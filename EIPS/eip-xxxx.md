---
eip: XXXX
title: Offchain Computation Standard
description: Standard to request & access offchain computed parameters while preserving composability
author: Nicolas Pasquier (@npasquie)
discussions-to: todo
status: Draft
type: Standards Track
category: ERC
created: 2022-01-24
requires: 165
---

# Offchain Computation Standard

<!-- AUTO-GENERATED-CONTENT:START (TOC) -->
- [Offchain Computation Standard](#offchain-computation-standard)
    - [Reader advisory](#reader-advisory)
  - [Simple Summary](#simple-summary)
  - [Abstract](#abstract)
  - [Motivation](#motivation)
  - [Specification](#specification)
    - [Parameter register](#parameter-register)
    - [Usage in contracts](#usage-in-contracts)
      - [Walkthrough of a transaction preparation in a signing software](#walkthrough-of-a-transaction-preparation-in-a-signing-software)
    - [Optional getParameter() implementations](#optional-getparameter-implementations)
      - [getParameter() instructing to find bytecode at an URI](#getparameter-instructing-to-find-bytecode-at-an-uri)
      - [getParameter() instructing to find a script at an URI](#getparameter-instructing-to-find-a-script-at-an-uri)
  - [Rationale](#rationale)
    - [Reference implementation of the Parameter Register](#reference-implementation-of-the-parameter-register)
    - [Reference implementation to be inherited from](#reference-implementation-to-be-inherited-from)
    - [Optional getParameter() implementations](#optional-getparameter-implementations-1)
    - [Drawbacks](#drawbacks)
    - [Coding implications](#coding-implications)
    - [Examples of scalabity gains in 3 use-cases](#examples-of-scalabity-gains-in-3-use-cases)
<!-- AUTO-GENERATED-CONTENT:END -->

### Reader advisory
No PR yet to the EIP repo. Modifications to come before PR : usage of EIP-3668 inspired error, more specifications for clients, rewording.

## Simple Summary

Standard to request & access offchain computed parameters while preserving composability

## Abstract

(Draft) A standard API is proposed to request & access offchain computed parameters in smart-contracts in a composable way. Implications on smart-contract programming and signers/wallets workflow are explored.

As this document is a draft, suggestions on other possible ways to achieve the desired properties are mentionned as well.

This standard can be used for every case where verification of correctness of computation/data is less complex than the computation/data itself.

## Motivation

Off-chain computation checked on-chain has become a common pattern is Dapps, virtually enabling usage of large data sets or complex computations in smart contracts within their limited resources. This is usually achieved through a script in a front-end app generating the correct parameters required by a contract call. This pattern is by nature non-composable, any protocol that needs to be integrated by other protocols must resolve to implement those costly operations on chain.  
The proposed new standards would greatly broaden the possibilities of smart-contract developers, especially in the interactions accross protocols. L2-scaling alone can't provide this kind of application-specific optimisations.

## Specification

### Parameter register

A register is deployed on-chain, for smart-contracts to consume offchain-computed parameters.  

Proposed implementation  
```solidity
    pragma solidity 0.8.11;

    /// @title ERC-XXXX Parameter Register
    /// @author Nicolas Pasquier (@npasquie)
    /// @notice as a user, use this contract to record offchain-computed parameters
    ///     as a contract, use it to consume those parameters
    /// @dev this is a draft version
    contract ParameterRegister {
        //    tx origin =>   call nonce =>        contract =>   data nonce =>                    data
        mapping(address => mapping(uint => mapping(address => mapping(uint => bytes)))) private data;

        //    tx origin =>   call nonce =>        contract =>                 data nonce
        mapping(address => mapping(uint => mapping(address => uint))) private consumptionNonce;
        mapping(address => mapping(uint => mapping(address => uint))) private recordingNonce;

        mapping(address => uint) private callNonce;

        struct Parameter {
            address _contract;
            bytes _data;
        }

        /// @notice records parameters to be used in the next contract call.
        ///     each call overwrites the previous parameters. Each parameter can only be consumed once,
        ///     use this function again for each transaction.
        /// @param parameters list of parameters to be used by contracts in nested calls,
        ///     to be provided in the order of consumption.
        function recordParameters(Parameter[] calldata parameters) external {
            require(msg.sender == tx.origin);

            callNonce[tx.origin]++;
            for(uint i; i < parameters.length; i++){
                recordParameter(
                    parameters[i]._contract,            // contract
                    recordingNonce                      // data none
                        [tx.origin]                     //      tx origin
                        [callNonce[tx.origin]]          //      call nonce
                        [parameters[i]._contract],      //      contract
                    parameters[i]._data                 // data parameter
                );
            }
        }

        /// @notice record a parameter for a one-time usage in a specific contract
        function recordParameter(address _contract, uint _nonce, bytes calldata _data) private {
            data
                [tx.origin]                             // tx origin
                [callNonce[tx.origin]]                  // call nonce
                [_contract]                             // contract
                [_nonce]                                // data none
                = _data;

            recordingNonce
                [tx.origin]                             // tx origin
                [callNonce[tx.origin]]                  // call nonce
                [_contract]                             // contract
                ++;
        }

        /// @notice as a contract, consume a pre-computed parameter,
        ///     successive calls will give different parameters (computed for context)
        /// @dev correctness of the data MUST be checked
        function consumeParameter() external returns (bytes memory _data){
            _data = data
                [tx.origin]                             // tx origin
                [callNonce[tx.origin]]                  // call nonce
                [msg.sender]                            // contract
                [consumptionNonce                       // data nonce
                    [tx.origin]                         //      tx origin
                    [callNonce[tx.origin]]              //      call nonce
                    [msg.sender]];                      //      contract

            consumptionNonce
                [tx.origin]                             // tx origin
                [callNonce[tx.origin]]                  // call nonce
                [msg.sender]                            // contract
                ++;
        }
    }
```

### Usage in contracts

Every contract aiming to use offchain-computed parameters must implement the `EIP-165` interface.
Every contract aiming to use offchain-computed parameters SHOULD inherit from the recommended implementation.
Please note the guidelines mentionned in NatSpec.
Let's consider it's usage in an example :  

```solidity
    pragma solidity 0.8.11;

    interface ERC165 {
        function supportsInterface(bytes4 interfaceID) external view returns (bool);
    }

    interface ParameterRegister {
        function consumeParameter() external returns (bytes memory _data);
    }

    /// @title ERC-XXXX Reference Implementation
    /// @author Nicolas Pasquier (@npasquie)
    /// @notice This is a draft version. Inherit of this contract to signal to signers/wallets
    ///     which offchain-computed parameters you need
    contract ERCXXXX is ERC165 {
        // todo : specify actual address after mainnet deployment
        ParameterRegister constant PARAMETER_REGISTER = ParameterRegister(address(0)); 

        // todo : specify actual identifier after it has been chosen
        bytes4 constant ERCXXXX_IDENTIFIER = bytes4(0);

        /// @notice request & consume a pre-computed parameter,
        ///     successive calls will give different parameters (computed for context)
        /// @param offchainLogicSelector function selector of the function that will compute offchain
        ///     the parameters needed. This function MUST exist in the contract and MUST be pure
        ///     the function MUST return the variables expected on abi-decoding returned values
        /// @param logicArgumentsEncoded MUST be the abi-encoded arguments matching the parameters
        ///     of the function that has selector `offchainLogicSelector`
        /// @return data abi-encoded arguments for the contract logic
        /// @dev use abi.decode() to extract the variables needed from the returned bytes,
        ///     correctness of the data MUST be checked
        function getParameter(bytes4 offchainLogicSelector, bytes memory logicArgumentsEncoded) 
            internal returns (bytes memory data) {
            data = PARAMETER_REGISTER.consumeParameter();
            require(
                data.length > 0,            // check that a parameter has been prepared
                string(abi.encode(          // standardised instructions to prepare the parameter
                    "eip-xxxx;",
                    address(this),
                    offchainLogicSelector,
                    logicArgumentsEncoded)
                )
            );
        }

        /// @notice cf https://eips.ethereum.org/EIPS/eip-165
        function supportsInterface(bytes4 interfaceID) external pure returns (bool){
            return(interfaceID == ERCXXXX_IDENTIFIER);
        }
    }

    contract Example is ERCXXXX {
        bytes4 constant FOR_OFFCHAIN_CALL_FUNCTION_SELECTOR = bytes4(keccak256(bytes("actuallyComputesNeededParameters(uint)")));

        uint someVarThatChangesDependingOnContext;

        // step 1 : called in a gas estimation request
        // step 4 : the same gas estimation is performed again, after having called the Parameter Register with the values
        //      returned by step 3
        function needsOffchainComputedParameter() public returns(string memory){

            // step 2 : a revert is triggered, containing standardised instructions on how to compute needed parameters offchain
            (bool[] memory offchainComputedArg1, uint offchainComputedArg2) = abi.decode(
                getParameter(
                    FOR_OFFCHAIN_CALL_FUNCTION_SELECTOR,
                    abi.encode(someVarThatChangesDependingOnContext)
                ),
                (bool[], uint)
            );

            require(offchainComputedArg2 >= 200 && offchainComputedArg1[1], "some check failed");


            // step 5 : somewhere else in code, another call to getParameter() may trigger a revert, we go back to step 3 with the
            //      updated instructions, add the returned values to the array of parameters sent to the recordParameters() function
            //      of the Parameter Register, and loop back to step 4 as many times as needed

            // step 6 : the gas estimation eventually sends a result without error message, we can sign & send the transaction
            return "success !"; 
        }

        /// step 3 : function is called offchain, it returns the parameters needed
        function actuallyComputesNeededParameters(uint someArg) external pure returns(bool[] memory computedArg1, uint computedArg2){
            bool[] memory returnVar;

            returnVar[0] = false;
            returnVar[1] = true;
            returnVar[2] = false;

            return(returnVar, someArg % 15 + 200);
        }
    }
```

This standard requires the signers/wallets to implement logic specific for it, as they are the software which will actually compute offchain the arguments requested by the contract. A short version of their workflow is mentionned in the comments, here is a detailed one. The workflow is described on a chain where either the EIP-3074 or the EIP-2803 is live. More on this in the rationale section.  

#### Walkthrough of a transaction preparation in a signing software

In the contract Example, we want to call the function needsOffchainComputedParameter().

**Step 1.)**  
A gas estimation is requested on a tx calling needsOffchainComputedParameter().

**Step 2.)**  
getParameter() from the Parameter Register is called. It fetches data from the parameter register, as the parameter register received no data yet, it returns an empty variable. A check is performed, as the data is constated to be empty, a revert is triggered. The revert gives an error message which has a standardised format. It is prefixed by `eip-xxxx;` to signal to the signing software that this error message contains instructions to compute the requested parameters. When abi-decoding the rest of the data, the signer will find the address of the contract that reverted, as well as a method selector. 

**Step 3.)**  
The signer now has to request the bytecode of the contract address returned. As the method corresponding to the selector is pure, it can be called in a local EVM (that disabled block gas limit) without needing to fork the chain. Arguments for this function are found in the error message, after the selector. Returned values (the offchain computed ones) are stored for the next step.

**Step 4.)**  
The gas estimation is called again, in a transaction that now includes a call to the recordParameters() function (thanks to either EIP-3074 or EIP-2803), providing the saved data stored from step 3.

**Step 5.)**  
As getParameter() can be called multiple times in one tx, especially in cross-protocol scenarios, the gas estimation may return a standardised error message again. We loop in steps 3 and 4 as long as needed, each time appending the new offchain parameters that we computed at the end of the array we provide to the recordParameters(). 

**Step 6.)**  
At some point, we will have provided all the offchain parameters needed and the gas estimation will give an error-free result. The transaction preparation is complete, we can sign and send.

### Optional getParameter() implementations

Multiple methods named `getParameter` can be accessible. Please provide feedback on which seems useful to you :

#### getParameter() instructing to find bytecode at an URI

Consider the following implementation :

```solidity
    function getParameter(string memory logicURI, bytes memory logicArgumentsEncoded) 
        internal returns (bytes memory data) {
        data = PARAMETER_REGISTER.consumeParameter();
        require(
            data.length > 0,            // check that a parameter has been prepared
            string(abi.encode(          // standardised instructions to prepare the parameter
                "eip-xxxx-uri;",
                logicURI,
                ";end-uri;",            // used to spot with certainty the end of the URI
                logicArgumentsEncoded)
            )
        );
    }
```

In this case, the wallet would fetch the bytecode to execute from the URI. URI can be IPFS, Arweave or HTTP/HTPPS format.

#### getParameter() instructing to find a script at an URI

Consider the following implementation :

```solidity
    function getParameter(string memory logicURI, bytes memory logicArgumentsEncoded, bool isWASM) 
        internal returns (bytes memory data) {
        data = PARAMETER_REGISTER.consumeParameter();
        require(
            data.length > 0,                // check that a parameter has been prepared
            string(abi.encode(              // standardised instructions to prepare the parameter
                "eip-xxxx-", 
                isWASM ? "wasm;" : "js;",   // we instruct the signer to expect the script in js or wasm
                logicURI,
                ";end-script;",             // used to spot with certainty the end of the URI
                logicArgumentsEncoded)
            )
        );
    }
```

In this case, the wallet would fetch a script in javascript or wasm from the URI and execute it. URI can be IPFS, Arweave or HTTP/HTPPS format.
## Rationale 

All design choices have been made to minimize as much as possible changes needed to be made to current way of operations to make composable offchain computation usage possible. In particular, no change to the EVM is required, even if as it is mentionned below, introducing new EVM instructions could be useful.

### Reference implementation of the Parameter Register

To store the data we use a mapping nested 4 times. This permits to make sure that a contract can only see the data that was meant for it, and hides any other data which can be used to deduce the context of the transaction and derive potentially composability-breaking conditions from it.
The data is accessed via the consumeParameter() method, which allows the same data to be accessed only once. This is because the data must be updated for each call of consumeParameter() as it corresponds to another context. This is automatic and the contract can't ask for the data of a specific nonce to minimize confusion and maximize abstraction.
Each time an address calls recordParameters() it increments its `callNonce`, as only the latest nonce can be requested, this effectively overwrites previously stored data (from an application standpoint, not from the chain standpoint). This avoids confusion between calls, and is useful to overwrite an eventual mistake and/or data stored for a call that is no longer planned.

### Reference implementation to be inherited from

We want the method corresponding to the `offchainLogicSelector` parameter of getParameter() to be pure so wallets/signers can get what this method returns with the parameters returned in the error message plus a bytecode request on the contract address, by using a local EVM without fork. This choice aims to limit as much as possible the extra load of requests that this standard puts on nodes. It makes sense to not only offload the consensus from complex computations by this standard, but also end nodes that serve requests, also extra requests usually comes at a cost.

### Optional getParameter() implementations

The bytecode at an URI is useful to offload the chain from large amounts of data (example: for merkle proofs) or complex implementations. A drawback is that the offchain logic doesn't have the same data-availability guarantees than the onchain logic in this case.
In the case of the implementation giving an URI for a script, we have the same offloading advantage and same data-availability guarantee drawback. We have the advantage that developers can implement this solution way more easily as it enables the usage of many existing libraries in javascript (ex: merkletreejs) and every language that can compile in Web Assembly (ex: C). A new drawback is that extra caution is needed (isolated environment) to execute the script as it is potentially malicious code.

### Drawbacks

The main drawback of this approach is that we store data on chain meant to be used only once. Another approach would be to create a new EVM instruction to access a new data field in the tx message, containing the offchain-computed parameters. This approach is more cost-efficient but requires this EIP to be included in a hardfork. This is similar to what was proposed in EIP-3508 (stagnant).

Another drawback is that we increase the number of RPC requests needed to prepare a tx. Signers also have to do more computations, of impredictible complexity. Wallets and signers must implement the new standard. I (the author) offer to provide a POC if first discussions show interest.

EIP-3074 or EIP-2803 must be live on chain for this EIP to be viable, as without them we can't call recordParameters() and another contract in the same tx directly from tx.origin.

### Coding implications

This standards enable developers to split their code in two parts : 
- the computations, which is ran off chain
- the checks, which is ran on chain

In most cases, the solution to a problem is order of magnitudes easier to verify than to compute. In Dapps, off-chain computations are usually considered negligeable, even if complex, as they do not generate gas fees.

### Examples of scalabity gains in 3 use-cases

Those situations are from real cases. Offchain computation is already used in combination of onchain checks in dapps in some cases, but in non-composable ways.

Merkle Tree for a token airdrop :
For a list of size n, space complexity is O(n), proof check is O(log(n))

Sorted list for a priority queue :
For a list of size n, insertion has a time complexity of O(log(n)), checking its correctness is O(1)

Finding the best route for a swap :
With e the number of edges and v the nodes, Djikstra's pathfinder has a time complexity of O((e + v) * log(v)), check has the same complexity but many use-cases would not need to check
---
eip: XXXX
title: Offchain Computation Standard
description: Standard for composable offchain computed parameters access & instruction
author: Nicolas Pasquier (@npasquie)
discussions-to: todo
status: Draft
type: Standards Track
category: ERC
created: 2022-01-13
requires: 165
---

# Offchain Computation Standard

<!-- AUTO-GENERATED-CONTENT:START (TOC) -->
- [Offchain Computation Standard](#offchain-computation-standard)
  - [Simple Summary](#simple-summary)
  - [Abstract](#abstract)
  - [Motivation](#motivation)
  - [Specification](#specification)
    - [Parameter register](#parameter-register)
    - [Usage in contracts](#usage-in-contracts)
      - [Walkthrough of a transaction preparation in a signing software](#walkthrough-of-a-transaction-preparation-in-a-signing-software)
  - [Rationale](#rationale)
    - [Other possibilities](#other-possibilities)
  - [Coding implications](#coding-implications)
    - [Examples of scalabity gains in 3 use-cases](#examples-of-scalabity-gains-in-3-use-cases)
<!-- AUTO-GENERATED-CONTENT:END -->

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
      //    tx origin =>   call nonce =>        contract =>         method =>   data nonce =>                    data
      mapping(address => mapping(uint => mapping(address => mapping(bytes4 => mapping(uint => bytes))))) private data;

      //    tx origin =>   call nonce =>        contract =>         method =>                  data nonce
      mapping(address => mapping(uint => mapping(address => mapping(bytes4 => uint)))) private consumptionNonce;
      mapping(address => mapping(uint => mapping(address => mapping(bytes4 => uint)))) private recordingNonce;

      mapping(address => uint) private callNonce;

      struct Parameter {
          address _contract;
          bytes4 _method;
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
                  parameters[i]._method,              // method
                  recordingNonce                      // data none
                      [tx.origin]                     //      tx origin
                      [callNonce[tx.origin]]          //      call nonce
                      [parameters[i]._contract]       //      contract
                      [parameters[i]._method],        //      method
                  parameters[i]._data                 // data parameter
              );
          }
      }

      /// @notice record a parameter for a one-time usage in a specific contract method
      function recordParameter(address _contract, bytes4 _method, uint _nonce, bytes calldata _data) private {
          data
              [tx.origin]                             // tx origin
              [callNonce[tx.origin]]                  // call nonce
              [_contract]                             // contract
              [_method]                               // method
              [_nonce]                                // data none
              = _data;

          recordingNonce
                  [tx.origin]                         // tx origin
                  [callNonce[tx.origin]]              // call nonce
                  [_contract]                         // contract
                  [_method]                           // method
                  ++;
      }

      /// @notice as a contract, consume a pre-computed parameter,
      ///     successive calls will give different parameters (computed for context)
      /// @dev correctness of the data MUST be checked
      /// @param method required, the method id that is consuming the data (same that calls)
      function consumeParameter(bytes4 method) external returns (bytes memory _data){
          _data = data
              [tx.origin]                             // tx origin
              [callNonce[tx.origin]]                  // call nonce
              [msg.sender]                            // contract
              [method]                                // method
              [consumptionNonce                       // data nonce
                  [tx.origin]                         //      tx origin
                  [callNonce[tx.origin]]              //      call nonce
                  [msg.sender]                        //      contract
                  [method]];                          //      method

          consumptionNonce
              [tx.origin]                             // tx origin
              [callNonce[tx.origin]]                  // call nonce
              [msg.sender]                            // contract
              [method]                                // method
              ++;
      }
  }
```

### Usage in contracts

Every contract aiming to use offchain-computed parameters must implement the `EIP-165` interface.
Every contract aiming to use offchain-computed parameters SHOULD inherit from the recommended implementation. Let's consider it's usage in an example :  

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

      /// @notice consume a pre-computed parameter,
      ///     successive calls will give different parameters (computed for context)
      /// @return _data abi-encoded arguments for the contract logic
      /// @dev use abi.decode() to extract the variables needed from the returned bytes,
      ///     correctness of the data MUST be checked using ercXXXXRequire()
      function getParameter() internal returns (bytes memory _data) {
          return PARAMETER_REGISTER.consumeParameter();
      }

      /// @notice similar to require(), sends a standardised error message for signers/wallets
      ///     to generate the offchain-computed parameters needed in your contract
      /// @param check will trigger the revert + offchain instructions if false
      /// @param offchainLogicSelector function selector of the function that will compute offchain
      ///     the parameters needed. This function MUST exist in the contract and MUST be pure
      ///     the function MUST return the variables expected on abi-decoding getParameter()
      /// @param logicArgumentsEncoded MUST be the abi-encoded arguments matching the parameters
      ///     of the function that has selector offchainLogicSelector
      function ercXXXXRequire(bool check, bytes4 offchainLogicSelector, bytes memory logicArgumentsEncoded) internal view {
          require(
              check,
              string(abi.encode(
                  "eip-xxxx;",
                  address(this),
                  offchainLogicSelector,
                  logicArgumentsEncoded)));
      }

      /// @notice cf https://eips.ethereum.org/EIPS/eip-165
      function supportsInterface(bytes4 interfaceID) external pure returns (bool){
          return(interfaceID == ERCXXXX_IDENTIFIER);
      }
  }

  contract Example is ERCXXXX {
      uint someVarThatChangesDependingOnContext;

      // step 1 : called in a gas estimation request
      // step 4 : the same gas estimation is performed again, after having called the Parameter Register with the values
      //      returned by step 3
      function needsOffchainComputedParameter() public returns(string memory){
          (bool[] memory offchainComputedArg1, uint offchainComputedArg2) = abi.decode(getParameter(), (bool[], uint));
          bytes4 forOffChainCallFunctionSelector = bytes4(keccak256(bytes("actuallyComputesNeededParameters(uint)")));

          bool someCheck = offchainComputedArg2 >= 200 && offchainComputedArg1[1];

          // step 2 : a revert is triggered, containing standardised instructions on how to compute needed parameters offchain
          ercXXXXRequire(someCheck, forOffChainCallFunctionSelector, abi.encode(someVarThatChangesDependingOnContext));

          // step 5 : somewhere else in code, another call to ercXXXXRequire() may trigger a revert, we go back to step 3 with the
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
A gas estimation is required on a tx calling needsOffchainComputedParameter().

**Step 2.)**
getParameter() from the Parameter Register is called, by default it will  


## Rationale 

All design choices have been made to minimize as much as possible changes needed to be made to current way of operations to make composable offchain computation usage possible. In particular, no change to the EVM is required, even if as it is mentionned below, introducing new EVM instructions could be useful.


-- 

A smart-contract is deployed onchain, which purpose is to 


To signal their need for offchain computation even in nested calls, smart-contracts need a standardised way to provide instructions on how to compute needed parameters. Those computations must be accessible to smart-contracts for checks & usage. This can be achived by : 
- For signaling :
    - fun
    - standardised revert message indicating which function expected parameters computed offchain
- For access : 
    - providing a new EVM instruction to retrieve data from the original transaction, which is similar in some ways to EIP-3508.
    or
    - usage of a smart contract deployed onchain specifically designed for access to this data 


### Other possibilities

## Coding implications

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
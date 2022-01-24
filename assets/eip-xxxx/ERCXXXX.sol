// SPDX-License-Identifier: MIT
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
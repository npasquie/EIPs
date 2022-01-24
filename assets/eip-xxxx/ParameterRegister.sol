// SPDX-License-Identifier: MIT
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
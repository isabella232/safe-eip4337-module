// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.9;

import "./common/Enum.sol";
import "./common/UserOperation.sol";
import "./handler/CompatibilityFallbackHandler.sol";

contract SafeEIP4337DoubleAgent is CompatibilityFallbackHandler {
    mapping(address => uint256) public safeNonces;
    mapping(address => bytes32) public transactionsReadyToExecute;

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 _requestId,
        uint256 requiredPrefund,
        address _caller
    ) external {
        bytes32 transactionHash = getTransactionHash(userOp.sender, userOp.callData, userOp.callGas);

        _validateSignatures(transactionHash);
        _markTransactionReadyToExecute(transactionHash);
        _payPrefund(userOp.sender, requiredPrefund);
    }

    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) external returns (bool success) {
        uint256 availableGas = gasleft();
        bytes calldata callData = keccak256(
            abi.encodeWithSignature("execTransaction(address,uint256,bytes,uint8)", to, value, data, operation)
        );
        require(transactionsReadyToExecute[address(this)] == getTransactionHash(address(this), callData, availableGas));
        safeNonces[address(this)]++;

        return GnosisSafe(address(this)).execTransactionFromModule(to, value, data, operation);
    }

    function getTransactionHash(
        address safe,
        bytes calldata data,
        uint256 callGas
    ) public view returns (bytes32) {
        return keccak256(abi.encode(safeNonces[safe], data, callGas, address(msg.sender), GnosisSafe(safe).getChainId()));
    }

    function _validateSignatures(
        address safe,
        bytes32 transactionHash,
        bytes calldata signatures
    ) internal view {
        GnosisSafe(safe).checkSignatures(transactionHash, signatures);
    }

    function _markTransactionReadyToExecute(UserOperation calldata userOp) internal {
        transactionsReadyToExecute[userOp.sender] = getTransactionHash(userOp.sender, userOp.callData, userOp.callGas);
    }

    function _payPrefund(address safe, uint256 requiredPrefund) internal {
        if (requiredPrefund != 0) {
            GnosisSafe(safe).execTransactionFromModule(msg.sender, requiredPrefund, "0x", Enum.Operation.Call);
        }
    }
}

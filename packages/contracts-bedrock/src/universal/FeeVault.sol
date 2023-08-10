// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { L2StandardBridge } from "../L2/L2StandardBridge.sol";
import { Predeploys } from "../libraries/Predeploys.sol";

/// @title FeeVault
/// @notice The FeeVault contract contains the basic logic for the various different vault contracts
///         used to hold fee revenue generated by the L2 system.
abstract contract FeeVault {
    /// @notice Enum representing where the FeeVault withdraws funds to.
    /// @custom:value L1 FeeVault withdraws funds to L1.
    /// @custom:value L2 FeeVault withdraws funds to L2.
    enum WithdrawalNetwork {
        L1,
        L2
    }

    /// @notice Minimum balance before a withdrawal can be triggered.
    uint256 public immutable MIN_WITHDRAWAL_AMOUNT;

    /// @notice Wallet that will receive the fees.
    address public immutable RECIPIENT;

    /// @notice Network which the RECIPIENT will receive fees on.
    WithdrawalNetwork public immutable WITHDRAWAL_NETWORK;

    /// @notice The minimum gas limit for the FeeVault withdrawal transaction.
    uint32 internal constant WITHDRAWAL_MIN_GAS = 35_000;

    /// @notice Total amount of wei processed by the contract.
    uint256 public totalProcessed;

    /// @notice Emitted each time a withdrawal occurs. This event will be deprecated
    ///         in favor of the Withdrawal event containing the WithdrawalNetwork parameter.
    /// @param value Amount that was withdrawn (in wei).
    /// @param to    Address that the funds were sent to.
    /// @param from  Address that triggered the withdrawal.
    event Withdrawal(uint256 value, address to, address from);

    /// @notice Emitted each time a withdrawal occurs.
    /// @param value             Amount that was withdrawn (in wei).
    /// @param to                Address that the funds were sent to.
    /// @param from              Address that triggered the withdrawal.
    /// @param withdrawalNetwork Network which the to address will receive funds on.
    event Withdrawal(uint256 value, address to, address from, WithdrawalNetwork withdrawalNetwork);

    /// @param _recipient           Wallet that will receive the fees.
    /// @param _minWithdrawalAmount Minimum balance for withdrawals.
    /// @param _withdrawalNetwork   Network which the recipient will receive fees on.
    constructor(
        address _recipient,
        uint256 _minWithdrawalAmount,
        WithdrawalNetwork _withdrawalNetwork
    ) {
        RECIPIENT = _recipient;
        MIN_WITHDRAWAL_AMOUNT = _minWithdrawalAmount;
        WITHDRAWAL_NETWORK = _withdrawalNetwork;
    }

    /// @notice Allow the contract to receive ETH.
    receive() external payable {}

    /// @notice Triggers a withdrawal of funds to the fee wallet on L1 or L2.
    function withdraw() external {
        require(
            address(this).balance >= MIN_WITHDRAWAL_AMOUNT,
            "FeeVault: withdrawal amount must be greater than minimum withdrawal amount"
        );

        uint256 value = address(this).balance;
        totalProcessed += value;

        emit Withdrawal(value, RECIPIENT, msg.sender);
        emit Withdrawal(value, RECIPIENT, msg.sender, WITHDRAWAL_NETWORK);

        if (WITHDRAWAL_NETWORK == WithdrawalNetwork.L2) {
            (bool success, ) = RECIPIENT.call{ value: value }(hex"");
            require(success, "FeeVault: failed to send ETH to L2 fee recipient");
        } else {
            L2StandardBridge(payable(Predeploys.L2_STANDARD_BRIDGE)).bridgeETHTo{ value: value }(
                RECIPIENT,
                WITHDRAWAL_MIN_GAS,
                bytes("")
            );
        }
    }
}

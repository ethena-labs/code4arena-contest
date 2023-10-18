// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IUSDeDefinitions {
  /// @notice This event is fired when the minter changes
  event MinterUpdated(address indexed newMinter, address indexed oldMinter);

  /// @notice Zero address not allowed
  error ZeroAddressException();
  /// @notice It's not possible to renounce the ownership
  error CantRenounceOwnership();
  /// @notice Only the minter role can perform an action
  error OnlyMinter();
}

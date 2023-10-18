// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IStakedUSDe {
  // Events //
  /// @notice Event emitted when the rewards are received
  event RewardsReceived(uint256 indexed amount, uint256 newVestingUSDeAmount);
  /// @notice Event emitted when the balance from an FULL_RESTRICTED_STAKER_ROLE user are redistributed
  event LockedAmountRedistributed(address indexed from, address indexed to, uint256 amount);

  // Errors //
  /// @notice Error emitted shares or assets equal zero.
  error InvalidAmount();
  /// @notice Error emitted when owner attempts to rescue USDe tokens.
  error InvalidToken();
  /// @notice Error emitted when slippage is exceeded on a deposit or withdrawal
  error SlippageExceeded();
  /// @notice Error emitted when a small non-zero share amount remains, which risks donations attack
  error MinSharesViolation();
  /// @notice Error emitted when owner is not allowed to perform an operation
  error OperationNotAllowed();
  /// @notice Error emitted when there is still unvested amount
  error StillVesting();
  /// @notice Error emitted when owner or blacklist manager attempts to blacklist owner
  error CantBlacklistOwner();
  /// @notice Error emitted when the zero address is given
  error InvalidZeroAddress();

  function transferInRewards(uint256 amount) external;

  function rescueTokens(address token, uint256 amount, address to) external;

  function getUnvestedAmount() external view returns (uint256);
}

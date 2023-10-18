// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IVirtualBalanceRewardPool {
  function getReward(address) external;

  function getReward() external;

  function balanceOf(address) external view returns (uint256);

  function earned(address) external view returns (uint256);

  function rewardToken() external view returns (address);
}

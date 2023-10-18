// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IBaseRewardPool {
  function getReward(address, bool) external returns (bool);

  function getReward() external returns (bool);

  function earned(address) external view returns (uint256);

  function balanceOf(address) external view returns (uint256);

  function extraRewards(uint256) external view returns (address);

  function withdrawAndUnwrap(uint256, bool) external returns (bool);

  function extraRewardsLength() external view returns (uint256);
}

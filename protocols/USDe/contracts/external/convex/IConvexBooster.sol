// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IConvexBooster {
  function poolInfo(uint256) external view returns (address, address, address, address, address, bool);

  function deposit(uint256, uint256, bool) external returns (bool);

  function depositAll(uint256, bool) external returns (bool);

  function withdraw(uint256, uint256) external returns (bool);

  function withdrawAll(uint256) external returns (bool);

  function rewardClaimed(uint256, address, uint256) external returns (bool);
}

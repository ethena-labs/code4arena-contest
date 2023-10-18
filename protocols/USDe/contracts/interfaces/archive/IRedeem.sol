// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IRedeem {
  function deposit(address token, uint256 tokenAmount) external returns (uint256 xUSDAmount);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface ICurvePool {
  function exchange(int128 i, int128 j, uint256 dx, uint256 dy) external payable returns (uint256);
}

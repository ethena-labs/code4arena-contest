// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface ILendingAddressRegistry {
  function getLendingMarket() external view returns (address);

  function setLendingMarket(address lendingMarket) external;

  function getPriceOracleAggregator() external view returns (address);

  function setPriceOracleAggregator(address priceOracleAggregator) external;

  function getTreasury() external view returns (address);

  function setTreasury(address treasury) external;

  function getStaking() external view returns (address);

  function setStaking(address staking) external;

  function getStablePool() external view returns (address);

  function setStablePool(address stablePool) external;

  function getSwapper() external view returns (address);

  function setSwapper(address swapper) external;

  function getKeepers() external view returns (address[] memory);

  function addKeeper(address keeper) external;

  function removeKeeper(address keeper) external;

  function isKeeper(address keeper) external view returns (bool);

  function getAddress(bytes32 id) external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IOracle.sol";

interface IPriceOracleAggregator {
  event UpdateOracle(address token, IOracle oracle);

  function updateOracleForAsset(address _asset, IOracle _oracle) external;

  function viewPriceInUSD(address _token) external view returns (uint256);
}

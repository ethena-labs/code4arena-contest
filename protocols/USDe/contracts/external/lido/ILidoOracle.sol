// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ILidoOracle {
  function getExpectedEpochId() external view returns (uint256);

  function getQuorum() external view returns (uint256);

  function getOracleMembers() external view returns (address[] memory);

  function reportBeacon(uint256 _epochId, uint64 _beaconBalances, uint32 _beaconValidators) external;
}

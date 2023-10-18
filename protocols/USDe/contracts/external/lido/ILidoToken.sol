// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ILidoToken {
  function getBeaconStat()
    external
    view
    returns (uint256 depositedValidators, uint256 beaconValidators, uint256 beaconBalance);
}

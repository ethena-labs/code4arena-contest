// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import "../contracts/USDe.sol";
import "../contracts/interfaces/IEthenaMinting.sol";
import "../contracts/EthenaMinting.sol";

contract WhitelistMinters is Script {
  address public ethenaMintingAddress;

  function run() public virtual {
    uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(ownerPrivateKey);
    // update to correct EthenaMinting address
    ethenaMintingAddress = address(0x980C680a90631c8Ea49fA37B47AbC3154219EC1a);
    EthenaMinting ethenaMinting = EthenaMinting(payable(ethenaMintingAddress));
    bytes32 ethenaMintingMinterRole = keccak256("MINTER_ROLE");

    // update array size and grantee addresses
    // ETH Execution Nodes
    address[] memory grantees = new address[](2);
    grantees[0] = address(0x13d2e29D174D075fA63cBc335a85d4a39bC71d5b);
    grantees[1] = address(0x1D475DD6312D21B80eb6123937FE7AbC4640adA5);
    grantees[1] = address(0x9a073D235A8D2C37854Da6f6A8F075C916debe06);

    for (uint256 i = 0; i < grantees.length; ++i) {
      if (!ethenaMinting.hasRole(ethenaMintingMinterRole, grantees[i])) {
        ethenaMinting.grantRole(ethenaMintingMinterRole, grantees[i]);
      }
    }
    vm.stopBroadcast();
  }
}

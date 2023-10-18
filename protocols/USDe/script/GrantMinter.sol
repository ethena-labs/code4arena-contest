// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import "../contracts/USDe.sol";
import "../contracts/interfaces/IEthenaMinting.sol";
import "../contracts/EthenaMinting.sol";
import "../contracts/USDe.sol";

contract GrantMinter is Script {
  address public ethenaMintingAddress;

  function run() public virtual {
    uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(ownerPrivateKey);
    // update to correct EthenaMinting address
    ethenaMintingAddress = address(0x8543703e1e9d4bCe16ae1C6f73c43F7CEBF99808);
    USDe usdeToken = USDe(address(0x400835DB609170D1c268bF0d8039b3644Cf7793B));

    // update array size and grantee addresses

    usdeToken.setMinter(ethenaMintingAddress);

    vm.stopBroadcast();
  }
}

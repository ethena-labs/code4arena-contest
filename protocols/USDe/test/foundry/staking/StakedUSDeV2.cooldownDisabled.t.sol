// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/* solhint-disable func-name-mixedcase  */
/* solhint-disable private-vars-leading-underscore  */

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import {SigUtils} from "forge-std/SigUtils.sol";

import "../../../contracts/USDe.sol";
import "../../../contracts/StakedUSDeV2.sol";
import "../../../contracts/interfaces/IUSDe.sol";
import "../../../contracts/interfaces/IERC20Events.sol";
import "./StakedUSDe.t.sol";

/// @dev Run all StakedUSDeV1 tests against StakedUSDeV2 with cooldown duration zero, to ensure backwards compatibility
contract StakedUSDeV2CooldownDisabledTest is StakedUSDeTest {
  StakedUSDeV2 stakedUSDeV2;

  function setUp() public virtual override {
    usdeToken = new USDe(address(this));

    alice = vm.addr(0xB44DE);
    bob = vm.addr(0x1DE);
    greg = vm.addr(0x6ED);
    owner = vm.addr(0xA11CE);
    rewarder = vm.addr(0x1DEA);
    vm.label(alice, "alice");
    vm.label(bob, "bob");
    vm.label(greg, "greg");
    vm.label(owner, "owner");
    vm.label(rewarder, "rewarder");

    vm.startPrank(owner);
    stakedUSDe = new StakedUSDeV2(IUSDe(address(usdeToken)), rewarder, owner);
    stakedUSDeV2 = StakedUSDeV2(address(stakedUSDe));

    // Disable cooldown and unstake methods, enable StakedUSDeV1 methods
    stakedUSDeV2.setCooldownDuration(0);
    vm.stopPrank();

    sigUtilsUSDe = new SigUtils(usdeToken.DOMAIN_SEPARATOR());
    sigUtilsStakedUSDe = new SigUtils(stakedUSDe.DOMAIN_SEPARATOR());

    usdeToken.setMinter(address(this));
  }

  function test_cooldownShares_fails_cooldownDuration_zero() external {
    vm.expectRevert(IStakedUSDe.OperationNotAllowed.selector);
    stakedUSDeV2.cooldownShares(0, address(0));
  }

  function test_cooldownAssets_fails_cooldownDuration_zero() external {
    vm.expectRevert(IStakedUSDe.OperationNotAllowed.selector);
    stakedUSDeV2.cooldownAssets(0, address(0));
  }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

/* solhint-disable private-vars-leading-underscore  */
/* solhint-disable func-name-mixedcase  */
/* solhint-disable var-name-mixedcase  */

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import {SigUtils} from "forge-std/SigUtils.sol";

import "../../../contracts/USDe.sol";
import "../../../contracts/StakedUSDe.sol";
import "../../../contracts/interfaces/IUSDe.sol";
import "../../../contracts/interfaces/IERC20Events.sol";
import "../../../contracts/interfaces/ISingleAdminAccessControl.sol";

contract StakedUSDeBlacklistTest is Test, IERC20Events {
  USDe public usdeToken;
  StakedUSDe public stakedUSDe;
  SigUtils public sigUtilsUSDe;
  SigUtils public sigUtilsStakedUSDe;
  uint256 public _amount = 100 ether;

  address public owner;
  address public alice;
  address public bob;
  address public greg;

  bytes32 SOFT_RESTRICTED_STAKER_ROLE;
  bytes32 FULL_RESTRICTED_STAKER_ROLE;
  bytes32 DEFAULT_ADMIN_ROLE;
  bytes32 BLACKLIST_MANAGER_ROLE;

  event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
  event Withdraw(
    address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
  );
  event LockedAmountRedistributed(address indexed from, address indexed to, uint256 amountToDistribute);

  function setUp() public virtual {
    usdeToken = new USDe(address(this));

    alice = makeAddr("alice");
    bob = makeAddr("bob");
    greg = makeAddr("greg");
    owner = makeAddr("owner");

    usdeToken.setMinter(address(this));

    vm.startPrank(owner);
    stakedUSDe = new StakedUSDe(IUSDe(address(usdeToken)), makeAddr('rewarder'), owner);
    vm.stopPrank();

    FULL_RESTRICTED_STAKER_ROLE = keccak256("FULL_RESTRICTED_STAKER_ROLE");
    SOFT_RESTRICTED_STAKER_ROLE = keccak256("SOFT_RESTRICTED_STAKER_ROLE");
    DEFAULT_ADMIN_ROLE = 0x00;
    BLACKLIST_MANAGER_ROLE = keccak256("BLACKLIST_MANAGER_ROLE");
  }

  function _mintApproveDeposit(address staker, uint256 amount, bool expectRevert) internal {
    usdeToken.mint(staker, amount);

    vm.startPrank(staker);
    usdeToken.approve(address(stakedUSDe), amount);

    uint256 sharesBefore = stakedUSDe.balanceOf(staker);
    if (expectRevert) {
      vm.expectRevert(IStakedUSDe.OperationNotAllowed.selector);
    } else {
      vm.expectEmit(true, true, true, false);
      emit Deposit(staker, staker, amount, amount);
    }
    stakedUSDe.deposit(amount, staker);
    uint256 sharesAfter = stakedUSDe.balanceOf(staker);
    if (expectRevert) {
      assertEq(sharesAfter, sharesBefore);
    } else {
      assertApproxEqAbs(sharesAfter - sharesBefore, amount, 1);
    }
    vm.stopPrank();
  }

  function _redeem(address staker, uint256 amount, bool expectRevert) internal {
    uint256 balBefore = usdeToken.balanceOf(staker);

    vm.startPrank(staker);

    if (expectRevert) {
      vm.expectRevert(IStakedUSDe.OperationNotAllowed.selector);
    } else {
      vm.expectEmit(true, true, true, false);
      emit Withdraw(staker, staker, staker, amount, amount);
    }
    stakedUSDe.redeem(amount, staker, staker);
    vm.stopPrank();

    uint256 balAfter = usdeToken.balanceOf(staker);

    if (expectRevert) {
      assertEq(balBefore, balAfter);
    } else {
      assertApproxEqAbs(amount, balAfter - balBefore, 1);
    }
  }

  function testStakeFlowCommonUser() public {
    _mintApproveDeposit(greg, _amount, false);

    assertEq(usdeToken.balanceOf(greg), 0);
    assertEq(usdeToken.balanceOf(address(stakedUSDe)), _amount);
    assertEq(stakedUSDe.balanceOf(greg), _amount);

    _redeem(greg, _amount, false);

    assertEq(usdeToken.balanceOf(greg), _amount);
    assertEq(usdeToken.balanceOf(address(stakedUSDe)), 0);
    assertEq(stakedUSDe.balanceOf(greg), 0);
  }

  /**
   * Soft blacklist: mints not allowed. Burns or transfers are allowed
   */
  function test_softBlacklist_deposit_reverts() public {
    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedUSDe.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    _mintApproveDeposit(alice, _amount, true);
  }

  function test_softBlacklist_withdraw_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedUSDe.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    _redeem(alice, _amount, false);
  }

  function test_softBlacklist_transfer_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedUSDe.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.prank(alice);
    stakedUSDe.transfer(bob, _amount);
  }

  function test_softBlacklist_transferFrom_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedUSDe.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.prank(alice);
    stakedUSDe.approve(bob, _amount);

    vm.prank(bob);
    stakedUSDe.transferFrom(alice, bob, _amount);
  }

  /**
   * Full blacklist: mints, burns or transfers are not allowed
   */

  function test_fullBlacklist_deposit_reverts() public {
    // Alice full blacklisted
    vm.startPrank(owner);
    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    _mintApproveDeposit(alice, _amount, true);
  }

  function test_fullBlacklist_withdraw_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    _redeem(alice, _amount, true);
  }

  function test_fullBlacklist_transfer_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.expectRevert(IStakedUSDe.OperationNotAllowed.selector);
    vm.prank(alice);
    stakedUSDe.transfer(bob, _amount);
  }

  function test_fullBlacklist_transferFrom_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.prank(alice);
    stakedUSDe.approve(bob, _amount);

    vm.prank(bob);

    vm.expectRevert(IStakedUSDe.OperationNotAllowed.selector);
    stakedUSDe.transferFrom(alice, bob, _amount);
  }

  function test_fullBlacklist_can_not_be_transfer_recipient() public {
    _mintApproveDeposit(alice, _amount, false);
    _mintApproveDeposit(bob, _amount, false);

    // Alice full blacklisted
    vm.startPrank(owner);
    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.expectRevert(IStakedUSDe.OperationNotAllowed.selector);
    vm.prank(bob);
    stakedUSDe.transfer(alice, _amount);
  }

  function test_fullBlacklist_user_can_not_burn_and_donate_to_vault() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice full blacklisted
    vm.startPrank(owner);
    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.expectRevert(bytes("ERC20: transfer to the zero address"));
    vm.prank(alice);
    stakedUSDe.transfer(address(0), _amount);
  }

  /**
   * Soft and Full blacklist: mints, burns or transfers are not allowed
   */
  function test_softFullBlacklist_deposit_reverts() public {
    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedUSDe.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    _mintApproveDeposit(alice, _amount, true);

    // Alice full blacklisted
    vm.startPrank(owner);
    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();
    _mintApproveDeposit(alice, _amount, true);
  }

  function test_softFullBlacklist_withdraw_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedUSDe.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    _redeem(alice, _amount / 3, false);

    // Alice full blacklisted
    vm.startPrank(owner);
    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    _redeem(alice, _amount / 3, true);
  }

  function test_softFullBlacklist_transfer_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted can transfer
    vm.startPrank(owner);
    stakedUSDe.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.prank(alice);
    stakedUSDe.transfer(bob, _amount / 3);

    // Alice full blacklisted cannot transfer
    vm.startPrank(owner);
    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.expectRevert(IStakedUSDe.OperationNotAllowed.selector);
    vm.prank(alice);
    stakedUSDe.transfer(bob, _amount / 3);
  }

  /**
   * redistributeLockedAmount
   */

  function test_redistributeLockedAmount() public {
    _mintApproveDeposit(alice, _amount, false);
    uint256 aliceStakedBalance = stakedUSDe.balanceOf(alice);
    uint256 previousTotalSupply = stakedUSDe.totalSupply();
    assertEq(aliceStakedBalance, _amount);

    vm.startPrank(owner);

    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);

    vm.expectEmit(true, true, true, true);
    emit LockedAmountRedistributed(alice, bob, _amount);

    stakedUSDe.redistributeLockedAmount(alice, bob);

    vm.stopPrank();

    assertEq(stakedUSDe.balanceOf(alice), 0);
    assertEq(stakedUSDe.balanceOf(bob), _amount);
    assertEq(stakedUSDe.totalSupply(), previousTotalSupply);
  }

  function testCanBurnOnRedistribute() public {
    _mintApproveDeposit(alice, _amount, false);
    uint256 aliceStakedBalance = stakedUSDe.balanceOf(alice);
    uint256 previousTotalSupply = stakedUSDe.totalSupply();
    assertEq(aliceStakedBalance, _amount);

    vm.startPrank(owner);

    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);

    stakedUSDe.redistributeLockedAmount(alice, address(0));

    vm.stopPrank();

    assertEq(stakedUSDe.balanceOf(alice), 0);
    assertEq(stakedUSDe.totalSupply(), previousTotalSupply - _amount);
  }

  /**
   * Access control
   */
  function test_renounce_reverts() public {
    vm.startPrank(owner);

    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    stakedUSDe.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    vm.stopPrank();

    vm.expectRevert();
    stakedUSDe.renounceRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.expectRevert();
    stakedUSDe.renounceRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
  }

  function test_grant_role() public {
    vm.startPrank(owner);

    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    stakedUSDe.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    vm.stopPrank();

    assertEq(stakedUSDe.hasRole(FULL_RESTRICTED_STAKER_ROLE, alice), true);
    assertEq(stakedUSDe.hasRole(SOFT_RESTRICTED_STAKER_ROLE, alice), true);
  }

  function test_revoke_role() public {
    vm.startPrank(owner);

    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    stakedUSDe.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    assertEq(stakedUSDe.hasRole(FULL_RESTRICTED_STAKER_ROLE, alice), true);
    assertEq(stakedUSDe.hasRole(SOFT_RESTRICTED_STAKER_ROLE, alice), true);

    stakedUSDe.revokeRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    stakedUSDe.revokeRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    assertEq(stakedUSDe.hasRole(FULL_RESTRICTED_STAKER_ROLE, alice), false);
    assertEq(stakedUSDe.hasRole(SOFT_RESTRICTED_STAKER_ROLE, alice), false);

    vm.stopPrank();
  }

  function test_revoke_role_by_other_reverts() public {
    vm.startPrank(owner);

    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    stakedUSDe.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    vm.stopPrank();

    vm.startPrank(bob);

    vm.expectRevert();
    stakedUSDe.revokeRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.expectRevert();
    stakedUSDe.revokeRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    vm.stopPrank();

    assertEq(stakedUSDe.hasRole(FULL_RESTRICTED_STAKER_ROLE, alice), true);
    assertEq(stakedUSDe.hasRole(SOFT_RESTRICTED_STAKER_ROLE, alice), true);
  }

  function test_revoke_role_by_myself_reverts() public {
    vm.startPrank(owner);

    stakedUSDe.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    stakedUSDe.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    vm.stopPrank();

    vm.startPrank(alice);

    vm.expectRevert();
    stakedUSDe.revokeRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.expectRevert();
    stakedUSDe.revokeRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    vm.stopPrank();

    assertEq(stakedUSDe.hasRole(FULL_RESTRICTED_STAKER_ROLE, alice), true);
    assertEq(stakedUSDe.hasRole(SOFT_RESTRICTED_STAKER_ROLE, alice), true);
  }

  function testAdminCannotRenounce() public {
    vm.startPrank(owner);

    vm.expectRevert(IStakedUSDe.OperationNotAllowed.selector);
    stakedUSDe.renounceRole(DEFAULT_ADMIN_ROLE, owner);

    vm.expectRevert(ISingleAdminAccessControl.InvalidAdminChange.selector);
    stakedUSDe.revokeRole(DEFAULT_ADMIN_ROLE, owner);

    vm.stopPrank();

    assertTrue(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, owner));
    assertEq(stakedUSDe.owner(), owner);
  }

  function testBlacklistManagerCanBlacklist() public {
    vm.prank(owner);
    stakedUSDe.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedUSDe.hasRole(BLACKLIST_MANAGER_ROLE, alice));
    assertFalse(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, alice));

    vm.startPrank(alice);
    stakedUSDe.addToBlacklist(bob, true);
    assertTrue(stakedUSDe.hasRole(FULL_RESTRICTED_STAKER_ROLE, bob));

    stakedUSDe.addToBlacklist(bob, false);
    assertTrue(stakedUSDe.hasRole(SOFT_RESTRICTED_STAKER_ROLE, bob));
    vm.stopPrank();
  }

  function testBlacklistManagerCannotRedistribute() public {
    vm.prank(owner);
    stakedUSDe.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedUSDe.hasRole(BLACKLIST_MANAGER_ROLE, alice));
    assertFalse(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, alice));

    _mintApproveDeposit(bob, 1000 ether, false);
    assertEq(stakedUSDe.balanceOf(bob), 1000 ether);

    vm.startPrank(alice);
    stakedUSDe.addToBlacklist(bob, true);
    assertTrue(stakedUSDe.hasRole(FULL_RESTRICTED_STAKER_ROLE, bob));
    vm.expectRevert(
      "AccessControl: account 0x328809bc894f92807417d2dad6b7c998c1afdac6 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    stakedUSDe.redistributeLockedAmount(bob, alice);
    assertEq(stakedUSDe.balanceOf(bob), 1000 ether);
    vm.stopPrank();
  }

  function testBlackListManagerCannotAddOthers() public {
    vm.prank(owner);
    stakedUSDe.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedUSDe.hasRole(BLACKLIST_MANAGER_ROLE, alice));
    assertFalse(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, alice));

    vm.prank(alice);
    vm.expectRevert(
      "AccessControl: account 0x328809bc894f92807417d2dad6b7c998c1afdac6 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    stakedUSDe.grantRole(BLACKLIST_MANAGER_ROLE, bob);
  }

  function testBlacklistManagerCanUnblacklist() public {
    vm.prank(owner);
    stakedUSDe.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedUSDe.hasRole(BLACKLIST_MANAGER_ROLE, alice));
    assertFalse(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, alice));

    vm.startPrank(alice);
    stakedUSDe.addToBlacklist(bob, true);
    assertTrue(stakedUSDe.hasRole(FULL_RESTRICTED_STAKER_ROLE, bob));

    stakedUSDe.addToBlacklist(bob, false);
    assertTrue(stakedUSDe.hasRole(SOFT_RESTRICTED_STAKER_ROLE, bob));

    stakedUSDe.removeFromBlacklist(bob, true);
    assertFalse(stakedUSDe.hasRole(FULL_RESTRICTED_STAKER_ROLE, bob));

    stakedUSDe.removeFromBlacklist(bob, false);
    assertFalse(stakedUSDe.hasRole(SOFT_RESTRICTED_STAKER_ROLE, bob));
    vm.stopPrank();
  }

  function testBlacklistManagerCanNotBlacklistAdmin() public {
    vm.prank(owner);
    stakedUSDe.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedUSDe.hasRole(BLACKLIST_MANAGER_ROLE, alice));
    assertFalse(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, alice));

    vm.startPrank(alice);
    vm.expectRevert(IStakedUSDe.CantBlacklistOwner.selector);
    stakedUSDe.addToBlacklist(owner, true);
    vm.expectRevert(IStakedUSDe.CantBlacklistOwner.selector);
    stakedUSDe.addToBlacklist(owner, false);
    vm.stopPrank();

    assertFalse(stakedUSDe.hasRole(FULL_RESTRICTED_STAKER_ROLE, owner));
    assertFalse(stakedUSDe.hasRole(SOFT_RESTRICTED_STAKER_ROLE, owner));
  }

  function testOwnerCanRemoveBlacklistManager() public {
    vm.startPrank(owner);
    stakedUSDe.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedUSDe.hasRole(BLACKLIST_MANAGER_ROLE, alice));
    assertFalse(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, alice));

    stakedUSDe.revokeRole(BLACKLIST_MANAGER_ROLE, alice);
    vm.stopPrank();

    assertFalse(stakedUSDe.hasRole(BLACKLIST_MANAGER_ROLE, alice));
  }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import {SigUtils} from "forge-std/SigUtils.sol";

import "../../../contracts/USDe.sol";
import "../../../contracts/StakedUSDe.sol";
import "../../../contracts/interfaces/IStakedUSDe.sol";
import "../../../contracts/interfaces/IUSDe.sol";
import "../../../contracts/interfaces/IERC20Events.sol";
import "../../../contracts/interfaces/ISingleAdminAccessControl.sol";

contract StakedUSDeACL is Test, IERC20Events {
  USDe public usdeToken;
  StakedUSDe public stakedUSDe;
  SigUtils public sigUtilsUSDe;
  SigUtils public sigUtilsStakedUSDe;

  address public owner;
  address public rewarder;
  address public alice;
  address public newOwner;
  address public greg;

  bytes32 public DEFAULT_ADMIN_ROLE;
  bytes32 public constant BLACKLIST_MANAGER_ROLE = keccak256("BLACKLIST_MANAGER_ROLE");
  bytes32 public constant FULL_RESTRICTED_STAKER_ROLE = keccak256("FULL_RESTRICTED_STAKER_ROLE");

  event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
  event Withdraw(
    address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
  );
  event RewardsReceived(uint256 indexed amount, uint256 newVestingUSDeAmount);

  function setUp() public virtual {
    usdeToken = new USDe(address(this));

    alice = vm.addr(0xB44DE);
    newOwner = vm.addr(0x1DE);
    greg = vm.addr(0x6ED);
    owner = vm.addr(0xA11CE);
    rewarder = vm.addr(0x1DEA);
    vm.label(alice, "alice");
    vm.label(newOwner, "newOwner");
    vm.label(greg, "greg");
    vm.label(owner, "owner");
    vm.label(rewarder, "rewarder");

    vm.prank(owner);
    stakedUSDe = new StakedUSDe(IUSDe(address(usdeToken)), rewarder, owner);

    DEFAULT_ADMIN_ROLE = stakedUSDe.DEFAULT_ADMIN_ROLE();

    sigUtilsUSDe = new SigUtils(usdeToken.DOMAIN_SEPARATOR());
    sigUtilsStakedUSDe = new SigUtils(stakedUSDe.DOMAIN_SEPARATOR());
  }

  function testCorrectSetup() public {
    assertTrue(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, owner));
  }

  function testCancelTransferAdmin() public {
    vm.startPrank(owner);
    stakedUSDe.transferAdmin(newOwner);
    stakedUSDe.transferAdmin(address(0));
    vm.stopPrank();
    assertTrue(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, owner));
    assertFalse(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, address(0)));
    assertFalse(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, newOwner));
  }

  function test_admin_cannot_transfer_self() public {
    vm.startPrank(owner);
    assertTrue(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, owner));
    vm.expectRevert(ISingleAdminAccessControl.InvalidAdminChange.selector);
    stakedUSDe.transferAdmin(owner);
    vm.stopPrank();
    assertTrue(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, owner));
  }

  function testAdminCanCancelTransfer() public {
    vm.startPrank(owner);
    stakedUSDe.transferAdmin(newOwner);
    stakedUSDe.transferAdmin(address(0));
    vm.stopPrank();

    vm.prank(newOwner);
    vm.expectRevert(ISingleAdminAccessControl.NotPendingAdmin.selector);
    stakedUSDe.acceptAdmin();

    assertTrue(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, owner));
    assertFalse(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, address(0)));
    assertFalse(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, newOwner));
  }

  function testOwnershipCannotBeRenounced() public {
    vm.startPrank(owner);
    vm.expectRevert(IStakedUSDe.OperationNotAllowed.selector);
    stakedUSDe.renounceRole(DEFAULT_ADMIN_ROLE, owner);

    vm.expectRevert(ISingleAdminAccessControl.InvalidAdminChange.selector);
    stakedUSDe.revokeRole(DEFAULT_ADMIN_ROLE, owner);
    vm.stopPrank();
    assertEq(stakedUSDe.owner(), owner);
    assertTrue(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, owner));
  }

  function testOwnershipTransferRequiresTwoSteps() public {
    vm.prank(owner);
    stakedUSDe.transferAdmin(newOwner);
    assertEq(stakedUSDe.owner(), owner);
    assertTrue(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, owner));
    assertNotEq(stakedUSDe.owner(), newOwner);
    assertFalse(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, newOwner));
  }

  function testCanTransferOwnership() public {
    vm.prank(owner);
    stakedUSDe.transferAdmin(newOwner);
    vm.prank(newOwner);
    stakedUSDe.acceptAdmin();
    assertTrue(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, newOwner));
    assertFalse(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, owner));
  }

  function testNewOwnerCanPerformOwnerActions() public {
    vm.prank(owner);
    stakedUSDe.transferAdmin(newOwner);
    vm.startPrank(newOwner);
    stakedUSDe.acceptAdmin();
    stakedUSDe.grantRole(BLACKLIST_MANAGER_ROLE, newOwner);
    stakedUSDe.addToBlacklist(alice, true);
    vm.stopPrank();
    assertTrue(stakedUSDe.hasRole(FULL_RESTRICTED_STAKER_ROLE, alice));
  }

  function testOldOwnerCantPerformOwnerActions() public {
    vm.prank(owner);
    stakedUSDe.transferAdmin(newOwner);
    vm.prank(newOwner);
    stakedUSDe.acceptAdmin();
    assertTrue(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, newOwner));
    assertFalse(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, owner));
    vm.prank(owner);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    stakedUSDe.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertFalse(stakedUSDe.hasRole(BLACKLIST_MANAGER_ROLE, alice));
  }

  function testOldOwnerCantTransferOwnership() public {
    vm.prank(owner);
    stakedUSDe.transferAdmin(newOwner);
    vm.prank(newOwner);
    stakedUSDe.acceptAdmin();
    assertTrue(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, newOwner));
    assertFalse(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, owner));
    vm.prank(owner);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    stakedUSDe.transferAdmin(alice);
    assertFalse(stakedUSDe.hasRole(DEFAULT_ADMIN_ROLE, alice));
  }

  function testNonAdminCantRenounceRoles() public {
    vm.prank(owner);
    stakedUSDe.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedUSDe.hasRole(BLACKLIST_MANAGER_ROLE, alice));

    vm.prank(alice);
    vm.expectRevert(IStakedUSDe.OperationNotAllowed.selector);
    stakedUSDe.renounceRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedUSDe.hasRole(BLACKLIST_MANAGER_ROLE, alice));
  }
}

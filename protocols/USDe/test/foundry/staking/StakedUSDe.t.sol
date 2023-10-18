// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import {SigUtils} from "forge-std/SigUtils.sol";

import "../../../contracts/USDe.sol";
import "../../../contracts/StakedUSDe.sol";
import "../../../contracts/interfaces/IUSDe.sol";
import "../../../contracts/interfaces/IERC20Events.sol";

contract StakedUSDeTest is Test, IERC20Events {
  USDe public usdeToken;
  StakedUSDe public stakedUSDe;
  SigUtils public sigUtilsUSDe;
  SigUtils public sigUtilsStakedUSDe;

  address public owner;
  address public rewarder;
  address public alice;
  address public bob;
  address public greg;

  bytes32 REWARDER_ROLE = keccak256("REWARDER_ROLE");

  event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
  event Withdraw(
    address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
  );
  event RewardsReceived(uint256 indexed amount, uint256 newVestingUSDeAmount);

  function setUp() public virtual {
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

    vm.prank(owner);
    stakedUSDe = new StakedUSDe(IUSDe(address(usdeToken)), rewarder, owner);

    sigUtilsUSDe = new SigUtils(usdeToken.DOMAIN_SEPARATOR());
    sigUtilsStakedUSDe = new SigUtils(stakedUSDe.DOMAIN_SEPARATOR());

    usdeToken.setMinter(address(this));
  }

  function _mintApproveDeposit(address staker, uint256 amount) internal {
    usdeToken.mint(staker, amount);

    vm.startPrank(staker);
    usdeToken.approve(address(stakedUSDe), amount);

    vm.expectEmit(true, true, true, false);
    emit Deposit(staker, staker, amount, amount);

    stakedUSDe.deposit(amount, staker);
    vm.stopPrank();
  }

  function _redeem(address staker, uint256 amount) internal {
    vm.startPrank(staker);

    vm.expectEmit(true, true, true, false);
    emit Withdraw(staker, staker, staker, amount, amount);

    stakedUSDe.redeem(amount, staker, staker);
    vm.stopPrank();
  }

  function _transferRewards(uint256 amount, uint256 expectedNewVestingAmount) internal {
    usdeToken.mint(address(rewarder), amount);
    vm.startPrank(rewarder);

    usdeToken.approve(address(stakedUSDe), amount);

    vm.expectEmit(true, false, false, true);
    emit Transfer(rewarder, address(stakedUSDe), amount);
    vm.expectEmit(true, false, false, false);
    emit RewardsReceived(amount, expectedNewVestingAmount);

    stakedUSDe.transferInRewards(amount);

    assertApproxEqAbs(stakedUSDe.getUnvestedAmount(), expectedNewVestingAmount, 1);
    vm.stopPrank();
  }

  function _assertVestedAmountIs(uint256 amount) internal {
    assertApproxEqAbs(stakedUSDe.totalAssets(), amount, 2);
  }

  function testInitialStake() public {
    uint256 amount = 100 ether;
    _mintApproveDeposit(alice, amount);

    assertEq(usdeToken.balanceOf(alice), 0);
    assertEq(usdeToken.balanceOf(address(stakedUSDe)), amount);
    assertEq(stakedUSDe.balanceOf(alice), amount);
  }

  function testInitialStakeBelowMin() public {
    uint256 amount = 0.99 ether;
    usdeToken.mint(alice, amount);
    vm.startPrank(alice);
    usdeToken.approve(address(stakedUSDe), amount);
    vm.expectRevert(IStakedUSDe.MinSharesViolation.selector);
    stakedUSDe.deposit(amount, alice);

    assertEq(usdeToken.balanceOf(alice), amount);
    assertEq(usdeToken.balanceOf(address(stakedUSDe)), 0);
    assertEq(stakedUSDe.balanceOf(alice), 0);
  }

  function testCantWithdrawBelowMinShares() public {
    _mintApproveDeposit(alice, 1 ether);

    vm.startPrank(alice);
    usdeToken.approve(address(stakedUSDe), 0.01 ether);
    vm.expectRevert(IStakedUSDe.MinSharesViolation.selector);
    stakedUSDe.redeem(0.5 ether, alice, alice);
  }

  function testCannotStakeWithoutApproval() public {
    uint256 amount = 100 ether;
    usdeToken.mint(alice, amount);

    vm.startPrank(alice);
    vm.expectRevert("ERC20: insufficient allowance");
    stakedUSDe.deposit(amount, alice);
    vm.stopPrank();

    assertEq(usdeToken.balanceOf(alice), amount);
    assertEq(usdeToken.balanceOf(address(stakedUSDe)), 0);
    assertEq(stakedUSDe.balanceOf(alice), 0);
  }

  function testStakeUnstake() public {
    uint256 amount = 100 ether;
    _mintApproveDeposit(alice, amount);

    assertEq(usdeToken.balanceOf(alice), 0);
    assertEq(usdeToken.balanceOf(address(stakedUSDe)), amount);
    assertEq(stakedUSDe.balanceOf(alice), amount);

    _redeem(alice, amount);

    assertEq(usdeToken.balanceOf(alice), amount);
    assertEq(usdeToken.balanceOf(address(stakedUSDe)), 0);
    assertEq(stakedUSDe.balanceOf(alice), 0);
  }

  function testOnlyRewarderCanReward() public {
    uint256 amount = 100 ether;
    uint256 rewardAmount = 0.5 ether;
    _mintApproveDeposit(alice, amount);

    usdeToken.mint(bob, rewardAmount);
    vm.startPrank(bob);

    vm.expectRevert(
      "AccessControl: account 0x72c7a47c5d01bddf9067eabb345f5daabdead13f is missing role 0xbeec13769b5f410b0584f69811bfd923818456d5edcf426b0e31cf90eed7a3f6"
    );
    stakedUSDe.transferInRewards(rewardAmount);
    vm.stopPrank();
    assertEq(usdeToken.balanceOf(alice), 0);
    assertEq(usdeToken.balanceOf(address(stakedUSDe)), amount);
    assertEq(stakedUSDe.balanceOf(alice), amount);
    _assertVestedAmountIs(amount);
    assertEq(usdeToken.balanceOf(bob), rewardAmount);
  }

  function testStakingAndUnstakingBeforeAfterReward() public {
    uint256 amount = 100 ether;
    uint256 rewardAmount = 100 ether;
    _mintApproveDeposit(alice, amount);
    _transferRewards(rewardAmount, rewardAmount);
    _redeem(alice, amount);
    assertEq(usdeToken.balanceOf(alice), amount);
    assertEq(stakedUSDe.totalSupply(), 0);
  }

  function testFuzzNoJumpInVestedBalance(uint256 amount) public {
    vm.assume(amount > 0 && amount < 1e60);
    _transferRewards(amount, amount);
    vm.warp(block.timestamp + 4 hours);
    _assertVestedAmountIs(amount / 2);
    assertEq(usdeToken.balanceOf(address(stakedUSDe)), amount);
  }

  function testOwnerCannotRescueUSDe() public {
    uint256 amount = 100 ether;
    _mintApproveDeposit(alice, amount);
    bytes4 selector = bytes4(keccak256("InvalidToken()"));
    vm.startPrank(owner);
    vm.expectRevert(abi.encodeWithSelector(selector));
    stakedUSDe.rescueTokens(address(usdeToken), amount, owner);
  }

  function testOwnerCanRescuestUSDe() public {
    uint256 amount = 100 ether;
    _mintApproveDeposit(alice, amount);
    vm.prank(alice);
    stakedUSDe.transfer(address(stakedUSDe), amount);
    assertEq(stakedUSDe.balanceOf(owner), 0);
    vm.startPrank(owner);
    stakedUSDe.rescueTokens(address(stakedUSDe), amount, owner);
    assertEq(stakedUSDe.balanceOf(owner), amount);
  }

  function testOwnerCanChangeRewarder() public {
    assertTrue(stakedUSDe.hasRole(REWARDER_ROLE, address(rewarder)));
    address newRewarder = address(0x123);
    vm.startPrank(owner);
    stakedUSDe.revokeRole(REWARDER_ROLE, rewarder);
    stakedUSDe.grantRole(REWARDER_ROLE, newRewarder);
    assertTrue(!stakedUSDe.hasRole(REWARDER_ROLE, address(rewarder)));
    assertTrue(stakedUSDe.hasRole(REWARDER_ROLE, newRewarder));
    vm.stopPrank();

    usdeToken.mint(rewarder, 1 ether);
    usdeToken.mint(newRewarder, 1 ether);

    vm.startPrank(rewarder);
    usdeToken.approve(address(stakedUSDe), 1 ether);
    vm.expectRevert(
      "AccessControl: account 0x5c664540bc6bb6b22e9d1d3d630c73c02edd94b7 is missing role 0xbeec13769b5f410b0584f69811bfd923818456d5edcf426b0e31cf90eed7a3f6"
    );
    stakedUSDe.transferInRewards(1 ether);
    vm.stopPrank();

    vm.startPrank(newRewarder);
    usdeToken.approve(address(stakedUSDe), 1 ether);
    stakedUSDe.transferInRewards(1 ether);
    vm.stopPrank();

    assertEq(usdeToken.balanceOf(address(stakedUSDe)), 1 ether);
    assertEq(usdeToken.balanceOf(rewarder), 1 ether);
    assertEq(usdeToken.balanceOf(newRewarder), 0);
  }

  function testUSDeValuePerStUSDe() public {
    _mintApproveDeposit(alice, 100 ether);
    _transferRewards(100 ether, 100 ether);
    vm.warp(block.timestamp + 4 hours);
    _assertVestedAmountIs(150 ether);
    assertEq(stakedUSDe.convertToAssets(1 ether), 1.5 ether - 1);
    assertEq(stakedUSDe.totalSupply(), 100 ether);
    // rounding
    _mintApproveDeposit(bob, 75 ether);
    _assertVestedAmountIs(225 ether);
    assertEq(stakedUSDe.balanceOf(alice), 100 ether);
    assertEq(stakedUSDe.balanceOf(bob), 50 ether);
    assertEq(stakedUSDe.convertToAssets(1 ether), 1.5 ether - 1);

    vm.warp(block.timestamp + 4 hours);

    uint256 vestedAmount = 275 ether;
    _assertVestedAmountIs(vestedAmount);

    assertApproxEqAbs(stakedUSDe.convertToAssets(1 ether), (vestedAmount * 1 ether) / 150 ether, 1);

    // rounding
    _redeem(bob, stakedUSDe.balanceOf(bob));

    _redeem(alice, 100 ether);

    assertEq(stakedUSDe.balanceOf(alice), 0);
    assertEq(stakedUSDe.balanceOf(bob), 0);
    assertEq(stakedUSDe.totalSupply(), 0);

    assertApproxEqAbs(usdeToken.balanceOf(alice), (vestedAmount * 2) / 3, 2);

    assertApproxEqAbs(usdeToken.balanceOf(bob), vestedAmount / 3, 2);

    assertApproxEqAbs(usdeToken.balanceOf(address(stakedUSDe)), 0, 1);
  }

  function testFairStakeAndUnstakePrices() public {
    uint256 aliceAmount = 100 ether;
    uint256 bobAmount = 1000 ether;
    uint256 rewardAmount = 200 ether;
    _mintApproveDeposit(alice, aliceAmount);
    _transferRewards(rewardAmount, rewardAmount);
    vm.warp(block.timestamp + 4 hours);
    _mintApproveDeposit(bob, bobAmount);
    vm.warp(block.timestamp + 4 hours);
    _redeem(alice, aliceAmount);
    _assertVestedAmountIs(bobAmount + (rewardAmount * 5) / 12);
  }

  function testFuzzFairStakeAndUnstakePrices(
    uint256 amount1,
    uint256 amount2,
    uint256 amount3,
    uint256 rewardAmount,
    uint256 waitSeconds
  ) public {
    vm.assume(
      amount1 >= 100 ether && amount2 > 0 && amount3 > 0 && rewardAmount > 0 && waitSeconds <= 9 hours
      // 100 trillion USD with 18 decimals
      && amount1 < 1e32 && amount2 < 1e32 && amount3 < 1e32 && rewardAmount < 1e32
    );

    uint256 totalContributions = amount1;

    _mintApproveDeposit(alice, amount1);

    _transferRewards(rewardAmount, rewardAmount);

    vm.warp(block.timestamp + waitSeconds);

    uint256 vestedAmount;
    if (waitSeconds > 8 hours) {
      vestedAmount = amount1 + rewardAmount;
    } else {
      vestedAmount = amount1 + rewardAmount - (rewardAmount * (8 hours - waitSeconds)) / 8 hours;
    }

    _assertVestedAmountIs(vestedAmount);

    uint256 bobStakedUSDe = (amount2 * (amount1 + 1)) / (vestedAmount + 1);
    if (bobStakedUSDe > 0) {
      _mintApproveDeposit(bob, amount2);
      totalContributions += amount2;
    }

    vm.warp(block.timestamp + waitSeconds);

    if (waitSeconds > 4 hours) {
      vestedAmount = totalContributions + rewardAmount;
    } else {
      vestedAmount = totalContributions + rewardAmount - ((4 hours - waitSeconds) * rewardAmount) / 4 hours;
    }

    _assertVestedAmountIs(vestedAmount);

    uint256 gregStakedUSDe = (amount3 * (stakedUSDe.totalSupply() + 1)) / (vestedAmount + 1);
    if (gregStakedUSDe > 0) {
      _mintApproveDeposit(greg, amount3);
      totalContributions += amount3;
    }

    vm.warp(block.timestamp + 8 hours);

    vestedAmount = totalContributions + rewardAmount;

    _assertVestedAmountIs(vestedAmount);

    uint256 usdePerStakedUSDeBefore = stakedUSDe.convertToAssets(1 ether);
    uint256 bobUnstakeAmount = (stakedUSDe.balanceOf(bob) * (vestedAmount + 1)) / (stakedUSDe.totalSupply() + 1);
    uint256 gregUnstakeAmount = (stakedUSDe.balanceOf(greg) * (vestedAmount + 1)) / (stakedUSDe.totalSupply() + 1);

    if (bobUnstakeAmount > 0) _redeem(bob, stakedUSDe.balanceOf(bob));
    uint256 usdePerStakedUSDeAfter = stakedUSDe.convertToAssets(1 ether);
    if (usdePerStakedUSDeAfter != 0) assertApproxEqAbs(usdePerStakedUSDeAfter, usdePerStakedUSDeBefore, 1 ether);

    if (gregUnstakeAmount > 0) _redeem(greg, stakedUSDe.balanceOf(greg));
    usdePerStakedUSDeAfter = stakedUSDe.convertToAssets(1 ether);
    if (usdePerStakedUSDeAfter != 0) assertApproxEqAbs(usdePerStakedUSDeAfter, usdePerStakedUSDeBefore, 1 ether);

    _redeem(alice, amount1);

    assertEq(stakedUSDe.totalSupply(), 0);
    assertApproxEqAbs(stakedUSDe.totalAssets(), 0, 10 ** 12);
  }

  function testTransferRewardsFailsInsufficientBalance() public {
    usdeToken.mint(address(rewarder), 99);
    vm.startPrank(rewarder);

    usdeToken.approve(address(stakedUSDe), 100);

    vm.expectRevert("ERC20: transfer amount exceeds balance");
    stakedUSDe.transferInRewards(100);
    vm.stopPrank();
  }

  function testTransferRewardsFailsZeroAmount() public {
    usdeToken.mint(address(rewarder), 100);
    vm.startPrank(rewarder);

    usdeToken.approve(address(stakedUSDe), 100);

    vm.expectRevert(IStakedUSDe.InvalidAmount.selector);
    stakedUSDe.transferInRewards(0);
    vm.stopPrank();
  }

  function testDecimalsIs18() public {
    assertEq(stakedUSDe.decimals(), 18);
  }

  function testMintWithSlippageCheck(uint256 amount) public {
    amount = bound(amount, 1 ether, type(uint256).max / 2);
    usdeToken.mint(alice, amount * 2);

    assertEq(stakedUSDe.balanceOf(alice), 0);

    vm.startPrank(alice);
    usdeToken.approve(address(stakedUSDe), amount);
    vm.expectEmit(true, true, true, true);
    emit Deposit(alice, alice, amount, amount);
    stakedUSDe.mint(amount, alice);

    assertEq(stakedUSDe.balanceOf(alice), amount);

    usdeToken.approve(address(stakedUSDe), amount);
    vm.expectEmit(true, true, true, true);
    emit Deposit(alice, alice, amount, amount);
    stakedUSDe.mint(amount, alice);

    assertEq(stakedUSDe.balanceOf(alice), amount * 2);
  }

  function testMintToDiffRecipient() public {
    usdeToken.mint(alice, 1 ether);

    vm.startPrank(alice);

    usdeToken.approve(address(stakedUSDe), 1 ether);

    stakedUSDe.deposit(1 ether, bob);

    assertEq(stakedUSDe.balanceOf(alice), 0);
    assertEq(stakedUSDe.balanceOf(bob), 1 ether);
  }

  function testCannotTransferRewardsWhileVesting() public {
    _transferRewards(100 ether, 100 ether);
    vm.warp(block.timestamp + 4 hours);
    _assertVestedAmountIs(50 ether);
    vm.prank(rewarder);
    vm.expectRevert(IStakedUSDe.StillVesting.selector);
    stakedUSDe.transferInRewards(100 ether);
    _assertVestedAmountIs(50 ether);
    assertEq(stakedUSDe.vestingAmount(), 100 ether);
  }

  function testCanTransferRewardsAfterVesting() public {
    _transferRewards(100 ether, 100 ether);
    vm.warp(block.timestamp + 8 hours);
    _assertVestedAmountIs(100 ether);
    _transferRewards(100 ether, 100 ether);
    vm.warp(block.timestamp + 8 hours);
    _assertVestedAmountIs(200 ether);
  }

  function testDonationAttack() public {
    uint256 initialStake = 1 ether;
    uint256 donationAmount = 10_000_000_000 ether;
    uint256 bobStake = 100 ether;
    _mintApproveDeposit(alice, initialStake);
    assertEq(stakedUSDe.totalSupply(), initialStake);
    usdeToken.mint(alice, donationAmount);
    vm.prank(alice);
    usdeToken.transfer(address(stakedUSDe), donationAmount);
    assertEq(stakedUSDe.totalSupply(), initialStake);
    assertEq(usdeToken.balanceOf(address(stakedUSDe)), initialStake + donationAmount);
    _mintApproveDeposit(bob, bobStake);
    uint256 bobStUSDeBal = stakedUSDe.balanceOf(bob);
    uint256 bobStUSDeExpectedBal = (bobStake * initialStake) / (initialStake + donationAmount);
    assertApproxEqAbs(bobStUSDeBal, bobStUSDeExpectedBal, 1e9);
    assertTrue(bobStUSDeBal > 0);
  }
}

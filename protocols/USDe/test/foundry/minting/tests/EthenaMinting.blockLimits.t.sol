// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase  */

import "../EthenaMinting.utils.sol";

contract EthenaMintingBlockLimitsTest is EthenaMintingUtils {
  /**
   * Max mint per block tests
   */

  // Ensures that the minted per block amount raises accordingly
  // when multiple mints are performed
  function test_multiple_mints() public {
    uint256 maxMintAmount = EthenaMintingContract.maxMintPerBlock();
    uint256 firstMintAmount = maxMintAmount / 4;
    uint256 secondMintAmount = maxMintAmount / 2;
    (
      IEthenaMinting.Order memory aOrder,
      IEthenaMinting.Signature memory aTakerSignature,
      IEthenaMinting.Route memory aRoute
    ) = mint_setup(firstMintAmount, _stETHToDeposit, 1, false);

    vm.prank(minter);
    EthenaMintingContract.mint(aOrder, aRoute, aTakerSignature);

    vm.prank(owner);
    stETHToken.mint(_stETHToDeposit, benefactor);

    (
      IEthenaMinting.Order memory bOrder,
      IEthenaMinting.Signature memory bTakerSignature,
      IEthenaMinting.Route memory bRoute
    ) = mint_setup(secondMintAmount, _stETHToDeposit, 2, true);
    vm.prank(minter);
    EthenaMintingContract.mint(bOrder, bRoute, bTakerSignature);

    assertEq(
      EthenaMintingContract.mintedPerBlock(block.number), firstMintAmount + secondMintAmount, "Incorrect minted amount"
    );
    assertTrue(
      EthenaMintingContract.mintedPerBlock(block.number) < maxMintAmount, "Mint amount exceeded without revert"
    );
  }

  function test_fuzz_maxMint_perBlock_exceeded_revert(uint256 excessiveMintAmount) public {
    // This amount is always greater than the allowed max mint per block
    vm.assume(excessiveMintAmount > EthenaMintingContract.maxMintPerBlock());

    maxMint_perBlock_exceeded_revert(excessiveMintAmount);
  }

  function test_fuzz_mint_maxMint_perBlock_exceeded_revert(uint256 excessiveMintAmount) public {
    vm.assume(excessiveMintAmount > EthenaMintingContract.maxMintPerBlock());
    (
      IEthenaMinting.Order memory mintOrder,
      IEthenaMinting.Signature memory takerSignature,
      IEthenaMinting.Route memory route
    ) = mint_setup(excessiveMintAmount, _stETHToDeposit, 1, false);

    // maker
    vm.startPrank(minter);
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit);
    assertEq(usdeToken.balanceOf(beneficiary), 0);

    vm.expectRevert(MaxMintPerBlockExceeded);
    // minter passes in permit signature data
    EthenaMintingContract.mint(mintOrder, route, takerSignature);

    assertEq(
      stETHToken.balanceOf(benefactor),
      _stETHToDeposit,
      "The benefactor stEth balance should be the same as the minted stEth"
    );
    assertEq(usdeToken.balanceOf(beneficiary), 0, "The beneficiary USDe balance should be 0");
  }

  function test_fuzz_nextBlock_mint_is_zero(uint256 mintAmount) public {
    vm.assume(mintAmount < EthenaMintingContract.maxMintPerBlock() && mintAmount > 0);
    (
      IEthenaMinting.Order memory order,
      IEthenaMinting.Signature memory takerSignature,
      IEthenaMinting.Route memory route
    ) = mint_setup(_usdeToMint, _stETHToDeposit, 1, false);

    vm.prank(minter);
    EthenaMintingContract.mint(order, route, takerSignature);

    vm.roll(block.number + 1);

    assertEq(
      EthenaMintingContract.mintedPerBlock(block.number), 0, "The minted amount should reset to 0 in the next block"
    );
  }

  function test_fuzz_maxMint_perBlock_setter(uint256 newMaxMintPerBlock) public {
    vm.assume(newMaxMintPerBlock > 0);

    uint256 oldMaxMintPerBlock = EthenaMintingContract.maxMintPerBlock();

    vm.prank(owner);
    vm.expectEmit();
    emit MaxMintPerBlockChanged(oldMaxMintPerBlock, newMaxMintPerBlock);

    EthenaMintingContract.setMaxMintPerBlock(newMaxMintPerBlock);

    assertEq(EthenaMintingContract.maxMintPerBlock(), newMaxMintPerBlock, "The max mint per block setter failed");
  }

  /**
   * Max redeem per block tests
   */

  // Ensures that the redeemed per block amount raises accordingly
  // when multiple mints are performed
  function test_multiple_redeem() public {
    uint256 maxRedeemAmount = EthenaMintingContract.maxRedeemPerBlock();
    uint256 firstRedeemAmount = maxRedeemAmount / 4;
    uint256 secondRedeemAmount = maxRedeemAmount / 2;

    (IEthenaMinting.Order memory redeemOrder, IEthenaMinting.Signature memory takerSignature2) =
      redeem_setup(firstRedeemAmount, _stETHToDeposit, 1, false);

    vm.prank(redeemer);
    EthenaMintingContract.redeem(redeemOrder, takerSignature2);

    vm.prank(owner);
    stETHToken.mint(_stETHToDeposit, benefactor);

    (IEthenaMinting.Order memory bRedeemOrder, IEthenaMinting.Signature memory bTakerSignature2) =
      redeem_setup(secondRedeemAmount, _stETHToDeposit, 2, true);

    vm.prank(redeemer);
    EthenaMintingContract.redeem(bRedeemOrder, bTakerSignature2);

    assertEq(
      EthenaMintingContract.mintedPerBlock(block.number),
      firstRedeemAmount + secondRedeemAmount,
      "Incorrect minted amount"
    );
    assertTrue(
      EthenaMintingContract.redeemedPerBlock(block.number) < maxRedeemAmount, "Redeem amount exceeded without revert"
    );
  }

  function test_fuzz_maxRedeem_perBlock_exceeded_revert(uint256 excessiveRedeemAmount) public {
    // This amount is always greater than the allowed max redeem per block
    vm.assume(excessiveRedeemAmount > EthenaMintingContract.maxRedeemPerBlock());

    // Set the max mint per block to the same value as the max redeem in order to get to the redeem
    vm.prank(owner);
    EthenaMintingContract.setMaxMintPerBlock(excessiveRedeemAmount);

    (IEthenaMinting.Order memory redeemOrder, IEthenaMinting.Signature memory takerSignature2) =
      redeem_setup(excessiveRedeemAmount, _stETHToDeposit, 1, false);

    vm.startPrank(redeemer);
    vm.expectRevert(MaxRedeemPerBlockExceeded);
    EthenaMintingContract.redeem(redeemOrder, takerSignature2);

    assertEq(stETHToken.balanceOf(address(EthenaMintingContract)), _stETHToDeposit, "Mismatch in stETH balance");
    assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in stETH balance");
    assertEq(usdeToken.balanceOf(beneficiary), excessiveRedeemAmount, "Mismatch in USDe balance");

    vm.stopPrank();
  }

  function test_fuzz_nextBlock_redeem_is_zero(uint256 redeemAmount) public {
    vm.assume(redeemAmount < EthenaMintingContract.maxRedeemPerBlock() && redeemAmount > 0);
    (IEthenaMinting.Order memory redeemOrder, IEthenaMinting.Signature memory takerSignature2) =
      redeem_setup(redeemAmount, _stETHToDeposit, 1, false);

    vm.startPrank(redeemer);
    EthenaMintingContract.redeem(redeemOrder, takerSignature2);

    vm.roll(block.number + 1);

    assertEq(
      EthenaMintingContract.redeemedPerBlock(block.number), 0, "The redeemed amount should reset to 0 in the next block"
    );
    vm.stopPrank();
  }

  function test_fuzz_maxRedeem_perBlock_setter(uint256 newMaxRedeemPerBlock) public {
    vm.assume(newMaxRedeemPerBlock > 0);

    uint256 oldMaxRedeemPerBlock = EthenaMintingContract.maxMintPerBlock();

    vm.prank(owner);
    vm.expectEmit();
    emit MaxRedeemPerBlockChanged(oldMaxRedeemPerBlock, newMaxRedeemPerBlock);
    EthenaMintingContract.setMaxRedeemPerBlock(newMaxRedeemPerBlock);

    assertEq(EthenaMintingContract.maxRedeemPerBlock(), newMaxRedeemPerBlock, "The max redeem per block setter failed");
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase  */

import "./MintingBaseSetup.sol";
import "forge-std/console.sol";

// These functions are reused across multiple files
contract EthenaMintingUtils is MintingBaseSetup {
  function maxMint_perBlock_exceeded_revert(uint256 excessiveMintAmount) public {
    // This amount is always greater than the allowed max mint per block
    vm.assume(excessiveMintAmount > EthenaMintingContract.maxMintPerBlock());
    (
      IEthenaMinting.Order memory order,
      IEthenaMinting.Signature memory takerSignature,
      IEthenaMinting.Route memory route
    ) = mint_setup(excessiveMintAmount, _stETHToDeposit, 1, false);

    vm.prank(minter);
    vm.expectRevert(MaxMintPerBlockExceeded);
    EthenaMintingContract.mint(order, route, takerSignature);

    assertEq(usdeToken.balanceOf(beneficiary), 0, "The beneficiary balance should be 0");
    assertEq(stETHToken.balanceOf(address(EthenaMintingContract)), 0, "The ethena minting stETH balance should be 0");
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in stETH balance");
  }

  function maxRedeem_perBlock_exceeded_revert(uint256 excessiveRedeemAmount) public {
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

  function executeMint() public {
    (
      IEthenaMinting.Order memory order,
      IEthenaMinting.Signature memory takerSignature,
      IEthenaMinting.Route memory route
    ) = mint_setup(_usdeToMint, _stETHToDeposit, 1, false);

    vm.prank(minter);
    EthenaMintingContract.mint(order, route, takerSignature);
  }

  function executeRedeem() public {
    (IEthenaMinting.Order memory redeemOrder, IEthenaMinting.Signature memory takerSignature2) =
      redeem_setup(_usdeToMint, _stETHToDeposit, 1, false);
    vm.prank(redeemer);
    EthenaMintingContract.redeem(redeemOrder, takerSignature2);
  }
}

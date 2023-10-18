// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../EthenaMinting.utils.sol";

contract EthenaMintingDelegateTest is EthenaMintingUtils {
  function setUp() public override {
    super.setUp();
  }

  function testDelegateSuccessfulMint() public {
    (IEthenaMinting.Order memory order,, IEthenaMinting.Route memory route) =
      mint_setup(_usdeToMint, _stETHToDeposit, 1, false);

    vm.prank(benefactor);
    EthenaMintingContract.setDelegatedSigner(trader2);

    bytes32 digest1 = EthenaMintingContract.hashOrder(order);
    vm.prank(trader2);
    IEthenaMinting.Signature memory trader2Sig =
      signOrder(trader2PrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)), 0, "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in benefactor stETH balance before mint");
    assertEq(usdeToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary USDe balance before mint");

    vm.prank(minter);
    EthenaMintingContract.mint(order, route, trader2Sig);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)),
      _stETHToDeposit,
      "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary stETH balance after mint");
    assertEq(usdeToken.balanceOf(beneficiary), _usdeToMint, "Mismatch in beneficiary USDe balance after mint");
  }

  function testDelegateFailureMint() public {
    (IEthenaMinting.Order memory order,, IEthenaMinting.Route memory route) =
      mint_setup(_usdeToMint, _stETHToDeposit, 1, false);

    // omit delegation by benefactor

    bytes32 digest1 = EthenaMintingContract.hashOrder(order);
    vm.prank(trader2);
    IEthenaMinting.Signature memory trader2Sig =
      signOrder(trader2PrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)), 0, "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in benefactor stETH balance before mint");
    assertEq(usdeToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary USDe balance before mint");

    vm.prank(minter);
    vm.expectRevert(InvalidSignature);
    EthenaMintingContract.mint(order, route, trader2Sig);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)), 0, "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in beneficiary stETH balance after mint");
    assertEq(usdeToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary USDe balance after mint");
  }

  function testDelegateSuccessfulRedeem() public {
    (IEthenaMinting.Order memory order,) = redeem_setup(_usdeToMint, _stETHToDeposit, 1, false);

    vm.prank(beneficiary);
    EthenaMintingContract.setDelegatedSigner(trader2);

    bytes32 digest1 = EthenaMintingContract.hashOrder(order);
    vm.prank(trader2);
    IEthenaMinting.Signature memory trader2Sig =
      signOrder(trader2PrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)),
      _stETHToDeposit,
      "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary stETH balance before mint");
    assertEq(usdeToken.balanceOf(beneficiary), _usdeToMint, "Mismatch in beneficiary USDe balance before mint");

    vm.prank(redeemer);
    EthenaMintingContract.redeem(order, trader2Sig);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)), 0, "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(stETHToken.balanceOf(beneficiary), _stETHToDeposit, "Mismatch in beneficiary stETH balance after mint");
    assertEq(usdeToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary USDe balance after mint");
  }

  function testDelegateFailureRedeem() public {
    (IEthenaMinting.Order memory order,) = redeem_setup(_usdeToMint, _stETHToDeposit, 1, false);

    // omit delegation by beneficiary

    bytes32 digest1 = EthenaMintingContract.hashOrder(order);
    vm.prank(trader2);
    IEthenaMinting.Signature memory trader2Sig =
      signOrder(trader2PrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)),
      _stETHToDeposit,
      "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary stETH balance before mint");
    assertEq(usdeToken.balanceOf(beneficiary), _usdeToMint, "Mismatch in beneficiary USDe balance before mint");

    vm.prank(redeemer);
    vm.expectRevert(InvalidSignature);
    EthenaMintingContract.redeem(order, trader2Sig);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)),
      _stETHToDeposit,
      "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary stETH balance after mint");
    assertEq(usdeToken.balanceOf(beneficiary), _usdeToMint, "Mismatch in beneficiary USDe balance after mint");
  }

  function testCanUndelegate() public {
    (IEthenaMinting.Order memory order,, IEthenaMinting.Route memory route) =
      mint_setup(_usdeToMint, _stETHToDeposit, 1, false);

    // delegate and then undelegate
    vm.startPrank(benefactor);
    EthenaMintingContract.setDelegatedSigner(trader2);
    EthenaMintingContract.removeDelegatedSigner(trader2);
    vm.stopPrank();

    bytes32 digest1 = EthenaMintingContract.hashOrder(order);
    vm.prank(trader2);
    IEthenaMinting.Signature memory trader2Sig =
      signOrder(trader2PrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)), 0, "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in benefactor stETH balance before mint");
    assertEq(usdeToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary USDe balance before mint");

    vm.prank(minter);
    vm.expectRevert(InvalidSignature);
    EthenaMintingContract.mint(order, route, trader2Sig);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)), 0, "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in beneficiary stETH balance after mint");
    assertEq(usdeToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary USDe balance after mint");
  }
}

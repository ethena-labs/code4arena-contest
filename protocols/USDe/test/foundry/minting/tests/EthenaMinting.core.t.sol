// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase  */

import "../EthenaMinting.utils.sol";

contract EthenaMintingCoreTest is EthenaMintingUtils {
  function setUp() public override {
    super.setUp();
  }

  function test_mint() public {
    executeMint();
  }

  function test_redeem() public {
    executeRedeem();
    assertEq(stETHToken.balanceOf(address(EthenaMintingContract)), 0, "Mismatch in stETH balance");
    assertEq(stETHToken.balanceOf(beneficiary), _stETHToDeposit, "Mismatch in stETH balance");
    assertEq(usdeToken.balanceOf(beneficiary), 0, "Mismatch in USDe balance");
  }

  function test_redeem_invalidNonce_revert() public {
    // Unset the max redeem per block limit
    vm.prank(owner);
    EthenaMintingContract.setMaxRedeemPerBlock(type(uint256).max);

    (IEthenaMinting.Order memory redeemOrder, IEthenaMinting.Signature memory takerSignature2) =
      redeem_setup(_usdeToMint, _stETHToDeposit, 1, false);

    vm.startPrank(redeemer);
    EthenaMintingContract.redeem(redeemOrder, takerSignature2);

    vm.expectRevert(InvalidNonce);
    EthenaMintingContract.redeem(redeemOrder, takerSignature2);
  }

  function test_nativeEth_withdraw() public {
    vm.deal(address(EthenaMintingContract), _stETHToDeposit);

    IEthenaMinting.Order memory order = IEthenaMinting.Order({
      order_type: IEthenaMinting.OrderType.MINT,
      expiry: block.timestamp + 10 minutes,
      nonce: 8,
      benefactor: benefactor,
      beneficiary: benefactor,
      collateral_asset: address(stETHToken),
      collateral_amount: _stETHToDeposit,
      usde_amount: _usdeToMint
    });

    address[] memory targets = new address[](1);
    targets[0] = address(EthenaMintingContract);

    uint256[] memory ratios = new uint256[](1);
    ratios[0] = 10_000;

    IEthenaMinting.Route memory route = IEthenaMinting.Route({addresses: targets, ratios: ratios});

    // taker
    vm.startPrank(benefactor);
    stETHToken.approve(address(EthenaMintingContract), _stETHToDeposit);

    bytes32 digest1 = EthenaMintingContract.hashOrder(order);
    IEthenaMinting.Signature memory takerSignature =
      signOrder(benefactorPrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);
    vm.stopPrank();

    assertEq(usdeToken.balanceOf(benefactor), 0);

    vm.recordLogs();
    vm.prank(minter);
    EthenaMintingContract.mint(order, route, takerSignature);
    vm.getRecordedLogs();

    assertEq(usdeToken.balanceOf(benefactor), _usdeToMint);

    //redeem
    IEthenaMinting.Order memory redeemOrder = IEthenaMinting.Order({
      order_type: IEthenaMinting.OrderType.REDEEM,
      expiry: block.timestamp + 10 minutes,
      nonce: 800,
      benefactor: benefactor,
      beneficiary: benefactor,
      collateral_asset: NATIVE_TOKEN,
      usde_amount: _usdeToMint,
      collateral_amount: _stETHToDeposit
    });

    // taker
    vm.startPrank(benefactor);
    usdeToken.approve(address(EthenaMintingContract), _usdeToMint);

    bytes32 digest3 = EthenaMintingContract.hashOrder(redeemOrder);
    IEthenaMinting.Signature memory takerSignature2 =
      signOrder(benefactorPrivateKey, digest3, IEthenaMinting.SignatureType.EIP712);
    vm.stopPrank();

    vm.startPrank(redeemer);
    EthenaMintingContract.redeem(redeemOrder, takerSignature2);

    assertEq(stETHToken.balanceOf(benefactor), 0);
    assertEq(usdeToken.balanceOf(benefactor), 0);
    assertEq(benefactor.balance, _stETHToDeposit);

    vm.stopPrank();
  }

  function test_fuzz_mint_noSlippage(uint256 expectedAmount) public {
    vm.assume(expectedAmount > 0 && expectedAmount < _maxMintPerBlock);

    (
      IEthenaMinting.Order memory order,
      IEthenaMinting.Signature memory takerSignature,
      IEthenaMinting.Route memory route
    ) = mint_setup(expectedAmount, _stETHToDeposit, 1, false);

    vm.recordLogs();
    vm.prank(minter);
    EthenaMintingContract.mint(order, route, takerSignature);
    vm.getRecordedLogs();
    assertEq(stETHToken.balanceOf(benefactor), 0);
    assertEq(stETHToken.balanceOf(address(EthenaMintingContract)), _stETHToDeposit);
    assertEq(usdeToken.balanceOf(beneficiary), expectedAmount);
  }

  function test_multipleValid_custodyRatios_addresses() public {
    uint256 _smallUsdeToMint = 1.75 * 10 ** 23;
    IEthenaMinting.Order memory order = IEthenaMinting.Order({
      order_type: IEthenaMinting.OrderType.MINT,
      expiry: block.timestamp + 10 minutes,
      nonce: 14,
      benefactor: benefactor,
      beneficiary: beneficiary,
      collateral_asset: address(stETHToken),
      collateral_amount: _stETHToDeposit,
      usde_amount: _smallUsdeToMint
    });

    address[] memory targets = new address[](3);
    targets[0] = address(EthenaMintingContract);
    targets[1] = custodian1;
    targets[2] = custodian2;

    uint256[] memory ratios = new uint256[](3);
    ratios[0] = 3_000;
    ratios[1] = 4_000;
    ratios[2] = 3_000;

    IEthenaMinting.Route memory route = IEthenaMinting.Route({addresses: targets, ratios: ratios});

    // taker
    vm.startPrank(benefactor);
    stETHToken.approve(address(EthenaMintingContract), _stETHToDeposit);

    bytes32 digest1 = EthenaMintingContract.hashOrder(order);
    IEthenaMinting.Signature memory takerSignature =
      signOrder(benefactorPrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);
    vm.stopPrank();

    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit);

    vm.prank(minter);
    vm.expectRevert(InvalidRoute);
    EthenaMintingContract.mint(order, route, takerSignature);

    vm.prank(owner);
    EthenaMintingContract.addCustodianAddress(custodian2);

    vm.prank(minter);
    EthenaMintingContract.mint(order, route, takerSignature);

    assertEq(stETHToken.balanceOf(benefactor), 0);
    assertEq(usdeToken.balanceOf(beneficiary), _smallUsdeToMint);

    assertEq(stETHToken.balanceOf(address(custodian1)), (_stETHToDeposit * 4) / 10);
    assertEq(stETHToken.balanceOf(address(custodian2)), (_stETHToDeposit * 3) / 10);
    assertEq(stETHToken.balanceOf(address(EthenaMintingContract)), (_stETHToDeposit * 3) / 10);

    // remove custodian and expect reversion
    vm.prank(owner);
    EthenaMintingContract.removeCustodianAddress(custodian2);

    vm.prank(minter);
    vm.expectRevert(InvalidRoute);
    EthenaMintingContract.mint(order, route, takerSignature);
  }

  function test_fuzz_multipleInvalid_custodyRatios_revert(uint256 ratio1) public {
    ratio1 = bound(ratio1, 0, UINT256_MAX - 7_000);
    vm.assume(ratio1 != 3_000);

    IEthenaMinting.Order memory mintOrder = IEthenaMinting.Order({
      order_type: IEthenaMinting.OrderType.MINT,
      expiry: block.timestamp + 10 minutes,
      nonce: 15,
      benefactor: benefactor,
      beneficiary: beneficiary,
      collateral_asset: address(stETHToken),
      collateral_amount: _stETHToDeposit,
      usde_amount: _usdeToMint
    });

    address[] memory targets = new address[](2);
    targets[0] = address(EthenaMintingContract);
    targets[1] = owner;

    uint256[] memory ratios = new uint256[](2);
    ratios[0] = ratio1;
    ratios[1] = 7_000;

    IEthenaMinting.Route memory route = IEthenaMinting.Route({addresses: targets, ratios: ratios});

    vm.startPrank(benefactor);
    stETHToken.approve(address(EthenaMintingContract), _stETHToDeposit);

    bytes32 digest1 = EthenaMintingContract.hashOrder(mintOrder);
    IEthenaMinting.Signature memory takerSignature =
      signOrder(benefactorPrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);
    vm.stopPrank();

    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit);

    vm.expectRevert(InvalidRoute);
    vm.prank(minter);
    EthenaMintingContract.mint(mintOrder, route, takerSignature);

    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit);
    assertEq(usdeToken.balanceOf(beneficiary), 0);

    assertEq(stETHToken.balanceOf(address(EthenaMintingContract)), 0);
    assertEq(stETHToken.balanceOf(owner), 0);
  }

  function test_fuzz_singleInvalid_custodyRatio_revert(uint256 ratio1) public {
    vm.assume(ratio1 != 10_000);

    IEthenaMinting.Order memory order = IEthenaMinting.Order({
      order_type: IEthenaMinting.OrderType.MINT,
      expiry: block.timestamp + 10 minutes,
      nonce: 16,
      benefactor: benefactor,
      beneficiary: beneficiary,
      collateral_asset: address(stETHToken),
      collateral_amount: _stETHToDeposit,
      usde_amount: _usdeToMint
    });

    address[] memory targets = new address[](1);
    targets[0] = address(EthenaMintingContract);

    uint256[] memory ratios = new uint256[](1);
    ratios[0] = ratio1;

    IEthenaMinting.Route memory route = IEthenaMinting.Route({addresses: targets, ratios: ratios});

    // taker
    vm.startPrank(benefactor);
    stETHToken.approve(address(EthenaMintingContract), _stETHToDeposit);

    bytes32 digest1 = EthenaMintingContract.hashOrder(order);
    IEthenaMinting.Signature memory takerSignature =
      signOrder(benefactorPrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);
    vm.stopPrank();

    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit);

    vm.expectRevert(InvalidRoute);
    vm.prank(minter);
    EthenaMintingContract.mint(order, route, takerSignature);

    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit);
    assertEq(usdeToken.balanceOf(beneficiary), 0);

    assertEq(stETHToken.balanceOf(address(EthenaMintingContract)), 0);
  }

  function test_unsupported_assets_ERC20_revert() public {
    vm.startPrank(owner);
    EthenaMintingContract.removeSupportedAsset(address(stETHToken));
    stETHToken.mint(_stETHToDeposit, benefactor);
    vm.stopPrank();

    IEthenaMinting.Order memory order = IEthenaMinting.Order({
      order_type: IEthenaMinting.OrderType.MINT,
      expiry: block.timestamp + 10 minutes,
      nonce: 18,
      benefactor: benefactor,
      beneficiary: beneficiary,
      collateral_asset: address(stETHToken),
      collateral_amount: _stETHToDeposit,
      usde_amount: _usdeToMint
    });

    address[] memory targets = new address[](1);
    targets[0] = address(EthenaMintingContract);

    uint256[] memory ratios = new uint256[](1);
    ratios[0] = 10_000;

    IEthenaMinting.Route memory route = IEthenaMinting.Route({addresses: targets, ratios: ratios});

    // taker
    vm.startPrank(benefactor);
    stETHToken.approve(address(EthenaMintingContract), _stETHToDeposit);

    bytes32 digest1 = EthenaMintingContract.hashOrder(order);
    IEthenaMinting.Signature memory takerSignature =
      signOrder(benefactorPrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);
    vm.stopPrank();

    vm.recordLogs();
    vm.expectRevert(UnsupportedAsset);
    vm.prank(minter);
    EthenaMintingContract.mint(order, route, takerSignature);
    vm.getRecordedLogs();
  }

  function test_unsupported_assets_ETH_revert() public {
    vm.startPrank(owner);
    vm.deal(benefactor, _stETHToDeposit);
    vm.stopPrank();

    IEthenaMinting.Order memory order = IEthenaMinting.Order({
      order_type: IEthenaMinting.OrderType.MINT,
      expiry: block.timestamp + 10 minutes,
      nonce: 19,
      benefactor: benefactor,
      beneficiary: beneficiary,
      collateral_asset: NATIVE_TOKEN,
      collateral_amount: _stETHToDeposit,
      usde_amount: _usdeToMint
    });

    address[] memory targets = new address[](1);
    targets[0] = address(EthenaMintingContract);

    uint256[] memory ratios = new uint256[](1);
    ratios[0] = 10_000;

    IEthenaMinting.Route memory route = IEthenaMinting.Route({addresses: targets, ratios: ratios});

    // taker
    vm.startPrank(benefactor);
    stETHToken.approve(address(EthenaMintingContract), _stETHToDeposit);

    bytes32 digest1 = EthenaMintingContract.hashOrder(order);
    IEthenaMinting.Signature memory takerSignature =
      signOrder(benefactorPrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);
    vm.stopPrank();

    vm.recordLogs();
    vm.expectRevert(UnsupportedAsset);
    vm.prank(minter);
    EthenaMintingContract.mint(order, route, takerSignature);
    vm.getRecordedLogs();
  }

  function test_expired_orders_revert() public {
    (
      IEthenaMinting.Order memory order,
      IEthenaMinting.Signature memory takerSignature,
      IEthenaMinting.Route memory route
    ) = mint_setup(_usdeToMint, _stETHToDeposit, 1, false);

    vm.warp(block.timestamp + 11 minutes);

    vm.recordLogs();
    vm.expectRevert(SignatureExpired);
    vm.prank(minter);
    EthenaMintingContract.mint(order, route, takerSignature);
    vm.getRecordedLogs();
  }

  function test_add_and_remove_supported_asset() public {
    address asset = address(20);
    vm.expectEmit(true, false, false, false);
    emit AssetAdded(asset);
    vm.startPrank(owner);
    EthenaMintingContract.addSupportedAsset(asset);
    assertTrue(EthenaMintingContract.isSupportedAsset(asset));

    vm.expectEmit(true, false, false, false);
    emit AssetRemoved(asset);
    EthenaMintingContract.removeSupportedAsset(asset);
    assertFalse(EthenaMintingContract.isSupportedAsset(asset));
  }

  function test_cannot_add_asset_already_supported_revert() public {
    address asset = address(20);
    vm.expectEmit(true, false, false, false);
    emit AssetAdded(asset);
    vm.startPrank(owner);
    EthenaMintingContract.addSupportedAsset(asset);
    assertTrue(EthenaMintingContract.isSupportedAsset(asset));

    vm.expectRevert(InvalidAssetAddress);
    EthenaMintingContract.addSupportedAsset(asset);
  }

  function test_cannot_removeAsset_not_supported_revert() public {
    address asset = address(20);
    assertFalse(EthenaMintingContract.isSupportedAsset(asset));

    vm.prank(owner);
    vm.expectRevert(InvalidAssetAddress);
    EthenaMintingContract.removeSupportedAsset(asset);
  }

  function test_cannotAdd_addressZero_revert() public {
    vm.prank(owner);
    vm.expectRevert(InvalidAssetAddress);
    EthenaMintingContract.addSupportedAsset(address(0));
  }

  function test_cannotAdd_USDe_revert() public {
    vm.prank(owner);
    vm.expectRevert(InvalidAssetAddress);
    EthenaMintingContract.addSupportedAsset(address(usdeToken));
  }

  function test_sending_redeem_order_to_mint_revert() public {
    (IEthenaMinting.Order memory order, IEthenaMinting.Signature memory takerSignature) =
      redeem_setup(1 ether, 50 ether, 20, false);

    address[] memory targets = new address[](1);
    targets[0] = address(EthenaMintingContract);

    uint256[] memory ratios = new uint256[](1);
    ratios[0] = 10_000;

    IEthenaMinting.Route memory route = IEthenaMinting.Route({addresses: targets, ratios: ratios});

    vm.expectRevert(InvalidOrder);
    vm.prank(minter);
    EthenaMintingContract.mint(order, route, takerSignature);
  }

  function test_sending_mint_order_to_redeem_revert() public {
    (IEthenaMinting.Order memory order, IEthenaMinting.Signature memory takerSignature,) =
      mint_setup(1 ether, 50 ether, 20, false);

    vm.expectRevert(InvalidOrder);
    vm.prank(redeemer);
    EthenaMintingContract.redeem(order, takerSignature);
  }

  function test_receive_eth() public {
    assertEq(address(EthenaMintingContract).balance, 0);
    vm.deal(owner, 10_000 ether);
    vm.prank(owner);
    (bool success,) = address(EthenaMintingContract).call{value: 10_000 ether}("");
    assertTrue(success);
    assertEq(address(EthenaMintingContract).balance, 10_000 ether);
  }
}

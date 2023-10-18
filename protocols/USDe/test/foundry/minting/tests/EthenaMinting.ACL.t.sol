// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase  */

import "../EthenaMinting.utils.sol";
import "../../../../contracts/interfaces/ISingleAdminAccessControl.sol";

contract EthenaMintingACLTest is EthenaMintingUtils {
  function setUp() public override {
    super.setUp();
  }

  function test_role_authorization() public {
    vm.deal(trader1, 1 ether);
    vm.deal(maker1, 1 ether);
    vm.deal(maker2, 1 ether);
    vm.startPrank(minter);
    stETHToken.mint(1 * 1e18, maker1);
    stETHToken.mint(1 * 1e18, trader1);
    vm.expectRevert(OnlyMinterErr);
    usdeToken.mint(address(maker2), 2000 * 1e18);
    vm.expectRevert(OnlyMinterErr);
    usdeToken.mint(address(trader2), 2000 * 1e18);
  }

  function test_redeem_notRedeemer_revert() public {
    (IEthenaMinting.Order memory redeemOrder, IEthenaMinting.Signature memory takerSignature2) =
      redeem_setup(_usdeToMint, _stETHToDeposit, 1, false);

    vm.startPrank(minter);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(minter), " is missing role ", vm.toString(redeemerRole)
        )
      )
    );
    EthenaMintingContract.redeem(redeemOrder, takerSignature2);
  }

  function test_fuzz_notMinter_cannot_mint(address nonMinter) public {
    (
      IEthenaMinting.Order memory mintOrder,
      IEthenaMinting.Signature memory takerSignature,
      IEthenaMinting.Route memory route
    ) = mint_setup(_usdeToMint, _stETHToDeposit, 1, false);

    vm.assume(nonMinter != minter);
    vm.startPrank(nonMinter);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(nonMinter), " is missing role ", vm.toString(minterRole)
        )
      )
    );
    EthenaMintingContract.mint(mintOrder, route, takerSignature);

    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit);
    assertEq(usdeToken.balanceOf(beneficiary), 0);
  }

  function test_fuzz_nonOwner_cannot_add_supportedAsset_revert(address nonOwner) public {
    vm.assume(nonOwner != owner);
    address asset = address(20);
    vm.expectRevert();
    vm.prank(nonOwner);
    EthenaMintingContract.addSupportedAsset(asset);
    assertFalse(EthenaMintingContract.isSupportedAsset(asset));
  }

  function test_fuzz_nonOwner_cannot_remove_supportedAsset_revert(address nonOwner) public {
    vm.assume(nonOwner != owner);
    address asset = address(20);
    vm.prank(owner);
    vm.expectEmit(true, false, false, false);
    emit AssetAdded(asset);
    EthenaMintingContract.addSupportedAsset(asset);
    assertTrue(EthenaMintingContract.isSupportedAsset(asset));

    vm.expectRevert();
    vm.prank(nonOwner);
    EthenaMintingContract.removeSupportedAsset(asset);
    assertTrue(EthenaMintingContract.isSupportedAsset(asset));
  }

  function test_minter_canTransfer_custody() public {
    vm.startPrank(owner);
    stETHToken.mint(1000, address(EthenaMintingContract));
    EthenaMintingContract.addCustodianAddress(beneficiary);
    vm.stopPrank();
    vm.prank(minter);
    vm.expectEmit(true, true, true, true);
    emit CustodyTransfer(beneficiary, address(stETHToken), 1000);
    EthenaMintingContract.transferToCustody(beneficiary, address(stETHToken), 1000);
    assertEq(stETHToken.balanceOf(beneficiary), 1000);
    assertEq(stETHToken.balanceOf(address(EthenaMintingContract)), 0);
  }

  function test_fuzz_nonMinter_cannot_transferCustody_revert(address nonMinter) public {
    vm.assume(nonMinter != minter);
    stETHToken.mint(1000, address(EthenaMintingContract));

    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(nonMinter), " is missing role ", vm.toString(minterRole)
        )
      )
    );
    vm.prank(nonMinter);
    EthenaMintingContract.transferToCustody(beneficiary, address(stETHToken), 1000);
  }

  /**
   * Gatekeeper tests
   */

  function test_gatekeeper_can_remove_minter() public {
    vm.prank(gatekeeper);

    EthenaMintingContract.removeMinterRole(minter);
    assertFalse(EthenaMintingContract.hasRole(minterRole, minter));
  }

  function test_gatekeeper_can_remove_redeemer() public {
    vm.prank(gatekeeper);

    EthenaMintingContract.removeRedeemerRole(redeemer);
    assertFalse(EthenaMintingContract.hasRole(redeemerRole, redeemer));
  }

  function test_fuzz_not_gatekeeper_cannot_remove_minter_revert(address notGatekeeper) public {
    vm.assume(notGatekeeper != gatekeeper);
    vm.startPrank(notGatekeeper);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ",
          Strings.toHexString(notGatekeeper),
          " is missing role ",
          vm.toString(gatekeeperRole)
        )
      )
    );
    EthenaMintingContract.removeMinterRole(minter);
    assertTrue(EthenaMintingContract.hasRole(minterRole, minter));
  }

  function test_fuzz_not_gatekeeper_cannot_remove_redeemer_revert(address notGatekeeper) public {
    vm.assume(notGatekeeper != gatekeeper);
    vm.startPrank(notGatekeeper);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ",
          Strings.toHexString(notGatekeeper),
          " is missing role ",
          vm.toString(gatekeeperRole)
        )
      )
    );
    EthenaMintingContract.removeRedeemerRole(redeemer);
    assertTrue(EthenaMintingContract.hasRole(redeemerRole, redeemer));
  }

  function test_gatekeeper_cannot_add_minters_revert() public {
    vm.startPrank(gatekeeper);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(gatekeeper), " is missing role ", vm.toString(adminRole)
        )
      )
    );
    EthenaMintingContract.grantRole(minterRole, bob);
    assertFalse(EthenaMintingContract.hasRole(minterRole, bob), "Bob should lack the minter role");
  }

  function test_gatekeeper_can_disable_mintRedeem() public {
    vm.startPrank(gatekeeper);
    EthenaMintingContract.disableMintRedeem();

    (
      IEthenaMinting.Order memory order,
      IEthenaMinting.Signature memory takerSignature,
      IEthenaMinting.Route memory route
    ) = mint_setup(_usdeToMint, _stETHToDeposit, 1, false);

    vm.prank(minter);
    vm.expectRevert(MaxMintPerBlockExceeded);
    EthenaMintingContract.mint(order, route, takerSignature);

    vm.prank(redeemer);
    vm.expectRevert(MaxRedeemPerBlockExceeded);
    EthenaMintingContract.redeem(order, takerSignature);

    assertEq(EthenaMintingContract.maxMintPerBlock(), 0, "Minting should be disabled");
    assertEq(EthenaMintingContract.maxRedeemPerBlock(), 0, "Redeeming should be disabled");
  }

  // Ensure that the gatekeeper is not allowed to enable/modify the minting
  function test_gatekeeper_cannot_enable_mint_revert() public {
    test_fuzz_nonAdmin_cannot_enable_mint_revert(gatekeeper);
  }

  // Ensure that the gatekeeper is not allowed to enable/modify the redeeming
  function test_gatekeeper_cannot_enable_redeem_revert() public {
    test_fuzz_nonAdmin_cannot_enable_redeem_revert(gatekeeper);
  }

  function test_fuzz_not_gatekeeper_cannot_disable_mintRedeem_revert(address notGatekeeper) public {
    vm.assume(notGatekeeper != gatekeeper);
    vm.startPrank(notGatekeeper);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ",
          Strings.toHexString(notGatekeeper),
          " is missing role ",
          vm.toString(gatekeeperRole)
        )
      )
    );
    EthenaMintingContract.disableMintRedeem();

    assertTrue(EthenaMintingContract.maxMintPerBlock() > 0);
    assertTrue(EthenaMintingContract.maxRedeemPerBlock() > 0);
  }

  /**
   * Admin tests
   */
  function test_admin_can_disable_mint(bool performCheckMint) public {
    vm.prank(owner);
    EthenaMintingContract.setMaxMintPerBlock(0);

    if (performCheckMint) maxMint_perBlock_exceeded_revert(1e18);

    assertEq(EthenaMintingContract.maxMintPerBlock(), 0, "The minting should be disabled");
  }

  function test_admin_can_disable_redeem(bool performCheckRedeem) public {
    vm.prank(owner);
    EthenaMintingContract.setMaxRedeemPerBlock(0);

    if (performCheckRedeem) maxRedeem_perBlock_exceeded_revert(1e18);

    assertEq(EthenaMintingContract.maxRedeemPerBlock(), 0, "The redeem should be disabled");
  }

  function test_admin_can_enable_mint() public {
    vm.startPrank(owner);
    EthenaMintingContract.setMaxMintPerBlock(0);

    assertEq(EthenaMintingContract.maxMintPerBlock(), 0, "The minting should be disabled");

    // Re-enable the minting
    EthenaMintingContract.setMaxMintPerBlock(_maxMintPerBlock);

    vm.stopPrank();

    executeMint();

    assertTrue(EthenaMintingContract.maxMintPerBlock() > 0, "The minting should be enabled");
  }

  function test_fuzz_nonAdmin_cannot_enable_mint_revert(address notAdmin) public {
    vm.assume(notAdmin != owner);

    test_admin_can_disable_mint(false);

    vm.prank(notAdmin);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(notAdmin), " is missing role ", vm.toString(adminRole)
        )
      )
    );
    EthenaMintingContract.setMaxMintPerBlock(_maxMintPerBlock);

    maxMint_perBlock_exceeded_revert(1e18);

    assertEq(EthenaMintingContract.maxMintPerBlock(), 0, "The minting should remain disabled");
  }

  function test_fuzz_nonAdmin_cannot_enable_redeem_revert(address notAdmin) public {
    vm.assume(notAdmin != owner);

    test_admin_can_disable_redeem(false);

    vm.prank(notAdmin);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(notAdmin), " is missing role ", vm.toString(adminRole)
        )
      )
    );
    EthenaMintingContract.setMaxRedeemPerBlock(_maxRedeemPerBlock);

    maxRedeem_perBlock_exceeded_revert(1e18);

    assertEq(EthenaMintingContract.maxRedeemPerBlock(), 0, "The redeeming should remain disabled");
  }

  function test_admin_can_enable_redeem() public {
    vm.startPrank(owner);
    EthenaMintingContract.setMaxRedeemPerBlock(0);

    assertEq(EthenaMintingContract.maxRedeemPerBlock(), 0, "The redeem should be disabled");

    // Re-enable the redeeming
    EthenaMintingContract.setMaxRedeemPerBlock(_maxRedeemPerBlock);

    vm.stopPrank();

    executeRedeem();

    assertTrue(EthenaMintingContract.maxRedeemPerBlock() > 0, "The redeeming should be enabled");
  }

  function test_admin_can_add_minter() public {
    vm.startPrank(owner);
    EthenaMintingContract.grantRole(minterRole, bob);

    assertTrue(EthenaMintingContract.hasRole(minterRole, bob), "Bob should have the minter role");
    vm.stopPrank();
  }

  function test_admin_can_remove_minter() public {
    test_admin_can_add_minter();

    vm.startPrank(owner);
    EthenaMintingContract.revokeRole(minterRole, bob);

    assertFalse(EthenaMintingContract.hasRole(minterRole, bob), "Bob should no longer have the minter role");

    vm.stopPrank();
  }

  function test_admin_can_add_gatekeeper() public {
    vm.startPrank(owner);
    EthenaMintingContract.grantRole(gatekeeperRole, bob);

    assertTrue(EthenaMintingContract.hasRole(gatekeeperRole, bob), "Bob should have the gatekeeper role");
    vm.stopPrank();
  }

  function test_admin_can_remove_gatekeeper() public {
    test_admin_can_add_gatekeeper();

    vm.startPrank(owner);
    EthenaMintingContract.revokeRole(gatekeeperRole, bob);

    assertFalse(EthenaMintingContract.hasRole(gatekeeperRole, bob), "Bob should no longer have the gatekeeper role");

    vm.stopPrank();
  }

  function test_fuzz_notAdmin_cannot_remove_minter(address notAdmin) public {
    test_admin_can_add_minter();

    vm.assume(notAdmin != owner);
    vm.startPrank(notAdmin);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(notAdmin), " is missing role ", vm.toString(adminRole)
        )
      )
    );
    EthenaMintingContract.revokeRole(minterRole, bob);

    assertTrue(EthenaMintingContract.hasRole(minterRole, bob), "Bob should maintain the minter role");
    vm.stopPrank();
  }

  function test_fuzz_notAdmin_cannot_remove_gatekeeper(address notAdmin) public {
    test_admin_can_add_gatekeeper();

    vm.assume(notAdmin != owner);
    vm.startPrank(notAdmin);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(notAdmin), " is missing role ", vm.toString(adminRole)
        )
      )
    );
    EthenaMintingContract.revokeRole(gatekeeperRole, bob);

    assertTrue(EthenaMintingContract.hasRole(gatekeeperRole, bob), "Bob should maintain the gatekeeper role");

    vm.stopPrank();
  }

  function test_fuzz_notAdmin_cannot_add_minter(address notAdmin) public {
    vm.assume(notAdmin != owner);
    vm.startPrank(notAdmin);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(notAdmin), " is missing role ", vm.toString(adminRole)
        )
      )
    );
    EthenaMintingContract.grantRole(minterRole, bob);

    assertFalse(EthenaMintingContract.hasRole(minterRole, bob), "Bob should lack the minter role");
    vm.stopPrank();
  }

  function test_fuzz_notAdmin_cannot_add_gatekeeper(address notAdmin) public {
    vm.assume(notAdmin != owner);
    vm.startPrank(notAdmin);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(notAdmin), " is missing role ", vm.toString(adminRole)
        )
      )
    );
    EthenaMintingContract.grantRole(gatekeeperRole, bob);

    assertFalse(EthenaMintingContract.hasRole(gatekeeperRole, bob), "Bob should lack the gatekeeper role");

    vm.stopPrank();
  }

  function test_base_transferAdmin() public {
    vm.prank(owner);
    EthenaMintingContract.transferAdmin(newOwner);
    assertTrue(EthenaMintingContract.hasRole(adminRole, owner));
    assertFalse(EthenaMintingContract.hasRole(adminRole, newOwner));

    vm.prank(newOwner);
    EthenaMintingContract.acceptAdmin();
    assertFalse(EthenaMintingContract.hasRole(adminRole, owner));
    assertTrue(EthenaMintingContract.hasRole(adminRole, newOwner));
  }

  function test_transferAdmin_notAdmin() public {
    vm.startPrank(randomer);
    vm.expectRevert();
    EthenaMintingContract.transferAdmin(randomer);
  }

  function test_grantRole_AdminRoleExternally() public {
    vm.startPrank(randomer);
    vm.expectRevert(
      "AccessControl: account 0xc91041eae7bf78e1040f4abd7b29908651f45546 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    EthenaMintingContract.grantRole(adminRole, randomer);
    vm.stopPrank();
  }

  function test_revokeRole_notAdmin() public {
    vm.startPrank(randomer);
    vm.expectRevert(
      "AccessControl: account 0xc91041eae7bf78e1040f4abd7b29908651f45546 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    EthenaMintingContract.revokeRole(adminRole, owner);
  }

  function test_revokeRole_AdminRole() public {
    vm.startPrank(owner);
    vm.expectRevert();
    EthenaMintingContract.revokeRole(adminRole, owner);
  }

  function test_renounceRole_notAdmin() public {
    vm.startPrank(randomer);
    vm.expectRevert(InvalidAdminChange);
    EthenaMintingContract.renounceRole(adminRole, owner);
  }

  function test_renounceRole_AdminRole() public {
    vm.prank(owner);
    vm.expectRevert(InvalidAdminChange);
    EthenaMintingContract.renounceRole(adminRole, owner);
  }

  function test_revoke_AdminRole() public {
    vm.prank(owner);
    vm.expectRevert(InvalidAdminChange);
    EthenaMintingContract.revokeRole(adminRole, owner);
  }

  function test_grantRole_nonAdminRole() public {
    vm.prank(owner);
    EthenaMintingContract.grantRole(minterRole, randomer);
    assertTrue(EthenaMintingContract.hasRole(minterRole, randomer));
  }

  function test_revokeRole_nonAdminRole() public {
    vm.startPrank(owner);
    EthenaMintingContract.grantRole(minterRole, randomer);
    EthenaMintingContract.revokeRole(minterRole, randomer);
    vm.stopPrank();
    assertFalse(EthenaMintingContract.hasRole(minterRole, randomer));
  }

  function test_renounceRole_nonAdminRole() public {
    vm.prank(owner);
    EthenaMintingContract.grantRole(minterRole, randomer);
    vm.prank(randomer);
    EthenaMintingContract.renounceRole(minterRole, randomer);
    assertFalse(EthenaMintingContract.hasRole(minterRole, randomer));
  }

  function testCanRepeatedlyTransferAdmin() public {
    vm.startPrank(owner);
    EthenaMintingContract.transferAdmin(newOwner);
    EthenaMintingContract.transferAdmin(randomer);
    vm.stopPrank();
  }

  function test_renounceRole_forDifferentAccount() public {
    vm.prank(randomer);
    vm.expectRevert("AccessControl: can only renounce roles for self");
    EthenaMintingContract.renounceRole(minterRole, owner);
  }

  function testCancelTransferAdmin() public {
    vm.startPrank(owner);
    EthenaMintingContract.transferAdmin(newOwner);
    EthenaMintingContract.transferAdmin(address(0));
    vm.stopPrank();
    assertTrue(EthenaMintingContract.hasRole(adminRole, owner));
    assertFalse(EthenaMintingContract.hasRole(adminRole, address(0)));
    assertFalse(EthenaMintingContract.hasRole(adminRole, newOwner));
  }

  function test_admin_cannot_transfer_self() public {
    vm.startPrank(owner);
    vm.expectRevert(InvalidAdminChange);
    EthenaMintingContract.transferAdmin(owner);
    vm.stopPrank();
    assertTrue(EthenaMintingContract.hasRole(adminRole, owner));
  }

  function testAdminCanCancelTransfer() public {
    vm.startPrank(owner);
    EthenaMintingContract.transferAdmin(newOwner);
    EthenaMintingContract.transferAdmin(address(0));
    vm.stopPrank();

    vm.prank(newOwner);
    vm.expectRevert(ISingleAdminAccessControl.NotPendingAdmin.selector);
    EthenaMintingContract.acceptAdmin();

    assertTrue(EthenaMintingContract.hasRole(adminRole, owner));
    assertFalse(EthenaMintingContract.hasRole(adminRole, address(0)));
    assertFalse(EthenaMintingContract.hasRole(adminRole, newOwner));
  }

  function testOwnershipCannotBeRenounced() public {
    vm.startPrank(owner);
    vm.expectRevert(ISingleAdminAccessControl.InvalidAdminChange.selector);
    EthenaMintingContract.renounceRole(adminRole, owner);

    vm.expectRevert(ISingleAdminAccessControl.InvalidAdminChange.selector);
    EthenaMintingContract.revokeRole(adminRole, owner);
    vm.stopPrank();
    assertEq(EthenaMintingContract.owner(), owner);
    assertTrue(EthenaMintingContract.hasRole(adminRole, owner));
  }

  function testOwnershipTransferRequiresTwoSteps() public {
    vm.prank(owner);
    EthenaMintingContract.transferAdmin(newOwner);
    assertEq(EthenaMintingContract.owner(), owner);
    assertTrue(EthenaMintingContract.hasRole(adminRole, owner));
    assertNotEq(EthenaMintingContract.owner(), newOwner);
    assertFalse(EthenaMintingContract.hasRole(adminRole, newOwner));
  }

  function testCanTransferOwnership() public {
    vm.prank(owner);
    EthenaMintingContract.transferAdmin(newOwner);
    vm.prank(newOwner);
    EthenaMintingContract.acceptAdmin();
    assertTrue(EthenaMintingContract.hasRole(adminRole, newOwner));
    assertFalse(EthenaMintingContract.hasRole(adminRole, owner));
  }

  function testNewOwnerCanPerformOwnerActions() public {
    vm.prank(owner);
    EthenaMintingContract.transferAdmin(newOwner);
    vm.startPrank(newOwner);
    EthenaMintingContract.acceptAdmin();
    EthenaMintingContract.grantRole(gatekeeperRole, bob);
    vm.stopPrank();
    assertTrue(EthenaMintingContract.hasRole(adminRole, newOwner));
    assertTrue(EthenaMintingContract.hasRole(gatekeeperRole, bob));
  }

  function testOldOwnerCantPerformOwnerActions() public {
    vm.prank(owner);
    EthenaMintingContract.transferAdmin(newOwner);
    vm.prank(newOwner);
    EthenaMintingContract.acceptAdmin();
    assertTrue(EthenaMintingContract.hasRole(adminRole, newOwner));
    assertFalse(EthenaMintingContract.hasRole(adminRole, owner));
    vm.prank(owner);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    EthenaMintingContract.grantRole(gatekeeperRole, bob);
    assertFalse(EthenaMintingContract.hasRole(gatekeeperRole, bob));
  }

  function testOldOwnerCantTransferOwnership() public {
    vm.prank(owner);
    EthenaMintingContract.transferAdmin(newOwner);
    vm.prank(newOwner);
    EthenaMintingContract.acceptAdmin();
    assertTrue(EthenaMintingContract.hasRole(adminRole, newOwner));
    assertFalse(EthenaMintingContract.hasRole(adminRole, owner));
    vm.prank(owner);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    EthenaMintingContract.transferAdmin(bob);
    assertFalse(EthenaMintingContract.hasRole(adminRole, bob));
  }

  function testNonAdminCanRenounceRoles() public {
    vm.prank(owner);
    EthenaMintingContract.grantRole(gatekeeperRole, bob);
    assertTrue(EthenaMintingContract.hasRole(gatekeeperRole, bob));

    vm.prank(bob);
    EthenaMintingContract.renounceRole(gatekeeperRole, bob);
    assertFalse(EthenaMintingContract.hasRole(gatekeeperRole, bob));
  }

  function testCorrectInitConfig() public {
    EthenaMinting ethenaMinting2 = new EthenaMinting(
      IUSDe(address(usdeToken)),
      assets,
      custodians,
      randomer,
      _maxMintPerBlock,
      _maxRedeemPerBlock
    );
    assertFalse(ethenaMinting2.hasRole(adminRole, owner));
    assertNotEq(ethenaMinting2.owner(), owner);
    assertTrue(ethenaMinting2.hasRole(adminRole, randomer));
    assertEq(ethenaMinting2.owner(), randomer);
  }
}

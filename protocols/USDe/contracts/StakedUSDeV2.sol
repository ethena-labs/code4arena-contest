// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "./StakedUSDe.sol";
import "./interfaces/IStakedUSDeCooldown.sol";
import "./USDeSilo.sol";

/**
 * @title StakedUSDeV2
 * @notice The StakedUSDeV2 contract allows users to stake USDe tokens and earn a portion of protocol LST and perpetual yield that is allocated
 * to stakers by the Ethena DAO governance voted yield distribution algorithm.  The algorithm seeks to balance the stability of the protocol by funding
 * the protocol's insurance fund, DAO activities, and rewarding stakers with a portion of the protocol's yield.
 * @dev If cooldown duration is set to zero, the StakedUSDeV2 behavior changes to follow ERC4626 standard and disables cooldownShares and cooldownAssets methods. If cooldown duration is greater than zero, the ERC4626 withdrawal and redeem functions are disabled, breaking the ERC4626 standard, and enabling the cooldownShares and the cooldownAssets functions.
 */
contract StakedUSDeV2 is IStakedUSDeCooldown, StakedUSDe {
  using SafeERC20 for IERC20;

  mapping(address => UserCooldown) public cooldowns;

  USDeSilo public silo;

  uint24 public MAX_COOLDOWN_DURATION = 90 days;

  uint24 public cooldownDuration;

  /// @notice ensure cooldownDuration is zero
  modifier ensureCooldownOff() {
    if (cooldownDuration != 0) revert OperationNotAllowed();
    _;
  }

  /// @notice ensure cooldownDuration is gt 0
  modifier ensureCooldownOn() {
    if (cooldownDuration == 0) revert OperationNotAllowed();
    _;
  }

  /// @notice Constructor for StakedUSDeV2 contract.
  /// @param _asset The address of the USDe token.
  /// @param initialRewarder The address of the initial rewarder.
  /// @param owner The address of the admin role.
  constructor(IERC20 _asset, address initialRewarder, address owner) StakedUSDe(_asset, initialRewarder, owner) {
    silo = new USDeSilo(address(this), address(_asset));
    cooldownDuration = MAX_COOLDOWN_DURATION;
  }

  /* ------------- EXTERNAL ------------- */

  /**
   * @dev See {IERC4626-withdraw}.
   */
  function withdraw(uint256 assets, address receiver, address owner)
    public
    virtual
    override
    ensureCooldownOff
    returns (uint256)
  {
    return super.withdraw(assets, receiver, owner);
  }

  /**
   * @dev See {IERC4626-redeem}.
   */
  function redeem(uint256 shares, address receiver, address owner)
    public
    virtual
    override
    ensureCooldownOff
    returns (uint256)
  {
    return super.redeem(shares, receiver, owner);
  }

  /// @notice Claim the staking amount after the cooldown has finished. The address can only retire the full amount of assets.
  /// @dev unstake can be called after cooldown have been set to 0, to let accounts to be able to claim remaining assets locked at Silo
  /// @param receiver Address to send the assets by the staker
  function unstake(address receiver) external {
    UserCooldown storage userCooldown = cooldowns[msg.sender];
    uint256 assets = userCooldown.underlyingAmount;

    if (block.timestamp >= userCooldown.cooldownEnd) {
      userCooldown.cooldownEnd = 0;
      userCooldown.underlyingAmount = 0;

      silo.withdraw(receiver, assets);
    } else {
      revert InvalidCooldown();
    }
  }

  /// @notice redeem assets and starts a cooldown to claim the converted underlying asset
  /// @param assets assets to redeem
  /// @param owner address to redeem and start cooldown, owner must allowed caller to perform this action
  function cooldownAssets(uint256 assets, address owner) external ensureCooldownOn returns (uint256) {
    if (assets > maxWithdraw(owner)) revert ExcessiveWithdrawAmount();

    uint256 shares = previewWithdraw(assets);

    cooldowns[owner].cooldownEnd = uint104(block.timestamp) + cooldownDuration;
    cooldowns[owner].underlyingAmount += assets;

    _withdraw(_msgSender(), address(silo), owner, assets, shares);

    return shares;
  }

  /// @notice redeem shares into assets and starts a cooldown to claim the converted underlying asset
  /// @param shares shares to redeem
  /// @param owner address to redeem and start cooldown, owner must allowed caller to perform this action
  function cooldownShares(uint256 shares, address owner) external ensureCooldownOn returns (uint256) {
    if (shares > maxRedeem(owner)) revert ExcessiveRedeemAmount();

    uint256 assets = previewRedeem(shares);

    cooldowns[owner].cooldownEnd = uint104(block.timestamp) + cooldownDuration;
    cooldowns[owner].underlyingAmount += assets;

    _withdraw(_msgSender(), address(silo), owner, assets, shares);

    return assets;
  }

  /// @notice Set cooldown duration. If cooldown duration is set to zero, the StakedUSDeV2 behavior changes to follow ERC4626 standard and disables cooldownShares and cooldownAssets methods. If cooldown duration is greater than zero, the ERC4626 withdrawal and redeem functions are disabled, breaking the ERC4626 standard, and enabling the cooldownShares and the cooldownAssets functions.
  /// @param duration Duration of the cooldown
  function setCooldownDuration(uint24 duration) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (duration > MAX_COOLDOWN_DURATION) {
      revert InvalidCooldown();
    }

    uint24 previousDuration = cooldownDuration;
    cooldownDuration = duration;
    emit CooldownDurationUpdated(previousDuration, cooldownDuration);
  }
}

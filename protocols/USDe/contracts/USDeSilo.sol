// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../contracts/interfaces/IUSDeSiloDefinitions.sol";

/**
 * @title USDeSilo
 * @notice The Silo allows to store USDe during the stake cooldown process.
 */
contract USDeSilo is IUSDeSiloDefinitions {
  using SafeERC20 for IERC20;

  address immutable STAKING_VAULT;
  IERC20 immutable USDE;

  constructor(address stakingVault, address usde) {
    STAKING_VAULT = stakingVault;
    USDE = IERC20(usde);
  }

  modifier onlyStakingVault() {
    if (msg.sender != STAKING_VAULT) revert OnlyStakingVault();
    _;
  }

  function withdraw(address to, uint256 amount) external onlyStakingVault {
    USDE.transfer(to, amount);
  }
}

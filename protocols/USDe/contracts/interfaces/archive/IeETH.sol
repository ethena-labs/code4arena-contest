// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IeETH is IERC20, IERC20Metadata {
  function mint(address _to, uint256 _amount) external;

  function burn(address _from, uint256 _amount) external;

  function burnFrom(address account, uint256 amount) external;
}

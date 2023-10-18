// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/**
 * @dev Interface of the ERC20 standard events only.
 */
interface IERC20Events {
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

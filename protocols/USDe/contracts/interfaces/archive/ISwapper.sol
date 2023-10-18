// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

interface ISwapper {
  function swap(address _tokenIn, address _tokenOut, uint256 _amountIn, address _to)
    external
    returns (uint256 amountOut);

  function swapExactTokensForETH(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address payable to,
    uint256 deadline
  ) external payable returns (uint256[] memory amounts);

  function swapTokenForETH(
    uint256 amountIn,
    uint256 amountOutMin,
    address _tokenIn,
    address payable to,
    uint256 deadline
  ) external payable returns (uint256 amount);

  function estimateSwap(address _tokenIn, address _tokenOut, uint256 _amountIn)
    external
    view
    returns (uint256 amountOut);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILendingMarket {
  function getUserCount(address _token) external view returns (uint256);

  function getUserAt(address _token, uint256 _index) external view returns (address user);

  /// @notice A struct to preview a user's collateral position
  struct PositionView {
    address owner;
    address token;
    uint256 amount;
    uint256 amountUSD;
    uint256 creditLimitUSD;
    uint256 debtPrincipal;
    uint256 debtInterest;
    bool liquidatable;
  }

  function positionView(address _user, address _token) external view returns (PositionView memory);

  function liquidatable(address _user, address _token) external view returns (bool);

  function liquidate(address _user, address _token) external;
}

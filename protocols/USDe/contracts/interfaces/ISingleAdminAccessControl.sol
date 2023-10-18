// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ISingleAdminAccessControl {
  error InvalidAdminChange();
  error NotPendingAdmin();

  event AdminTransferred(address indexed oldAdmin, address indexed newAdmin);
  event AdminTransferRequested(address indexed oldAdmin, address indexed newAdmin);
}

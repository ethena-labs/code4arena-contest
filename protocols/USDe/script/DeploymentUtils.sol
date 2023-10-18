// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

/**
 * solhint-disable private-vars-leading-underscore
 */

import "forge-std/Vm.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DeploymentUtils is StdUtils {
  error USER_NOT_OWNER();
  error USER_LACKS_ROLE();
  error ADDRESS_DERIVATION_ERROR();

  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
  address private constant CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

  function _deployFromArtifacts(string memory contractPath) internal returns (address deployment) {
    bytes memory bytecode = abi.encodePacked(vm.getCode(contractPath));
    assembly {
      deployment := create(0, add(bytecode, 0x20), mload(bytecode))
    }

    return deployment;
  }

  function _deployFromArtifactsWithBroadcast(string memory contractPath) internal returns (address deployment) {
    bytes memory bytecode = abi.encodePacked(vm.getCode(contractPath));
    vm.broadcast();
    assembly {
      deployment := create(0, add(bytecode, 0x20), mload(bytecode))
    }

    return deployment;
  }

  function _deployFromArtifactsWithBroadcast(string memory contractPath, bytes memory args)
    internal
    returns (address deployment)
  {
    bytes memory bytecode = abi.encodePacked(vm.getCode(contractPath), args);

    vm.broadcast();
    assembly {
      deployment := create(0, add(bytecode, 0x20), mload(bytecode))
    }

    return deployment;
  }

  function _deployCreate2FromArtifactsWithBroadcast(string memory contractPath, bytes memory args, uint256 salt)
    internal
    returns (address deployment)
  {
    bytes memory bytecode = abi.encodePacked(vm.getCode(contractPath), args);

    vm.broadcast();
    assembly {
      deployment := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
    }

    return deployment;
  }

  function _deployFromArtifacts(string memory contractPath, bytes memory args) internal returns (address deployment) {
    bytes memory bytecode = abi.encodePacked(vm.getCode(contractPath), args);
    assembly {
      deployment := create(0, add(bytecode, 0x20), mload(bytecode))
    }

    return deployment;
  }

  function _create2Deploy(bytes32 salt, bytes memory bytecode, bytes memory constructorParams)
    internal
    returns (address)
  {
    if (_isContractDeployed(CREATE2_FACTORY) == false) {
      revert("MISSING CREATE2_FACTORY");
    }
    address computed = computeCreate2Address(salt, hashInitCode(bytecode, constructorParams));

    if (_isContractDeployed(computed)) {
      return computed;
    } else {
      bytes memory creationBytecode = abi.encodePacked(salt, abi.encodePacked(bytecode, constructorParams));
      bytes memory returnData;
      (, returnData) = CREATE2_FACTORY.call(creationBytecode);
      address deployedAt = address(uint160(bytes20(returnData)));
      if (deployedAt != computed) revert ADDRESS_DERIVATION_ERROR();
      return deployedAt;
    }
  }

  function _isContractDeployed(address _addr) internal view returns (bool isContract) {
    return (_addr.code.length > 0);
  }

  function deploy2(bytes memory bytecode, uint256 _salt) public {
    address addr;
    assembly {
      addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)

      if iszero(extcodesize(addr)) { revert(0, 0) }
    }
  }

  // Deployment checks //

  // Ensures that the given user is the owner of the specified contract
  function _utilsIsOwner(address user, address contractAddr) internal view {
    address owner = Ownable(contractAddr).owner();

    if (owner != user) revert USER_NOT_OWNER();
  }

  // Ensures that given user has a certain role
  function _utilsHasRole(bytes32 role, address user, address contractAddr) internal view {
    bool userHasRole = IAccessControl(contractAddr).hasRole(role, user);

    if (!userHasRole) revert USER_LACKS_ROLE();
  }
}

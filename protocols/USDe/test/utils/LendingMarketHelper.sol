// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import {stdStorage, StdStorage, Test, stdError} from 'forge-std/Test.sol';
import {Utils} from './Utils.sol';
import {USDeListingHelper} from '../../contracts/lending/helpers/USDeListingHelper.sol';
import {IUSDe} from '../../contracts/interfaces/IUSDe.sol';
import {IAStETH} from '../../contracts/lending/tokens/interfaces/IAStETH.sol';
import {ACLManager} from '@aave/core-v3/contracts/protocol/configuration/ACLManager.sol';
import {IPoolConfigurator} from '@aave/core-v3/contracts/interfaces/IPoolConfigurator.sol';
import {USDePayload} from '../../contracts/lending/USDePayload/USDePayload.sol';
import {TestnetERC20} from '../../contracts/TestnetERC20.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {MockAggregator} from '@aave/core-v3/contracts/mocks/oracle/CLAggregators/MockAggregator.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';
import {IAStEthEvents} from '../../contracts/lending/tokens/interfaces/IAStEthEvents.sol';
import {USDeAToken} from '../../contracts/lending/tokens/USDe/USDeAToken.sol';
import {USDeVariableDebtToken} from '../../contracts/lending/tokens/USDe/USDeVariableDebtToken.sol';
import {USDeStableDebtToken} from '../../contracts/lending/tokens/USDe/USDeStableDebtToken.sol';
import {AstEth} from '../../contracts/lending/tokens/stEth/AstEth.sol';
import {StEthStableDebtToken} from '../../contracts/lending/tokens/stEth/StEthStableDebtToken.sol';
import {StEthVariableDebtToken} from '../../contracts/lending/tokens/stEth/StEthVariableDebtToken.sol';
import {IAaveIncentivesController} from '@aave/core-v3/contracts/interfaces/IAaveIncentivesController.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {IPoolAddressesProvider} from '@bgd-helpers/v3-config-engine/V3RateStrategyFactory.sol';

// These tests can only be performed against Sepolia forks,
// right now we don't have access to the core aave deployment scripts
contract LendingMarketHelper is Test, USDeListingHelper, IAStEthEvents, Utils {
  address constant POOL_PROXY = 0xB2DE1540FC5b6B9f297cac16a9Ee8b13Df14919F;
  address constant POOL_CONFIGURATOR_PROXY = 0xBbc901D87B5DE66E5B417aB60ab38301ade664dE;
  address constant ORACLE = 0xAe14768b00F387FBDBDD75Ce0a82A2Dc8aECd11e;
  address constant REWARDS_CONTROLLER = 0x0bc3e690baf756d736044A637f145C00b3229AD0;
  address constant COLLECTOR = 0x0a121A336D251FF97eCb14F34de861F5eE037836; // treasury
  address constant POOL_ADDRESSES_PROVIDER = 0x9D25db7AF906587DDB7b967dE77E10d3254e4aA7;
  address constant USDE_ADDRESS = 0xa3D012f6437DB89AE02a8d60536cA8b649F577Ae;
  address constant USDE_OWNER = 0x46a1ea206Ef8EC604155abA33AD3a1E3054E132F;
  address constant ACL_MANAGER = 0x0F8f675811712BB5684241972C09BF4b3cF1e3cf;
  address constant DEPLOYER = 0x3fB65F19D735EDB9D7C2D61B9D470b376dd0f47E;
  address constant PROTOCOL_DATA_PROVIDER = 0xf385aD3B35BE014e76b9e0Ffd88CE9405E00eb4d;
  uint256 constant STRATEGY_VARIABLE_BORROW_RATE = 4e27;
  address bob;
  address alice;

  function lendingMarketDeployAndSetup()
    public
    returns (
      IUSDe usde,
      IPool pool,
      ACLManager aclManager,
      Contracts memory contracts,
      TestnetERC20 stETH,
      StEthTokenImplementations memory stEthProxies,
      USDeTokenImplementations memory usdeProxies
    )
  {
    bob = vm.addr(0x1DE);
    alice = vm.addr(0xB44DE);

    // labels
    vm.label(bob, 'bob');
    vm.label(alice, 'alice');
    vm.label(DEPLOYER, 'deployer');
    vm.label(USDE_OWNER, 'usde owner');
    vm.label(POOL_PROXY, 'lending pool');

    vm.startPrank(DEPLOYER);
    usde = IUSDe(USDE_ADDRESS);
    pool = IPool(POOL_PROXY);
    aclManager = ACLManager(ACL_MANAGER);

    // Mock stEth
    stETH = new TestnetERC20('STETH', 'STETH', DEPLOYER);
    // Mock cbEth used in testing
    TestnetERC20 cbETH = new TestnetERC20('CBETH', 'CBETH', DEPLOYER);

    contracts = deployUSDeSetup(
      IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER),
      STRATEGY_VARIABLE_BORROW_RATE,
      IPoolConfigurator(POOL_CONFIGURATOR_PROXY),
      usde,
      address(stETH),
      pool,
      aclManager,
      DEPLOYER,
      REWARDS_CONTROLLER,
      COLLECTOR,
      ORACLE,
      address(cbETH)
    );

    listUSDe(contracts, USDE_ADDRESS, aclManager);

    DataTypes.ReserveData memory stEthReserveData = pool.getReserveData(address(stETH));

    DataTypes.ReserveData memory usdeReserveData = pool.getReserveData(USDE_ADDRESS);

    usdeProxies = USDeTokenImplementations(
      USDeAToken(usdeReserveData.aTokenAddress),
      USDeStableDebtToken(usdeReserveData.stableDebtTokenAddress),
      USDeVariableDebtToken(usdeReserveData.variableDebtTokenAddress)
    );

    stEthProxies = StEthTokenImplementations(
      AstEth(stEthReserveData.aTokenAddress),
      StEthStableDebtToken(stEthReserveData.stableDebtTokenAddress),
      StEthVariableDebtToken(stEthReserveData.variableDebtTokenAddress)
    );

    // Set the relation between the aUSDe and the USDe variable debt token
    usdeProxies.USDeAToken.setVariableDebtToken(usdeReserveData.variableDebtTokenAddress);
    usdeProxies.USDeVariableDebtToken.setAToken(usdeReserveData.aTokenAddress);

    vm.startPrank(USDE_OWNER);
    grantUSDeMinterRole(usde, PROTOCOL_DATA_PROVIDER);

    return (usde, pool, aclManager, contracts, stETH, stEthProxies, usdeProxies);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./DeploymentUtils.sol";
import "forge-std/Script.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import "../contracts/StakedUSDe.sol";
import "../contracts/interfaces/IUSDe.sol";
import "../contracts/mock/MockToken.sol";
import "../contracts/USDe.sol";
import "../contracts/StakedUSDe.sol";
import "../contracts/interfaces/IEthenaMinting.sol";
import "../contracts/EthenaMinting.sol";
import "../contracts/WETH9.sol";

// This deployment uses CREATE2 to ensure that only the modified contracts are deployed
contract FullDeployment is Script, DeploymentUtils {
  struct Contracts {
    // Mock tokens
    MockToken stEth;
    // MockToken rETH;
    // MockToken cbETH;
    // MockToken usdc;
    // MockToken usdt;
    // MockToken wbETH;
    address weth9;
    // E-tokens
    USDe USDeToken;
    StakedUSDe stakedUSDe;
    // E-contracts
    EthenaMinting ethenaMintingContract;
  }

  struct Configuration {
    // Roles
    bytes32 usdeMinterRole;
  }
  // bytes32 stakedUSDeTokenMinterRole;
  // bytes32 stakingRewarderRole;

  address public constant ZERO_ADDRESS = address(0);
  // versioning to enable forced redeploys
  bytes32 public constant SALT = bytes32("Ethena0.0.15");
  uint256 public constant MAX_USDE_MINT_PER_BLOCK = 100_000e18;
  uint256 public constant MAX_USDE_REDEEM_PER_BLOCK = 100_000e18;

  function run() public virtual {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    deployment(deployerPrivateKey);
  }

  function deployment(uint256 deployerPrivateKey) public returns (Contracts memory) {
    address deployerAddress = vm.addr(deployerPrivateKey);
    Contracts memory contracts;

    contracts.weth9 = _create2Deploy(SALT, type(WETH9).creationCode, bytes(""));

    vm.startBroadcast(deployerPrivateKey);

    contracts.USDeToken = USDe(_create2Deploy(SALT, type(USDe).creationCode, abi.encode(deployerAddress)));

    // Checks the USDe owner
    _utilsIsOwner(deployerAddress, address(contracts.USDeToken));

    contracts.stakedUSDe = StakedUSDe(
      _create2Deploy(
        SALT, type(StakedUSDe).creationCode, abi.encode(address(contracts.USDeToken), deployerAddress, deployerAddress)
      )
    );

    // Checks the staking owner and admin
    _utilsIsOwner(deployerAddress, address(contracts.stakedUSDe));
    _utilsHasRole(contracts.stakedUSDe.DEFAULT_ADMIN_ROLE(), deployerAddress, address(contracts.stakedUSDe));

    IUSDe iUSDe = IUSDe(address(contracts.USDeToken));

    // stEth //
    contracts.stEth = MockToken(
      _create2Deploy(
        SALT, type(MockToken).creationCode, abi.encode("Mocked stETH", "stETH", uint256(18), deployerAddress)
      )
    );
    // rETH //
    // contracts.rETH = MockToken(
    //   _create2Deploy(
    //     SALT,
    //     type(MockToken).creationCode,
    //     abi.encode('Mocked rETH', 'rETH', uint256(18), deployerAddress)
    //   )
    // );
    // // cbETH //
    // contracts.cbETH = MockToken(
    //   _create2Deploy(
    //     SALT,
    //     type(MockToken).creationCode,
    //     abi.encode('Mocked cbETH', 'cbETH', uint256(18), deployerAddress)
    //   )
    // );
    // // USDC //
    // contracts.usdc = MockToken(
    //   _create2Deploy(SALT, type(MockToken).creationCode, abi.encode('Mocked USDC', 'USDC', uint256(6), deployerAddress))
    // );
    // // USDT //
    // contracts.usdt = MockToken(
    //   _create2Deploy(SALT, type(MockToken).creationCode, abi.encode('Mocked USDT', 'USDT', uint256(6), deployerAddress))
    // );
    // // WBETH //
    // contracts.wbETH = MockToken(
    //   _create2Deploy(
    //     SALT,
    //     type(MockToken).creationCode,
    //     abi.encode('Mocked WBETH', 'WBETH', uint256(6), deployerAddress)
    //   )
    // );

    // Ethena Minting
    address[] memory assets = new address[](2);
    assets[0] = address(contracts.stEth);

    // assets[1] = address(contracts.cbETH);
    // assets[2] = address(contracts.rETH);
    // assets[3] = address(contracts.usdc);
    // assets[4] = address(contracts.usdt);
    // assets[5] = address(contracts.wbETH);
    // ETH
    assets[1] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address[] memory custodians = new address[](1);
    // copper address
    custodians[0] = address(0x6b95F243959329bb88F5D3Df9A7127Efba703fDA);

    contracts.ethenaMintingContract = EthenaMinting(
      payable(
        _create2Deploy(
          SALT,
          type(EthenaMinting).creationCode,
          abi.encode(iUSDe, assets, custodians, deployerAddress, MAX_USDE_MINT_PER_BLOCK, MAX_USDE_REDEEM_PER_BLOCK)
        )
      )
    );

    // give minting contract USDe minter role
    contracts.USDeToken.setMinter(address(contracts.ethenaMintingContract));

    // Checks the minting owner and admin
    _utilsIsOwner(deployerAddress, address(contracts.ethenaMintingContract));

    _utilsHasRole(
      contracts.ethenaMintingContract.DEFAULT_ADMIN_ROLE(), deployerAddress, address(contracts.ethenaMintingContract)
    );

    vm.stopBroadcast();

    string memory blockExplorerUrl = "https://sepolia.etherscan.io";

    uint256 chainId;
    assembly {
      chainId := chainid()
    }

    if (chainId == 1) {
      blockExplorerUrl = "https://etherscan.io";
    } else if (chainId == 5) {
      blockExplorerUrl = "https://goerli.etherscan.io";
    } else if (chainId == 137) {
      blockExplorerUrl = "https://polygonscan.com";
    }

    // Logs
    console.log("=====> All Ethena contracts deployed ....");
    console.log("USDe                          : %s/address/%s", blockExplorerUrl, address(contracts.USDeToken));
    console.log("StakedUSDe                     : %s/address/%s", blockExplorerUrl, address(contracts.stakedUSDe));
    console.log("stETH                         : %s/address/%s", blockExplorerUrl, address(contracts.stEth));
    // console.log('rETH                          : %s/address/%s', blockExplorerUrl, address(contracts.rETH));
    // console.log('cbETH                         : %s/address/%s', blockExplorerUrl, address(contracts.cbETH));
    console.log("WETH9                         : %s/address/%s", blockExplorerUrl, address(contracts.weth9));
    // console.log('USDC                          : %s/address/%s', blockExplorerUrl, address(contracts.usdc));
    // console.log('USDT                          : %s/address/%s', blockExplorerUrl, address(contracts.usdt));
    // console.log('WBETH                         : %s/address/%s', blockExplorerUrl, address(contracts.wbETH));
    console.log(
      "Ethena Minting                  : %s/address/%s", blockExplorerUrl, address(contracts.ethenaMintingContract)
    );
    return contracts;
  }
}

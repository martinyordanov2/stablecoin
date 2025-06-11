// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Invariants is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine engine;
    HelperConfig helperConfig;
    DecentralizedStableCoin dsc;
    address public weth;
    address public wbtc;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, engine, helperConfig) = deployer.run();
        targetContract(address(engine));
        (,, weth, wbtc,) = helperConfig.activeNetworkConfig();
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        //get the value of all collateral in the protocol
        // compare it to all the debt (dsc)
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 btcValue = engine.getUsdValue(wbtc, totalBtcDeposited);

        console.log(wethValue);
        console.log(btcValue);
        console.log(totalSupply);

        assert(wethValue + btcValue >= totalSupply);
    }
}

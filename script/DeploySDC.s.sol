// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
// import { HelperConfig } from "./HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    address[] public tokenAdresses;
    address[] public priceFeedAdresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();

        tokenAdresses = [weth, wbtc];
        priceFeedAdresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine(tokenAdresses, priceFeedAdresses, address(dsc));

        dsc.transferOwnership(address(engine));
        vm.stopBroadcast();
        return(dsc, engine); 
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import { MockFailedTransferFrom } from "../mocks/MockFailedTransferFrom.sol";

contract DecentralizedStableCoinTest is Test {
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    DSCEngine engine;
    DecentralizedStableCoin dsc;
    MockV3Aggregator ethUsdPriceFeed;
    MockV3Aggregator btcUsdPriceFeed;
    ERC20Mock wBtcMock;
    ERC20Mock wEthMock;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    address public user = makeAddr("user");

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    address public dscAddress;

    function setUp() public {
        dsc = new DecentralizedStableCoin();
        dscAddress = address(dsc);

        ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        wEthMock = new ERC20Mock("WETH", "WETH", msg.sender, 0);
        wEthMock.mint(user, 1000e18);

        btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        wBtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 0);
        wBtcMock.mint(user, 1000e18);

        tokenAddresses.push(address(wEthMock));
        priceFeedAddresses.push(address(ethUsdPriceFeed));
        tokenAddresses.push(address(wBtcMock));
        priceFeedAddresses.push(address(btcUsdPriceFeed));

        engine = new DSCEngine(tokenAddresses, priceFeedAddresses, dscAddress);
    }

    //depositCollateral

    function testDepositCollateralSuccessfulDeposit() public {
        uint256 depositAmount = 80e18;
        uint256 allowance = 100e18;

        vm.prank(user);
        wEthMock.approve(address(engine), allowance);

        uint256 userInitialBalance = wEthMock.balanceOf(address(user));
        uint256 contractInitialBalance = wEthMock.balanceOf(address(engine));

        vm.prank(user);
        engine.depositCollateral(address(wEthMock), depositAmount);

        uint256 userFinalBalance = wEthMock.balanceOf(user);
        assertEq(userFinalBalance, userInitialBalance - depositAmount);

        uint256 contracBalanceAfterDeposit = wEthMock.balanceOf(address(engine));
        assertEq(contractInitialBalance + depositAmount, contracBalanceAfterDeposit);
    }

    function testDepositCollateralIfCollateralIsZero() public {
        uint256 allowance = 100e18;

        vm.prank(user);
        wEthMock.approve(address(engine), allowance);

        vm.prank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(address(wEthMock), 0);
    }

    function testDepositCollateralIfTokenNotAllowed() public {
        uint256 allowance = 100e18;
        uint256 depositAmount = 80e18;

        vm.prank(user);
        wEthMock.approve(address(engine), allowance);

        vm.prank(user);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        engine.depositCollateral(address(0), depositAmount);
    }

    //getUsdValue

    // function testGetUsdValue() public view{
    //     uint256 ethAmount = 10e18;
    //     uint256 expectedValue = 20000e18;
    //     uint256 actualValue = engine.getUsdValue(address(wEthMock), ethAmount);
    //     assertEq(expectedValue, actualValue);
    // }
}
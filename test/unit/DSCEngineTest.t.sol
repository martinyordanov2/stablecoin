// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockFailedMintDSC} from "../mocks/MockFailedMintDSC.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig helperConfig;
    address weth;
    address wbtc;
    address ethUsdPriceFeed;
    address[] tokenAddresses;
    address[] priceFeeds;
    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 100 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 100 ether;
    uint256 public constant AMOUNT_TO_MINT = 60 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, helperConfig) = deployer.run();
        (ethUsdPriceFeed,, weth, wbtc,) = helperConfig.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    //constructor tests
    function testRevertsIfAddressesAndPriceLenghtAreNotTheSame() public {
        tokenAddresses.push(weth);
        tokenAddresses.push(wbtc);
        priceFeeds.push(ethUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAdrAndPriceFeedAdrMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeeds, address(dsc));
    }

    //pricefeed tests

    function testgetTokenAmountFromUsd() public view {
        uint256 usdAmountInWei = 10 ether;
        // $2000 for 1 ETH so we devide 10/ 2000 = 0.005 ether
        uint256 expectedWeth = 0.005 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmountInWei);
        assertEq(expectedWeth, actualWeth);
    }

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    //depositCollateral Tests

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        vm.startPrank(USER);
        ERC20Mock ranToken = new ERC20Mock("ranToken", "ranToken", USER, AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInfo(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositedAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(expectedTotalDscMinted, totalDscMinted);
        assertEq(expectedDepositedAmount, AMOUNT_COLLATERAL);
    }

    //mintDsc

    function testRevertsIfAmounToMintIsZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.mintDsc(0);
        vm.stopPrank();
    }

    ///But the actual error being reverted is DSCEngine__BelowMinimumHealthFactor(0), which includes a parameter (uint256 healthFactor or similar).
    function testRevertsIfHealthFactorIsBrokenForMinting() public {
        vm.startPrank(USER);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BelowMinimumHealthFactor.selector, 0));
        engine.mintDsc(AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    function testRevertsIfMintFails() public {
        // Arrange - Setup
        MockFailedMintDSC mockDsc = new MockFailedMintDSC();
        tokenAddresses = [weth];
        priceFeeds = [ethUsdPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeeds, address(mockDsc));
        mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(mockDsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        mockDsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    //redeemCollateral

    function testRevertsIfCollateralIsZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsIfHealthFactorIsBrokenForRedeeming() public depositedCollateral {
        vm.startPrank(USER);
        engine.mintDsc(AMOUNT_TO_MINT);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BelowMinimumHealthFactor.selector, 0));
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }


    function testCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(USER);
        engine.mintDsc(1e18);
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL - 1 ether);
        uint256 userBalanceAfterRedeem = engine.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceAfterRedeem, 1 ether);
        vm.stopPrank();
    }
}

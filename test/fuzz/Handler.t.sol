// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;

    MockV3Aggregator ethUsdPriceFeed;
    uint256 public timesMintIsCalled;
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;
    address[] public usersWithCollateralDeposited;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        engine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(engine.getCollateralTokenPriceFeed(address(weth)));
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(engine), amountCollateral);

        engine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        //double push
        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = engine.getCollateralBalanceOfUser(address(collateral), msg.sender);

        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }

        engine.redeemCollateral(address(collateral), amountCollateral);
    }

    function mintDsc(uint256 amountDscToMint, uint256 addressSeed) public {
        //When using invariants we are going to use random addresses. We need to know which user's address has deposited collateral so ONLY he can be allowed to mint. Therefore we rule out the msg.sender.
        if(usersWithCollateralDeposited.length == 0){
            return;
        }
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];

        //We can mint only when the collateral > amount to be minted. In other words the healthfactor must not be broken. Next line gets the dsc minted and the collateral's value to prepare the values for the later check if healthfactor is not broken.
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInfo(sender);

        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);

        if (maxDscToMint < 0) {
            return;
        }
        amountDscToMint = bound(amountDscToMint, 0, uint256(maxDscToMint));
        
        if (amountDscToMint == 0) {
            //this
            return;
        }

        vm.startPrank(sender);
        engine.mintDsc(amountDscToMint);
        vm.stopPrank();
        timesMintIsCalled++;
    }

    // this breaks the invariant  
    // function updateCollateralPrice(uint96 newPrice) public{ //this test destroys the value of the collateral
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    // function depositCollateralAndMintDsc(uint256 collateralSeed, uint256 amountCollateral, uint256 amountDscToMint)
    //     public
    // {
    //     amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
    //     ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

    //     // Calculate safe DSC amount
    //     uint256 collateralValueInUsd = engine.getUsdValue(address(collateral), amountCollateral);
    //     uint256 maxDscToMint = collateralValueInUsd / 2; // 50% of collateral value
    //     amountDscToMint = bound(amountDscToMint, 1, maxDscToMint);

    //     vm.startPrank(msg.sender);
    //     collateral.mint(msg.sender, amountCollateral);
    //     collateral.approve(address(engine), amountCollateral);

    //     engine.depositCollateralAndMintDsc(address(collateral), amountCollateral, amountDscToMint);
    //     vm.stopPrank();

    //     timesMintIsCalled++; // Track the mint
    // }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}

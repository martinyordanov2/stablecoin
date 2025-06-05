// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";

contract DecentralizedStableCoinTest is Test {
    DecentralizedStableCoin dsc;

    function setUp() public {
        dsc = new DecentralizedStableCoin();
    }

    function testBurnAmountIsZero() public {
        vm.prank(dsc.owner());
        dsc.mint(address(this), 50);
        vm.expectRevert();
        dsc.burn(0);
    }

    function testBurnAmountIsGreater() public {
        vm.prank(dsc.owner());
        dsc.mint(address(this), 50);
        vm.expectRevert();
        dsc.burn(100);
    }

    function testBurnAmountIsAppropriate() public {
        vm.prank(dsc.owner());
        dsc.mint(address(this), 50);
        dsc.burn(20);
        assertEq(dsc.balanceOf(address(this)), 30);
    }

    function testMintToAddressZero() public {
        vm.prank(dsc.owner());
        vm.expectRevert();
        dsc.mint(address(0), 50);
    }

    function testMintZeroValue() public {
        vm.prank(dsc.owner());
        vm.expectRevert();
        dsc.mint(address(this), 0);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../src/testing/WETH.sol";
import "../src/custodial/MarketplaceCustodial.sol";

contract MarketPlace_custodial_order is Test {
    WETH private weth;
    MarketplaceCustodial private mkpc;

    address bob = vm.addr(1);
    address alice = vm.addr(2);
    address tom = vm.addr(3);

    function setup() public {
        weth = new WETH();
        vm.deal(bob, 10 ether);
        vm.deal(alice, 5 ether);
        vm.deal(tom, 1 ether);
        deal(address(weth), bob, 10 ether);
        deal(address(weth), alice, 5 ether);
        deal(address(weth), tom, 1 ether);
        mkpc = new MarketplaceCustodial(address(weth));
    }
}

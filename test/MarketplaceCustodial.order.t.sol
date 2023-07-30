// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/testing/WETH.sol";
import "../src/testing/NFT721.sol";
import "../src/testing/NFT1155.sol";
import "../src/custodial/MarketplaceCustodial.sol";

contract MarketPlaceCustodialOrder is Test {
    WETH private _weth;
    MarketplaceCustodial private _mkpc;
    NFT721 private _nft721;
    NFT1155 private _nft1155;

    address public owner = vm.addr(10);
    address public bob = vm.addr(1);
    address public alice = vm.addr(2);
    address public tom = vm.addr(3);

    function setUp() public {
        _weth = new WETH();
        vm.deal(owner, 1 ether);
        vm.deal(bob, 10 ether);
        vm.deal(alice, 5 ether);
        vm.deal(tom, 1 ether);
        deal(address(_weth), bob, 10 ether);
        deal(address(_weth), alice, 5 ether);
        deal(address(_weth), tom, 1 ether);

        vm.startPrank(owner);
        _mkpc = new MarketplaceCustodial(address(_weth));
        _nft721 = new NFT721();
        _nft1155 = new NFT1155(25);
        _nft721.transferFrom(owner, bob, 1);
        _nft721.transferFrom(owner, bob, 2);
        vm.stopPrank();
    }

    function test_CreateSale() public {
        vm.startPrank(bob);
        _nft721.setApprovalForAll(address(_mkpc), true);
        _mkpc.createSale(address(_nft721), 1, 2 ether);
        vm.stopPrank();
        address seller = _mkpc.getSaleOrder(1).seller;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;
/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

//TODO: write tests

import "./BaseSetUp.sol";

contract ModifyBid is BaseSetUp {
    function testRevert_ModifyBid_Not_Bid_Owner() public {
        vm.startPrank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);
        vm.stopPrank();
        vm.startPrank(bidder);
        //approve for  eth allowance
        _weth.approve(address(_mkpc), 2 ether);
        //Create a bid for 1.5 eth
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);
        vm.stopPrank();
        vm.startPrank(buyer);
        bytes4 selector = bytes4(keccak256("notOwner(string)"));
        vm.expectRevert(abi.encodeWithSelector(selector, "Bid"));
        _mkpc.modifyBid(1, 0, 1 ether);
        vm.stopPrank();
    }

    //TODO: make it work
    function test_Revert_ModifyBid_Index_Out_Of_Bounds() public {
        vm.startPrank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);
        vm.stopPrank();
        vm.startPrank(bidder);
        //approve for  WETH allowance
        _weth.approve(address(_mkpc), 5 ether);
        //Create a bid for 1.5 eth
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);

        //wrong index, should revert
        vm.expectRevert("index out of bounds");
        _mkpc.modifyBid(1, 2, 1 ether);

        //cancel bid 0
        _mkpc.cancelBid(1, 0);

        //no bids, should revert
        vm.expectRevert("no bids");
        _mkpc.modifyBid(1, 0, 1 ether);
        vm.stopPrank();
    }

    function testRevert_ModifyBid_Offer_Closed() public {
        vm.startPrank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);
    vm.stopPrank();
        vm.startPrank(bidder);
        //approve for  WETH allowance
        _weth.approve(address(_mkpc), 5 ether);
        //Create a bid for 1.5 eth
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);
        vm.stopPrank();
        vm.prank(seller);
        //cancel sale 1
        _mkpc.cancelSale(1);

        vm.startPrank(bidder);
        //offer is closed, should revert
        bytes4 selector = bytes4(keccak256("offerClosed()"));
        vm.expectRevert(selector);
        _mkpc.modifyBid(1, 0, 1 ether);
        vm.stopPrank();
        assertTrue(_mkpc.getSaleOrder(1).closed);
    }

    function test_ModifyBid() public {
        vm.startPrank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);
        vm.stopPrank();
        vm.startPrank(bidder);
        //approve for  WETH allowance
        _weth.approve(address(_mkpc), 5 ether);
        //Create a bid for 1.5 eth
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);
        uint256 newPrice = 1 ether;
        _mkpc.modifyBid(1, 0, newPrice);
        vm.stopPrank();
        MarketplaceCustodial.Bid memory bid = _mkpc.getSaleOrder(1).bids[0];
        assertEq(bid.bidder, bidder);
        assertEq(bid.bidPrice, newPrice);
    }

    function test_Emit_ModifyBid_BidModified() public {
        vm.startPrank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);
        vm.stopPrank();
        vm.startPrank(bidder);
        //approve for  WETH allowance
        _weth.approve(address(_mkpc), 5 ether);
        //Create a bid for 1.5 eth
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);
        uint256 newPrice = 1 ether;
        vm.expectEmit();
        emit BidModified(1, bidder, newPrice);
        _mkpc.modifyBid(1, 0, newPrice);
        vm.stopPrank();
    }
}

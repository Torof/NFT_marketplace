// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;
/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

import "./BaseSetUp.sol";

contract CreateBid is BaseSetUp {
    function test_Revert_CreateBid_If_Offer_Not_GT_0() public {
        vm.startPrank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(buyer);
        //Create a bid
        vm.expectRevert("amount can't be zero");
        _mkpc.createBid(1, 0, 1 weeks);

        //check bids list is empty
        uint256 length = _mkpc.getSaleOrder(1).bids.length;
        assertEq(length, 0);
    }

    function test_Revert_CreateBid_If_Allowance_Not_Enough() public {
        vm.startPrank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 4 ether);

        vm.startPrank(buyer);
        //Create a bid, should revert
        vm.expectRevert("not enough balance allowed");
        _mkpc.createBid(1, 3 ether, 1 weeks);

        //approve for 1 eth allowance
        _weth.approve(address(_mkpc), 1 ether);

        //should revert, bid higher than allowance
        vm.expectRevert("not enough balance allowed");
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);
        vm.stopPrank();

        //check bids list is empty
        uint256 length = _mkpc.getSaleOrder(1).bids.length;
        assertEq(length, 0);
    }

    function test_Revert_CreateBid_If_Balance_Not_Enough() public {
        vm.startPrank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(buyer);
        //Create a bid, should revert user doesn't have enough funds
        bytes4 selector = bytes4(keccak256("notEnoughBalance()"));
        vm.expectRevert(selector);
        //The ether modifier is for units, the price is actually in WETH
        _mkpc.createBid(1, 6 ether, 1 weeks);

        //check bids list is empty
        uint256 length = _mkpc.getSaleOrder(1).bids.length;
        assertEq(length, 0);
    }

    function test_Revert_CreateBid_If_OfferClosed() public {
        vm.startPrank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);
        _mkpc.cancelSale(1);
        vm.stopPrank();

        vm.startPrank(buyer);
        //Create a bid, should revert because sale is over
        bytes4 selector = bytes4(keccak256("offerClosed()"));
        vm.expectRevert(selector);
        _mkpc.createBid(1, 3 ether, 1 weeks);

        //check bids list is empty
        uint256 length = _mkpc.getSaleOrder(1).bids.length;
        assertEq(length, 0);
    }

    //Create bid and check if bid is added to bids list
    function test_CreateBid() public {
        vm.startPrank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(buyer);
        //approve for  eth allowance
        _weth.approve(address(_mkpc), 2 ether);
        //Create a bid for 1.5 eth
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);
        vm.stopPrank();

        //check bids list has one bid
        uint256 length = _mkpc.getSaleOrder(1).bids.length;
        assertEq(length, 1);
        //Check bid's information is correct
        MarketplaceCustodial.Bid memory firstBid = _mkpc.getSaleOrder(1).bids[0];
        assertEq(firstBid.bidder, buyer);
        assertEq(firstBid.bidPrice, 1 ether + (1 ether * 5 / 10));
        assertEq(firstBid.duration, 1 weeks);
    }

    function test_Emit_CreateBid_BidSubmitted() public {
        vm.startPrank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(buyer);
        //approve for  eth allowance
        _weth.approve(address(_mkpc), 2 ether);

        vm.expectEmit();
        // We emit the BidSubmitted event we expect to see.
        emit BidSubmitted(1, buyer, 1 ether + (1 ether * 5 / 10));
        //Create a bid for 1.5 eth
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);
        vm.stopPrank();
    }
}

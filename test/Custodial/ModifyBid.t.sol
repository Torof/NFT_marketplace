// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

//TODO: write tests

import "./SetUp.t.sol";

contract ModifyBid is SetUp {
    function testRevert_ModifyBid_Not_Bid_Owner() public {
        vm.prank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(buyer);
        //approve for  eth allowance
        _weth.approve(address(_mkpc), 2 ether);
        //Create a bid for 1.5 eth
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);
        vm.stopPrank();
        vm.prank(bidder);
        bytes4 selector = bytes4(keccak256("notOwner(string)"));
        vm.expectRevert(abi.encodeWithSelector(selector, "Bid"));
        _mkpc.modifyBid(1, 0, 1 ether);
    }

    //TODO: make it work
    function test_Revert_ModifyBid_Index_Out_Of_Bounds() public {
        vm.prank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(buyer);
        //approve for  WETH allowance
        _weth.approve(address(_mkpc), 5 ether);
        //Create a bid for 1.5 eth
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);

        //wrong index, should revert
        vm.expectRevert("Index out of bounds");
        _mkpc.modifyBid(1, 2, 1 ether);

        //cancel bid 0
        _mkpc.cancelBid(1, 0);

        //no bids, should revert
        vm.expectRevert("no bids");
        _mkpc.modifyBid(1, 0, 1 ether);
        vm.stopPrank();
    }

    function testRevert_ModifyBid_Offer_Closed() public {}
    function test_ModifyBid() public {}
    function test_Emit_ModifyBid_BidModified() public {}
}

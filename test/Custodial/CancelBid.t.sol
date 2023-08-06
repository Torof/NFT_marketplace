// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

import "./SetUp.t.sol";

contract CancelBid is SetUp {
    function test_Revert_CancelBid_If_caller_Is_Not_Bidder() public {
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
        _mkpc.cancelBid(1, 0);
    }

    function test_Revert_CancelBid_Index_Out_Of_Bounds() public {
        vm.prank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(buyer);
        //approve for  WETH allowance
        _weth.approve(address(_mkpc), 5 ether);
        //Create a bid for 1.5 eth
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);

        //wrong index, should revert
        vm.expectRevert("index out of bounds");
        _mkpc.cancelBid(1, 3);

        //cancel bid 0
        _mkpc.cancelBid(1, 0);

        //no bids, should revert
        vm.expectRevert("no bids");
        _mkpc.cancelBid(1, 0);
        vm.stopPrank();
    }

    function test_CancelBid() public {
        vm.prank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(buyer);
        //approve for  WETH allowance
        _weth.approve(address(_mkpc), 5 ether);
        //Create a bid for 1.5 WETH
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);

        //cancel bid 0
        _mkpc.cancelBid(1, 0);

        vm.stopPrank();
    }

    function test_Emit_CancelBid_BidCanceled() public {
        vm.prank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(buyer);
        //approve for  WETH allowance
        _weth.approve(address(_mkpc), 5 ether);
        //Create a bid for 1.5 WETH
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);

        vm.expectEmit();
        emit BidCanceled(1, buyer, 0);
        //cancel bid 0
        _mkpc.cancelBid(1, 0);

        vm.stopPrank();
    }
}

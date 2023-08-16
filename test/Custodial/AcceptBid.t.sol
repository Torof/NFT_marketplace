// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

import "./BaseSetUp.t.sol";

contract AcceptBid is BaseSetUp {
    function test_Revert_AcceptBid_If_SaleClosed() public {
        address ownerOf = _nft721.ownerOf(1);
        assertEq(seller, ownerOf);
        vm.prank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(bidder);
        _weth.approve(address(_mkpc), 10 ether);
        _mkpc.createBid(1, 1 ether * (5 / 10), 2 weeks);

        vm.startPrank(seller);
        _mkpc.cancelSale(1);
        bytes4 selector = bytes4(keccak256("offerClosed()"));
        vm.expectRevert(selector);
        _mkpc.acceptBid(1, 0);
        vm.stopPrank();
    }

    function test_Revert_AcceptBid_Index_Out_Of_Bounds() public {
        vm.prank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(bidder);
        _weth.approve(address(_mkpc), 10 ether);
        _mkpc.createBid(1, 1 ether * (5 / 10), 2 weeks);

        vm.startPrank(seller);

        vm.expectRevert("index out of bound");
        _mkpc.acceptBid(1, 2);
        vm.stopPrank();
    }

    function test_Revert_AcceptBid_If_Offer_Is_Expired() public {
        vm.prank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(bidder);
        _weth.approve(address(_mkpc), 10 ether);
        _mkpc.createBid(1, 1 ether * (5 / 10), 2 weeks);

        skip(3 weeks);

        vm.startPrank(seller);

        vm.expectRevert("offer expired");
        _mkpc.acceptBid(1, 0);
        vm.stopPrank();
    }

    function test_Revert_AcceptBid_If_Bidder_Not_Enough_Balance() public {
        vm.prank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(bidder, bidder);
        bool approved = _weth.approve(address(_mkpc), 10 ether);
        assertEq(approved, true, "approval unsuccesful");
        _mkpc.createBid(1, 1 ether * (5 / 10), 2 weeks);

        //Change bidder balance to 0
        deal(address(_weth), bidder, 0);
        vm.stopPrank();

        vm.startPrank(seller);
        vm.expectRevert("WETH: not enough balance");
        _mkpc.acceptBid(1, 0);
        vm.stopPrank();
    }

    function test_Revert_AcceptBid_If_Bidder_Not_Enough_Allowance() public {
        vm.prank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(bidder);
        _weth.approve(address(_mkpc), 10 ether);
        _mkpc.createBid(1, 1 ether * (5 / 10), 2 weeks);
        _weth.approve(address(_mkpc), 0);
        vm.stopPrank();

        vm.startPrank(seller);
        vm.expectRevert("Bidder: not enough allowance");
        _mkpc.acceptBid(1, 0);
        vm.stopPrank();
    }

    //TODO: asserts : payment sent to previous owner, NFT sent to new owner
    function test_AcceptBid() public {
        vm.prank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(bidder);
        _weth.approve(address(_mkpc), 10 ether);
        _mkpc.createBid(1, 1 ether * (5 / 10), 2 weeks);

        vm.startPrank(seller);

        _mkpc.acceptBid(1, 0);
        vm.stopPrank();
    }

    function test_Emit_AcceptBid_SaleSuccessful() public {
        vm.prank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(bidder);
        _weth.approve(address(_mkpc), 10 ether);
        _mkpc.createBid(1, 1 ether * (5 / 10), 2 weeks);

        vm.startPrank(seller);
        vm.expectEmit();
        emit SaleSuccessful(1, seller, bidder, 1 ether * (5 / 10));

        _mkpc.acceptBid(1, 0);
        vm.stopPrank();
    }
}

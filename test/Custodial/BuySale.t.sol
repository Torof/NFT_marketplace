// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

import "./SetUp.t.sol";

contract BuySale is SetUp {
    function test_Revert_BuySale_If_Balance_Not_Enough() public {
        vm.prank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        hoax(empty, 1 ether);
        //reverts because there isn't enough ether to cover the price
        bytes4 selector = bytes4(keccak256("notEnoughBalance()"));
        vm.expectRevert(selector);
        _mkpc.buySale{value: 1 ether}(1);
    }

    function test_Revert_BuySale_If_Price_Not_Right() public {
        vm.prank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.prank(buyer);
        //reverts because there isn't enough ether to cover the price
        vm.expectRevert("not the right amount");
        _mkpc.buySale{value: 1 ether}(1);
    }

    function test_Revert_BuySale_If_OfferClosed() public {
        vm.startPrank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        //Verify that sale and bids are open.
        bool isClosed = _mkpc.getSaleOrder(1).closed;
        assertEq(isClosed, false);

        //Cancel the sale
        _mkpc.cancelSale(1);
        vm.stopPrank();
        //Verify that sale is closed
        isClosed = _mkpc.getSaleOrder(1).closed;
        assertEq(isClosed, true);

        vm.prank(buyer);
        //reverts because offer is closed
        bytes4 selector = bytes4(keccak256("offerClosed()"));
        vm.expectRevert(selector);
        _mkpc.buySale{value: 2 ether}(1);
    }

    //CHECK: possible non standard NFT ?

    function test_BuySale() public {
        vm.startPrank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        //Verify that sale and bids are open.
        bool isClosed = _mkpc.getSaleOrder(1).closed;
        assertEq(isClosed, false);

        vm.prank(buyer);
        //Buy sale
        _mkpc.buySale{value: 2 ether}(1);

        //verify buyer is buyer
        address buyer_ = _mkpc.getSaleOrder(1).buyer;
        assertEq(buyer, buyer_);

        //verify buyer is new owner
        address ownerOf = _nft721.ownerOf(_mkpc.getSaleOrder(1).tokenId);
        assertEq(buyer, ownerOf);

        //verify offer is closed
        isClosed = _mkpc.getSaleOrder(1).closed;
        assertEq(isClosed, true);
    }

    function test_Emit_BuySale_SaleSuccessful() public {
        vm.startPrank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.prank(buyer);
        //Buy sale
        vm.expectEmit();
        // We emit the SaleSuccessful event we expect to see.
        emit SaleSuccessful(1, seller, buyer, 2 ether);
        _mkpc.buySale{value: 2 ether}(1);
    }
}

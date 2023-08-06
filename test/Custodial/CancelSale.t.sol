// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

import "./SetUp.t.sol";

contract CancelSale is SetUp {
    function test_Revert_CancelSale_if_Not_Owner() public {
        vm.prank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);
        vm.prank(buyer);
        bytes4 selector = bytes4(keccak256("notOwner(string)"));
        vm.expectRevert(abi.encodeWithSelector(selector, "Sale"));
        _mkpc.cancelSale(1);
    }

    function test_CancelSale_If_OfferClosed() public {
        vm.startPrank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);
        _mkpc.cancelSale(1);

        bytes4 selector = bytes4(keccak256("offerClosed()"));
        vm.expectRevert(selector);
        _mkpc.cancelSale(1);
        vm.stopPrank();
    }

    //TODO: revert if standard not recognized

    function test_CancelSale() public {
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

        //Verify that there is no buyer
        address buyer_ = _mkpc.getSaleOrder(1).buyer;
        assertEq(buyer_, address(0));
    }

    function test_Emit_CancelSale_SaleCanceled() public {
        vm.startPrank(seller);

        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.expectEmit();
        // We emit the CancelSale event we expect to see.
        emit SaleCanceled(1);
        //Cancel the sale
        _mkpc.cancelSale(1);
        vm.stopPrank();
    }
}

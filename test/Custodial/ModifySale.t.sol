    // SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

import "./BaseSetUp.sol";

contract ModifySale is BaseSetUp {
    //Not owner of sale
    function test_Revert_ModifySale_If_Not_Owner() public {
        vm.prank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);
        vm.prank(buyer);
        bytes4 selector = bytes4(keccak256("notOwner(string)"));
        vm.expectRevert(abi.encodeWithSelector(selector, "Sale"));
        _mkpc.modifySale(1, 5 ether);
    }

    function test_Revert_ModifySale_If_Offer_Closed() public {
        vm.startPrank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);
        _mkpc.cancelSale(1);
        bytes4 selector = bytes4(keccak256("offerClosed()"));
        vm.expectRevert(selector);
        _mkpc.modifySale(1, 5 ether);
        vm.stopPrank();
    }

    function test_ModifySale() public {
        vm.startPrank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);
        uint256 price = _mkpc.getSaleOrder(1).price;
        assertEq(price, 2 ether);
        _mkpc.modifySale(1, 5 ether);
        price = _mkpc.getSaleOrder(1).price;
        assertEq(price, 5 ether);
        vm.stopPrank;
    }

    function test_Emit_ModifySale_SaleModified() public {
        vm.startPrank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);
        vm.expectEmit();
        emit SaleModified(1, 5 ether);
        _mkpc.modifySale(1, 5 ether);
    }
}

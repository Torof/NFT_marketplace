// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

import "./BaseSetUp.sol";

contract CreateSale is BaseSetUp {
    //Revert if caller is not owner of NFT

    function test_Revert_CreateSale_if_NotOwner() public {
        vm.startPrank(buyer);
        bytes4 selector = bytes4(keccak256("notOwner(string)"));

        vm.expectRevert(abi.encodeWithSelector(selector, "ERC721"));
        _mkpc.createSale(address(_nft721), 3, 2 ether);
        vm.stopPrank();
    }

    //Revert if seller did not approve markeplace to transfer NFT -- isApprovedForAll
    function test_Revert_CreateSale_if_NotApproved() public {
        vm.prank(owner);
        //Send NFT to user to create sale
        _nft721.transferFrom(owner, buyer, 3);

        vm.startPrank(buyer);
        bytes4 selector = bytes4(keccak256("notApproved()"));
        vm.expectRevert(selector);
        _mkpc.createSale(address(_nft721), 3, 2 ether);
        vm.stopPrank();
    }

    //Revert if prive is negative or eq to 0
    function test_Revert_CreateSale_if_Price_Not_GT_Than_0() public {
        vm.prank(seller);
        vm.expectRevert("price must be > 0");
        _mkpc.createSale(address(_nft721), 1, 0);
    }

    //Check reverts if standard is not erc721 or erc1155 (supportsInterface)
    function test_Revert_CreateSale_Standard_Not_Recognized() public {}

    function test_CreateSale_ERC721() public {
        vm.prank(seller);
        //Create sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        //Verify that seller is registered
        address seller_ = _mkpc.getSaleOrder(1).seller;
        assertEq(seller, seller_);
    }

    function test_CreateSale_ERC1155() public {
        vm.prank(seller);
        //Create sale
        _mkpc.createSale(address(_nft1155), 1, 2 ether);

        //Verify that seller is registered
        address seller_ = _mkpc.getSaleOrder(1).seller;
        assertEq(seller, seller_);
    }

    //TODO: complete
    function test_GetSaleOrder() public {
        vm.prank(seller);
        //Create sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        //Verify that saleOrder has right info
        address seller_ = _mkpc.getSaleOrder(1).seller;
        assertEq(seller, seller_);
    }

    function test_Emit_CreateSale_SaleCreated() public {
        vm.prank(seller);

        vm.expectEmit();

        // We emit the SaleCreated event we expect to see.
        emit SaleCreated(1, seller, 1, address(_nft721), type(IERC721).interfaceId, 2 ether);

        //Create sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);
    }

    function test_Emit_CreateSale_NFTReceived() public {
        vm.prank(seller);

        vm.expectEmit();

        // We emit the event we expect to see.
        emit NFTReceived(address(_mkpc), seller, 1, 1, type(IERC721).interfaceId, "");

        //Create sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);
    }
}

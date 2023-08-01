// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

//TODO: test events
//TODO: test potential security issues
//TODO: test scenarii

/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

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
    address public seller = vm.addr(1);
    address public alice = vm.addr(2);
    address public tom = vm.addr(3);
    address public empty = vm.addr(4);

    function setUp() public {
        //Create WETH for testing
        _weth = new WETH();

        //Deals Ether and WETH to addresses for testing
        vm.deal(owner, 1 ether);
        vm.deal(seller, 10 ether);
        vm.deal(alice, 5 ether);
        vm.deal(tom, 1 ether);
        deal(address(_weth), seller, 10 ether);
        deal(address(_weth), alice, 5 ether);
        deal(address(_weth), tom, 1 ether);

        //Deploy marketplace and 2 NFT collections, erc721 and erc1155
        vm.startPrank(owner);
        _mkpc = new MarketplaceCustodial(address(_weth));
        _nft721 = new NFT721();
        _nft1155 = new NFT1155(25);
        _nft721.transferFrom(owner, seller, 1);
        _nft721.transferFrom(owner, seller, 2);
        vm.stopPrank();

        //Seller approves marketplace to transfer NFT on its behalf
        vm.prank(seller);
        _nft721.setApprovalForAll(address(_mkpc), true);
    }

    //Helper function
    function createASaleOrder() public {
        vm.prank(seller);
        //Create sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        //Verify that seller is registered
        address seller_ = _mkpc.getSaleOrder(1).seller;
        assertEq(seller, seller_);
    }

    //Helper function
    function createBid() public {
        createASaleOrder();
        vm.startPrank(alice);
        //approve for  eth allowance
        _weth.approve(address(_mkpc), 2 ether);
        //Create a bid for 1.5 eth
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);
        vm.stopPrank();
    }

    //Direct transfer from safeTransferFrom() disabled
    function test_Revert_On_Direct_Transfer() public {
        //Should revert if NFT is sent directly with SafeTransferFrom
        vm.prank(seller, seller);
        vm.expectRevert("direct transfer not allowed");
        _nft721.safeTransferFrom(seller, address(_mkpc), 1);
    }

    //Revert if caller is not owner of NFT
    function test_Revert_CreateSale_if_NotOwner() public {
        vm.startPrank(alice);
        bytes4 selector = bytes4(keccak256("notOwner()"));
        vm.expectRevert(selector);
        _mkpc.createSale(address(_nft721), 3, 2 ether);
        vm.stopPrank();
    }

    //Revert if seller did not approve markeplace to transfer NFT -- isApprovedForAll
    function test_Revert_CreateSale_if_NotApproved() public {
        vm.prank(owner);
        //Send NFT to user to create sale
        _nft721.transferFrom(owner, alice, 3);

        vm.startPrank(alice);
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
    function test_Revert_Standard_Not_Recognized() public {}

    function test_CreateSale() public {
        vm.prank(seller);
        //Create sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        //Verify that seller is registered
        address seller_ = _mkpc.getSaleOrder(1).seller;
        assertEq(seller, seller_);
    }

    //Not owner of sale
    function test_Revert_ModifySale_If_Not_Owner() public {
        vm.prank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);
        vm.prank(alice);
        bytes4 selector = bytes4(keccak256("notOwner()"));
        vm.expectRevert(selector);
        _mkpc.modifySale(1, 5 ether);
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

    function test_Revert_CancelSale_if_Not_Owner() public {
        vm.prank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);
        vm.prank(alice);
        bytes4 selector = bytes4(keccak256("notOwner()"));
        vm.expectRevert(selector);
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

        vm.prank(alice);
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

        vm.prank(alice);
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

        vm.prank(alice);
        //Buy sale
        _mkpc.buySale{value: 2 ether}(1);

        //verify alice is buyer
        address buyer_ = _mkpc.getSaleOrder(1).buyer;
        assertEq(alice, buyer_);

        //verify alice is new owner
        address ownerOf = _nft721.ownerOf(_mkpc.getSaleOrder(1).tokenId);
        assertEq(alice, ownerOf);

        //verify offer is closed
        isClosed = _mkpc.getSaleOrder(1).closed;
        assertEq(isClosed, true);
    }

    function test_Revert_CreateBid_If_Offer_Not_GT_0() public {
        vm.prank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.prank(alice);
        //Create a bid
        vm.expectRevert("amount can't be zero");
        _mkpc.createBid(1, 0, 1 weeks);

        //check bids list is empty
        uint256 length = _mkpc.getSaleOrder(1).bids.length;
        assertEq(length, 0);
    }

    function test_Revert_CreateBid_If_Allowance_Not_Enough() public {
        vm.prank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 4 ether);

        vm.startPrank(alice);
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
        vm.prank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.prank(alice);
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

        vm.prank(alice);
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
        vm.prank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(alice);
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
        assertEq(firstBid.bidder, alice);
        assertEq(firstBid.offerPrice, 1 ether + (1 ether * 5 / 10));
        assertEq(firstBid.duration, 1 weeks);
    }

    function test_ModifyBid() public {}

    function test_Revert_CancelBid_If_caller_Is_Not_Bidder() public {
        vm.prank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(alice);
        //approve for  eth allowance
        _weth.approve(address(_mkpc), 2 ether);
        //Create a bid for 1.5 eth
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);
        vm.stopPrank();
        vm.prank(tom);
        bytes4 selector = bytes4(keccak256("notOwner()"));
        vm.expectRevert(selector);
        _mkpc.cancelBid(1, 0);
    }

    function test_Revert_CancelBid_Index_Out_Of_Bounds() public {
        vm.prank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(alice);
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

    function test_CancelOffer() public {
        vm.prank(seller);
        //Create a sale
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(alice);
        //approve for  WETH allowance
        _weth.approve(address(_mkpc), 5 ether);
        //Create a bid for 1.5 WETH
        _mkpc.createBid(1, 1 ether + (1 ether * 5 / 10), 1 weeks);

        //cancel bid 0
        _mkpc.cancelBid(1, 0);

        vm.stopPrank();
    }

    function test_Revert_AcceptBid_If_SaleClosed() public {
        address ownerOf = _nft721.ownerOf(1);
        assertEq(seller, ownerOf);
        vm.prank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(tom);
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
        address ownerOf = _nft721.ownerOf(1);
        assertEq(seller, ownerOf);
        vm.prank(seller);
        _mkpc.createSale(address(_nft721), 1, 2 ether);

        vm.startPrank(tom);
        _weth.approve(address(_mkpc), 10 ether);
        _mkpc.createBid(1, 1 ether * (5 / 10), 2 weeks);

        vm.startPrank(seller);

        // bytes4 selector = bytes4(keccak256("offerClosed()"));
        vm.expectRevert("index out of bound");
        _mkpc.acceptBid(1, 2);
        vm.stopPrank();
    }

    function test_Revert_AcceptBid_If_Offer_Is_Expired() public {}

    function test_Revert_AcceptBid_If_Bidder_Not_Enough_Balance() public {}

    function test_Revert_AcceptBid_If_Bidder_Not_Enough_Allowance() public {}

    function test_AcceptBid() public {}

    //===========================================//
    //                                           //
    //            Scenarii                       //
    //                                           //
    //===========================================//

    function test_Scenario() public {}
}

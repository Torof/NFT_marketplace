// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

//TODO: test potential security issues
//TODO: test scenarii

/**
 * @notice the 'ether' modifier is used to signify units. Some functions use the 'ether' modifier while the currency is in WETH.
 */

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/testing/WETH.sol";
import "../../src/testing/NFT721.sol";
import "../../src/testing/NFT1155.sol";
import "../../src/custodial/MarketplaceCustodial.sol";

contract SetUp is Test {
    WETH public _weth;
    MarketplaceCustodial public _mkpc;
    NFT721 public _nft721;
    NFT1155 public _nft1155;

    address public owner = vm.addr(10);
    address public seller = vm.addr(1);
    address public buyer = vm.addr(2);
    address public bidder = vm.addr(3);
    address public empty = vm.addr(4);

    event NFTReceived(address operator, address from, uint256 tokenId, uint256 amount, bytes4 standard, bytes data);
    event BatchNFTReceived(
        address _operator, address _from, uint256[] ids, uint256[] values, string standard, bytes data
    );
    event SaleCreated(
        uint256 offerId, address from, uint256 tokenId, address contractAddress, bytes4 standard, uint256 price
    );
    event SaleCanceled(uint256 marketOfferId);
    event SaleSuccessful(uint256 marketOfferId, address seller, address buyer, uint256 price);
    event BidSubmitted(uint256 marketOfferId, address offerer, uint256 offerPrice);
    event BidCanceled(uint256 marketOfferId, address offererAddress, uint256 canceledOffer);
    event FeesModified(uint256 newFees);
    /**
     * @notice Emitted when a seller cancel its sale
     */
    event SaleModified(uint256 marketOfferId, uint256 newPrice);

    function setUp() public {
        //Create WETH for testing
        _weth = new WETH();

        //Deals Ether and WETH to addresses for testing
        vm.deal(owner, 1 ether);
        vm.deal(seller, 10 ether);
        vm.deal(buyer, 5 ether);
        vm.deal(bidder, 1 ether);
        deal(address(_weth), seller, 10 ether);
        deal(address(_weth), buyer, 5 ether);
        deal(address(_weth), bidder, 1 ether);

        //Deploy marketplace and 2 NFT collections, erc721 and erc1155
        vm.startPrank(owner);
        _mkpc = new MarketplaceCustodial(address(_weth), 10);
        _nft721 = new NFT721();
        _nft1155 = new NFT1155(25);
        _nft721.transferFrom(owner, seller, 1);
        _nft721.transferFrom(owner, seller, 2);
        vm.stopPrank();

        //Seller approves marketplace to transfer NFT on its behalf
        vm.prank(seller);
        _nft721.setApprovalForAll(address(_mkpc), true);
    }
}

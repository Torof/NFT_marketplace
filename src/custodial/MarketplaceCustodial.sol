/// TODO: add security extension contract (NFT unlock, withdraw ETH, onlyEOA ...)
/// TODO: gas opti
/// CHECK: if offer expired , delete offer ?

/**
 * @author Torof
 * @title  A custodial NFT MarketPlace
 * @notice This marketplace allows the listing and selling of {ERC721} and {ERC1155} Non Fungible & Semi Fungible Tokens.
 * @dev    The marketplace MUST hold the NFT in custody. Offers follow a non custodial model using Wrapped Ethereum.
 *         Sender needs to have sufficiant WETH funds to submit offer.
 *         Showing the onGoing offers and not the expired offers must happen on the front-end.
 */

/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MarketplaceCustodial is ReentrancyGuard, IERC721Receiver, IERC1155Receiver, Ownable {
    /// sale id - all sales ongoing and closed
    uint256 public marketOffersNonce = 1;

    /// percentage of the fee. starts at 0, cannot be more than 10
    uint256 public marketPlaceFee;

    /// All the fees in ETH gathered by the markeplace
    uint256 private _ethFees;

    /// All the fees in WETH gathered by the markeplace
    uint256 private _wethFees;

    //WETH contract
    //TODO: better to have contract object or address ?
    ERC20 public immutable WETH;
    mapping(uint256 => SaleOrder) public marketOffers;
    // mapping(address => uint256) public balanceOfEth;

    struct SaleOrder {
        /// price of the sale
        uint256 price;
        //Id of the NFT token for sale
        uint256 tokenId;
        ///address of the NFT contract
        address contractAddress;
        /// address that created the sale
        address seller;
        /// address that bought the sale
        address buyer;
        /// standard of the collection - bytes4 of {IERC721} interface OR {IERC1155} interface - only ERC721 and ERC1155 accepted
        bytes4 standard;
        ///sale is on or finished
        bool closed;
        ///Array containing all the bids made for a NFT
        Bid[] bids;
    }

    struct Bid {
        ///Address that made the bid
        address bidder;
        ///Price of the bid
        uint256 offerPrice;
        ///Maximum duration of the bid
        uint256 duration;
        ///Time at which the bid was initiated. Used to calculate max duration
        uint256 offerTime;
    }

    //=============================================
    //
    //           EVENTS
    //
    //=============================================

    /**
     * @notice Emitted when a NFT is received
     */
    event NFTReceived(address operator, address from, uint256 tokenId, uint256 amount, bytes4 standard, bytes data);

    event BatchNFTReceived(
        address _operator, address _from, uint256[] ids, uint256[] values, string standard, bytes data
    );

    /**
     * @notice Emitted when a new market sale is created
     */
    event SaleCreated(
        uint256 offerId, address from, uint256 tokenId, address contractAddress, bytes4 standard, uint256 price
    );

    /**
     * @notice Emitted when a seller cancel its sale
     */
    event SaleCanceled(uint256 marketOfferId);

    /**
     * @notice Emitted when a seller cancel its sale
     */
    event SaleModified(uint256 marketOfferId, uint256 newPrice);

    /**
     * @notice Emitted when a sale is successfully concluded
     */
    event SaleSuccessful(uint256 marketOfferId, address seller, address buyer, uint256 price);

    /**
     * @notice Emitted when a new bid is made
     */
    event BidSubmitted(uint256 marketOfferId, address bidder, uint256 bidPrice);

    /**
     * @notice Emitted when a bid is modified
     */
    event BidModified(uint256 marketOfferId, address bidder, uint256 newPrice);

    /**
     * @notice Emitted when a bidder cancel its offer
     */
    event BidCanceled(uint256 marketOfferId, address bidder, uint256 canceledBid);

    /**
     * @notice Emitted when the markeplace fees are modified
     */
    event FeesModified(uint256 newFees);

    //===========================================
    //
    //           ERRORS
    //
    //===========================================

    error offerClosed();

    error failedToSend_ETH();

    error failedToSend_WETH();

    error notOwner(string);

    error notEnoughBalance();

    error notApproved();

    error standardNotRecognized();

    constructor(address _WETH, uint256 _fees) {
        WETH = ERC20(_WETH);
        marketPlaceFee = _fees;
    }

    /// ==========================================
    ///    Receive & support interfaces
    /// ==========================================

    // receive() external payable {
    //     ///TODO: verify sender is not contract, if not revert
    //     ///CHECK: change to WETH ?
    //     ///CHECK: add an error vault ?
    //     if (msg.value > 0) revert("not allowed receive");
    // }

    fallback() external {
        revert("not allowed fallback");
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @notice         MUST be implemented to be compatible with all ERC721 standards NFTs
     * @return bytes4  function {onERC721Received} selector
     * @param operator address allowed to transfer NFTs on owner's behalf
     * @param from     address the NFT comes from
     * @param tokenId  id of the NFT within its collection
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        if (msg.sender != address(this) && tx.origin == operator) {
            revert("direct transfer not allowed");
        } //disallow direct transfers with safeTransferFrom()
        emit NFTReceived(operator, from, tokenId, 1, type(IERC721).interfaceId, data);
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @notice         MUST be implemented to be compatible with all ERC1155 standards NFTs single transfers
     * @return bytes4  of function {onERC1155Received} selector
     * @param operator address allowed to transfer NFTs on owner's behalf
     * @param from     address the NFT comes from
     * @param id       the id of the NFT within its collection
     * @param value    quantity received. Use case for Semi Fungible Tokens
     */
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        if (msg.sender != address(this) && tx.origin == operator) {
            revert("direct transfer not allowed");
        } //disallow direct transfers
        emit NFTReceived(operator, from, id, value, type(IERC1155).interfaceId, data);
        return IERC1155Receiver.onERC1155Received.selector;
    }

    /**
     * @notice         MUST be implemented to be compatible with all ERC1155 standards NFTs batch transfers
     * @return bytes4  of function {onERC1155BatchReceived} selector
     * @param operator address allowed to transfer NFTs on owner's behalf
     * @param from     address the NFT comes from
     * @param ids      an array of all the ids of the tokens within their collection/type
     * @param values   quantity of each received. Use case for Semi Fungible Tokens
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        //disallow direct transfers
        if (msg.sender != address(this) && tx.origin == operator) {
            revert("direct transfer not allowed");
        }
        emit BatchNFTReceived(operator, from, ids, values, "ERC1155", data);
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    /// =============================================
    ///       Marketplace functions
    /// =============================================

    ///ALERT: no float points allowed, units should be changed to avoid problems
    /**
     * @notice set the fees. CANNOT be negative or more than 10%
     * @param  newFees the fee the marketplace will receive from each sale
     */
    function setFees(uint256 newFees) external onlyOwner {
        require(newFees <= 10, "can't be more than 10%");
        marketPlaceFee = newFees;
        emit FeesModified(newFees);
    }

    /**
     * @notice withdraw all gains in ETH made from the sales fees all at once.
     */
    function withdrawEthFees() external payable onlyOwner {
        uint256 fees = _ethFees;
        _ethFees = 0;
        (bool sent,) = msg.sender.call{value: fees}("");
        if (!sent) revert failedToSend_ETH();
    }

    /**
     * @notice withdraw all gains made in WETH from the sales fees all at once.
     */
    function withdrawWethFees() external payable onlyOwner {
        uint256 fees = _wethFees;
        _wethFees = 0;
        bool sent = ERC20(WETH).transfer(msg.sender, fees);
        if (!sent) revert failedToSend_WETH();
    }

    /// ==========================================
    ///      Main sale
    /// ==========================================

    /**
     * @notice opens a new sale of a single NFT. Supports {ERC721} and {ERC1155}. Compatible with {ERC721A}
     * @param contractAddress   the address of the NFT's contract
     * @param tokenId   id of the token within its collection
     * @param price   price defined by the creator/seller
     *
     */
    function createSale(address contractAddress, uint256 tokenId, uint256 price) external nonReentrant {
        require(price > 0, "price must be > 0");
        //BUG: verify creator has approved marketplace for transfer from NFT contract
        bytes4 standard;

        ///assign collection address - ERC721
        if (ERC721(contractAddress).supportsInterface(type(IERC721).interfaceId)) {
            ERC721 collection = ERC721(contractAddress);

            ///creator must own NFT
            if (collection.ownerOf(tokenId) != msg.sender) revert notOwner("ERC721");

            ///Verify caller has approved marketplace for all NFTs of one contract - ERC721
            if (!collection.isApprovedForAll(msg.sender, address(this))) revert notApproved();

            ///NFT's standard - ERC721
            standard = type(IERC721).interfaceId;

            _createSale(contractAddress, msg.sender, tokenId, price, standard);

            ///Transfer NFT to marketplace contract for custody - ERC721
            collection.safeTransferFrom(msg.sender, address(this), tokenId);
        }
        ///assign colection address - ERC1155
        else if (ERC1155(contractAddress).supportsInterface(type(IERC1155).interfaceId)) {
            ERC1155 collection = ERC1155(contractAddress);

            ///Verify caller is token owner
            if (collection.balanceOf(msg.sender, tokenId) < 1) revert notOwner("ERC1155");

            ///Verify caller has approved marketplace for all NFTs of one contract - ERC1155
            if (!collection.isApprovedForAll(msg.sender, address(this))) revert notApproved();

            /// NFT's standard - ERC1155
            standard = type(IERC1155).interfaceId;

            _createSale(contractAddress, msg.sender, tokenId, price, standard);

            /// Transfer NFT to marketplace contract for custody - ERC1155
            collection.safeTransferFrom(msg.sender, address(this), tokenId, 1, "");
        } else {
            revert standardNotRecognized();
        }
    }

    /**
     * @notice modify the sale's price
     * @param  marketOfferId index of the saleOrder
     * @param  newPrice the new price of the sale
     */
    function modifySale(uint256 marketOfferId, uint256 newPrice) external {
        ///Verify caller is seller
        if (msg.sender != marketOffers[marketOfferId].seller) {
            revert notOwner("Sale");
        }
        /// offer must still be ongoing to cancel
        if (marketOffers[marketOfferId].closed) revert offerClosed();
        ///Set new price
        marketOffers[marketOfferId].price = newPrice;

        emit SaleModified(marketOfferId, newPrice);
    }

    /**
     * @notice cancel a sale.
     * @param  marketOfferId index of the saleOrder
     */
    function cancelSale(uint256 marketOfferId) external nonReentrant {
        SaleOrder memory saleOrder = marketOffers[marketOfferId];

        /// offer must still be ongoing to cancel
        if (saleOrder.closed) revert offerClosed();

        ///caller must be seller
        if (msg.sender != saleOrder.seller) revert notOwner("Sale");

        /// sale is over
        marketOffers[marketOfferId].closed = true;

        if (saleOrder.standard == type(IERC721).interfaceId) {
            /// sale is canceled NFt sent back to its owner - ERC721
            ERC721(saleOrder.contractAddress).safeTransferFrom(address(this), msg.sender, saleOrder.tokenId);
        } else if (saleOrder.standard == type(IERC1155).interfaceId) {
            /// sale is canceled and erc1155 NFT sent back to its owner
            ERC1155(saleOrder.contractAddress).safeTransferFrom(address(this), msg.sender, saleOrder.tokenId, 1, "");
        } else {
            revert standardNotRecognized();
        }

        emit SaleCanceled(marketOfferId);
    }

    //TODO: verify is not a contract
    //CHECK: use send or transfer over call ?
    /**
     * @notice allows anyone to buy instantly a NFT at asked price.
     * @dev    fees SHOULD be automatically soustracted
     * @param  marketOfferId index of the saleOrder
     * emits a {SaleSuccesful} event
     */
    function buySale(uint256 marketOfferId) external payable nonReentrant {
        //Offer must be ongoing
        if (marketOffers[marketOfferId].closed) revert offerClosed();

        ///caller must have balance
        if ((msg.sender).balance < marketOffers[marketOfferId].price) revert notEnoughBalance();
        //ALERT: redundant checks
        /// give the exact amount to buy
        require(msg.value == marketOffers[marketOfferId].price, "not the right amount");

        /// update buyer
        marketOffers[marketOfferId].buyer = msg.sender;

        /// close offer
        marketOffers[marketOfferId].closed = true;

        SaleOrder memory offer = marketOffers[marketOfferId];

        /// Fees of the marketplace
        uint256 afterFees = msg.value - ((msg.value * marketPlaceFee) / 100);
        _ethFees += ((msg.value * marketPlaceFee) / 100);

        /// check if NFT is a erc721 standard NFT
        if (ERC721(offer.contractAddress).supportsInterface(type(IERC721).interfaceId)) {
            /// transfer NFT ERC721 to new owner
            ERC721(offer.contractAddress).safeTransferFrom(address(this), msg.sender, offer.tokenId);
        }
        /// check if NFT is a erc1155 standard NFT
        else if (ERC1155(offer.contractAddress).supportsInterface(type(IERC1155).interfaceId)) {
            /// transfer NFT ERC1155 to new owner
            ERC1155(offer.contractAddress).safeTransferFrom(address(this), msg.sender, offer.tokenId, 1, "");
        } else {
            revert standardNotRecognized();
        }

        ///buyer sends sale price to seller
        (bool sent2,) = marketOffers[marketOfferId].seller.call{value: afterFees}("");
        if (!sent2) revert failedToSend_ETH();

        emit SaleSuccessful(
            marketOfferId, marketOffers[marketOfferId].seller, msg.sender, marketOffers[marketOfferId].price
        );
    }

    // =========================================
    //      Secondary offers
    // =========================================

    /**
     * @notice make an offer. Offer is made and sent in WETH.
     * @param  marketOfferId index of the saleOrder
     * @param  amount price of the offer
     * @param  duration duration of the offer
     *
     * emits a {OfferSubmitted} event
     */
    function createBid(uint256 marketOfferId, uint256 amount, uint256 duration) external nonReentrant {
        require(amount > 0, "amount can't be zero");

        ///Only if offer is still ongoing
        if (marketOffers[marketOfferId].closed) revert offerClosed();

        /// caller must have enough WETH balance to create order
        if (WETH.balanceOf(msg.sender) < amount) revert notEnoughBalance();

        //WETH allowance from bidder to marketplace
        require(WETH.allowance(msg.sender, address(this)) >= amount, "not enough balance allowed");

        Bid memory tempO = Bid({bidder: msg.sender, offerTime: block.timestamp, offerPrice: amount, duration: duration});

        ///Submit new bid to order's bid list
        marketOffers[marketOfferId].bids.push(tempO);
        emit BidSubmitted(marketOfferId, msg.sender, amount);
    }

    //TODO: add duration modif?
    //TODO: natspec
    /**
     *
     */
    function modifyBid(uint256 marketOfferId, uint256 bidIndex, uint256 newPrice) external {
        require(marketOffers[marketOfferId].bids.length != 0, "no bids");

        ///Revert if bid index doesn't exist
        require(marketOffers[marketOfferId].bids.length - 1 >= bidIndex, "index out of bounds");

        //Only bidder can modify its bid
        if (marketOffers[marketOfferId].bids[bidIndex].bidder != msg.sender) revert notOwner("Bid");

        ///Only if offer is still ongoing
        if (marketOffers[marketOfferId].closed) revert offerClosed();

        ///Set new price of bid
        marketOffers[marketOfferId].bids[bidIndex].offerPrice = newPrice;

        emit BidModified(marketOfferId, msg.sender, newPrice);
    }

    /**
     * @notice cancel an offer made.
     * @param marketOfferId id of the sale
     *
     * Emits a {offerCanceled} event
     */
    function cancelBid(uint256 marketOfferId, uint256 bidIndex) external {
        ///Revert if no bids for this order
        require(marketOffers[marketOfferId].bids.length != 0, "no bids");

        ///Revert if bid index doesn't exist
        require(marketOffers[marketOfferId].bids.length - 1 >= bidIndex, "index out of bounds");

        ///Only bidder can cancel a bid
        if (msg.sender != marketOffers[marketOfferId].bids[bidIndex].bidder) revert notOwner("Bid");

        ///Delete bid
        marketOffers[marketOfferId].bids[bidIndex] =
            marketOffers[marketOfferId].bids[marketOffers[marketOfferId].bids.length - 1];
        marketOffers[marketOfferId].bids.pop();

        emit BidCanceled(marketOfferId, msg.sender, 0);
    }

    //ALERT: unsafe erc20 safeTransfer and unsafe erc721 && erc1155 transfers ?
    //FIXME: use oracle for time fetching
    /**
     * @notice a third party made an offer below the asked price and seller accepts
     * @dev    fees SHOULD be automatically substracted
     * @param  marketOfferId id of the sale
     *
     * Emits a {SaleSuccesful} event
     */
    function acceptBid(
        uint256 marketOfferId,
        uint256 index //ALERT: order price and bought at price are different
    ) external nonReentrant {
        SaleOrder storage order = marketOffers[marketOfferId];
        require(index < order.bids.length, "index out of bound");
        Bid memory offer = marketOffers[marketOfferId].bids[index];

        ///verify caller is owner of the token - sale
        if (order.seller != msg.sender) revert notOwner("Bid");
        if (order.closed) revert offerClosed();

        //TODO: change to custom error
        require(block.timestamp < offer.offerTime + offer.duration, "offer expired");
        require(WETH.balanceOf(offer.bidder) > offer.offerPrice, "WETH: not enough balance");
        require(
            WETH.allowance(offer.bidder, address(this)) >= order.bids[index].offerPrice, "Bidder: not enough allowance"
        );

        /// update buyer
        order.buyer = offer.bidder;

        /// update sell price
        order.price = offer.offerPrice;

        /// offer is now over
        order.closed = true;

        /// Fees of the marketplace
        uint256 afterFees = offer.offerPrice - ((offer.offerPrice * marketPlaceFee) / 100);
        _wethFees += (offer.offerPrice * marketPlaceFee) / 100;

        if (order.standard == type(IERC721).interfaceId) {
            ERC721(order.contractAddress).safeTransferFrom(address(this), order.buyer, order.tokenId);
        }
        /// transfer NFT ERC1155 to new owner
        else if (order.standard == type(IERC1155).interfaceId) {
            ERC1155(order.contractAddress).safeTransferFrom(address(this), order.buyer, order.tokenId, 1, "");
        } else {
            revert standardNotRecognized();
        }

        bool sent1 = ERC20(WETH).transferFrom(offer.bidder, msg.sender, afterFees);
        if (!sent1) revert failedToSend_WETH();

        bool sent2 = ERC20(WETH).transferFrom(offer.bidder, address(this), (offer.offerPrice * marketPlaceFee) / 100);
        if (!sent2) revert failedToSend_WETH();

        emit SaleSuccessful(marketOfferId, order.seller, order.buyer, offer.offerPrice);
    }

    /// ================================
    ///    INTERNAL
    /// ================================

    function _createSale(address contractAddress, address seller, uint256 tokenId, uint256 price, bytes4 standard)
        internal
    {
        SaleOrder storage order = marketOffers[marketOffersNonce];

        /// collection address
        order.contractAddress = contractAddress;

        /// seller address , cannot be msg.sender since internal
        order.seller = seller;

        ///sale price
        order.price = price;

        order.tokenId = tokenId;

        ///NFT's standard
        order.standard = standard;

        emit SaleCreated(marketOffersNonce, seller, tokenId, contractAddress, standard, price);
        marketOffersNonce++;
    }

    /// ===============================
    ///         Security fallbacks
    /// ===============================

    // /**
    //  * @notice allow a user to withdraw its balance if ETH was sent
    //  */
    // function withdrawEthForUser() external {
    //     //TODO: require balance > 0
    //     uint256 amount = balanceOfEth[msg.sender];
    //     delete balanceOfEth[msg.sender];
    //     (bool success,) = msg.sender.call{value: amount}("");
    //     require(success);
    // }

    /**
     * @notice security function to allow marketplace to send NFT.
     */
    function unlockNFT(address contract_, uint256 tokenId, address to) external onlyOwner {
        ERC721(contract_).safeTransferFrom(address(this), to, tokenId);
    }

    /// ================================
    ///            VIEWS
    /// ================================

    /**
     * @notice get all informations of a sale order by calling its id
     * @param marketOfferId id of the sale
     */
    function getSaleOrder(uint256 marketOfferId) external view returns (SaleOrder memory) {
        return marketOffers[marketOfferId];
    }

    /**
     * @notice get all fees in ETH collected
     */
    function getEthFees() external view onlyOwner returns (uint256) {
        return _ethFees;
    }

    /**
     * @notice get all fees in WETH collected
     */
    function getWethFees() external view onlyOwner returns (uint256) {
        return _wethFees;
    }

    ///==================================
    ///           HOOKS
    ///==================================

    function _beforeTokenTransfer() internal {}

    function _afterTokenTransfer() internal {}
}

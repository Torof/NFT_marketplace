/// TODO: add security extension contract (NFT unlock, withdraw ETH, onlyEOA ...)
/// TODO: gas opti
/// TODO: notOwner() messages
/// CHECK: if offer expired , delete offer ?

/**
 *@author Torof
 *@title A custodial NFT MarketPlace
 *@notice This marketplace allows the listing and selling of {ERC721} and {ERC1155} Non Fungible & Semi Fungible Tokens.
 *@dev The marketplace MUST hold the NFT in custody. Offers follow a non custodial model using Wrapped Ethereum.
 *      Sender needs to have sufficiant WETH funds to submit offer.
 *      Showing the onGoing offers and not the expired offers must happen on the front-end.
 */

/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MarketplaceCustodial is
    ReentrancyGuard,
    IERC721Receiver,
    IERC1155Receiver,
    Ownable
{
    uint256 public marketOffersNonce = 1; /// sale id - all sales ongoing and closed
    uint256 private ethFees; /// All the fees gathered by the markeplace
    uint256 private wethFees;
    uint256 public marketPlaceFee; /// percentage of the fee. starts at 0, cannot be more than 10
    ERC20 public constant WETH = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    mapping(uint256 => SaleOrder) public marketOffers;
    mapping(address => uint256) public balanceOfEth;

    struct SaleOrder {
        uint256 price; /// price of the sale
        uint256 tokenId;
        address contractAddress; ///address of the NFT contract
        address seller; /// address that created the sale
        address buyer; /// address that bought the sale
        bytes4 standard; /// standard of the collection - bytes4 of {IERC721} interface OR {IERC1155} interface - only ERC721 and ERC1155 accepted
        bool closed; ///sale is on or finished
        Offer[] offers; /// an array of all the offers
    }

    struct Offer {
        address sender;
        uint offerPrice;
        uint duration;
        uint offerTime;
    }

    error offerClosed();

    error failedToSendEther();

    error notOwner(string);

    error notEnoughBalance();

    error standardNotRecognized();

    /**
     *@notice Emitted when a NFT is received
     */
    event NFTReceived(
        address operator,
        address from,
        uint256 tokenId,
        uint256 amount,
        bytes4 standard,
        bytes data
    );

    event BatchNFTReceived(
        address _operator,
        address _from,
        uint[] ids,
        uint[] values,
        string standard,
        bytes data
    );
    /**
     *@notice Emitted when a new market saleis created
     */
    event SaleCreated(
        uint256 offerId,
        address from,
        uint256 tokenId,
        address contractAddress,
        bytes4 standard,
        uint256 price
    );

    /**
     *@notice Emitted when a seller cancel its sale
     */
    event SaleCanceled(uint256 marketOfferId);

    /**
     *@notice Emitted when a sale is successfully concluded
     */
    event SaleSuccessful(
        uint marketOfferId,
        address seller,
        address buyer,
        uint price
    );

    /**
     *@notice Emitted when a new offer is made
     */
    event OfferSubmitted(
        uint256 marketOfferId,
        address offerer,
        uint256 offerPrice
    );

    /**
     *@notice Emitted when a bidder cancel its offer
     */
    event OfferCanceled(
        uint256 marketOfferId,
        address offererAddress,
        uint canceledOffer
    );

    event FeeModified(
        uint256 newFees
    );

    // constructor(address _WETH) {
    //     WETH = ERC20(_WETH);
    // }

    /// ==========================================
    ///    Receive & support interfaces
    /// ==========================================

    receive() external payable {
        ///TODO: verify sender is not contract, if not revert
        ///CHECK: change to WETH ?
        balanceOfEth[msg.sender] = msg.value;
    }

    fallback() external {
        revert("not allowed");
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public pure override returns (bool) {
        return
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @notice         MUST be implemented to be compatible with all ERC721 standards NFTs
     * @return bytes4  function {onERC721Received} selector
     * @param operator address allowed to transfer NFTs on owner's behalf
     * @param from     address the NFT comes from
     * @param tokenId  id of the NFT within its collection
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        if (msg.sender != address(this) && tx.origin == operator)
            revert("direct transfer not allowed"); //disallow direct transfers with safeTransferFrom()
        emit NFTReceived(
            operator,
            from,
            tokenId,
            1,
            type(IERC721).interfaceId,
            data
        );
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
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        if (msg.sender != address(this) && tx.origin == operator)
            revert("direct transfer not allowed"); //disallow direct transfers
        emit NFTReceived(
            operator,
            from,
            id,
            value,
            type(IERC1155).interfaceId,
            data
        );
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
        if (msg.sender != address(this) && tx.origin == operator)
            revert("direct transfer not allowed"); //disallow direct transfers
        emit BatchNFTReceived(operator, from, ids, values, "ERC1155", data);
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    /// =============================================
    ///       Marketplace functions
    /// =============================================

    /**
     *@notice      set the fees. CANNOT be negative or more than 10%
     *@param _newFees the fee the marketplace will receive from each sale
     */
    function setFees(uint256 _newFees) external onlyOwner {
        require(_newFees <= 10, "can't be more than 10%");
        marketPlaceFee = _newFees;
        emit FeeModified(_newFees);
    }

    /**
     * @notice withdraw all gains in ETH made from the sales fees all at once.
     */
    function withdrawEthFees() external payable onlyOwner {
        ethFees = 0;
        (bool sent, ) = msg.sender.call{value: ethFees}("");
        if (!sent) revert failedToSendEther();
    }

    /**
     * @notice withdraw all gains made in WETH from the sales fees all at once.
     */
    function withdrawWETHFees() external payable onlyOwner {
        wethFees = 0;
        bool sent = ERC20(WETH).transferFrom(
            address(this),
            msg.sender,
            wethFees
        );
        if (!sent) revert failedToSendEther();
    }

    /// ==========================================
    ///      Main sale
    /// ==========================================

    /**
     * @notice                 opens a new sale of a single NFT. Supports {ERC721} and {ERC1155}. Compatible with {ERC721A}
     * @param _contractAddress the address of the NFT's contract
     * @param _tokenId         id of the token within its collection
     * @param _price           price defined by the creator/seller
     *
     */
    function createSale(
        address _contractAddress,
        uint256 _tokenId,
        uint256 _price
    ) external nonReentrant {
        require(_price > 0, "price cannot be negative");
        bytes4 standard;

        if (
            ERC721(_contractAddress).supportsInterface(
                type(IERC721).interfaceId
            )
        ) {
            ERC721 collection = ERC721(_contractAddress); ///collection address

            if (collection.ownerOf(_tokenId) != msg.sender) revert notOwner(""); ///creator must own NFT

            standard = type(IERC721).interfaceId; ///NFT's standard

            _createSale(_contractAddress, msg.sender, _tokenId, _price, standard);

            collection.safeTransferFrom(msg.sender, address(this), _tokenId); ///Transfer NFT to marketplace contract for custody

        } else if (
            ERC1155(_contractAddress).supportsInterface(
                type(IERC1155).interfaceId
            )
        ) {
            ERC1155 collection = ERC1155(_contractAddress);
            if (collection.balanceOf(msg.sender, _tokenId) < 1)
                revert notOwner("");

                standard = type(IERC1155).interfaceId; /// NFT's standard
                _createSale(_contractAddress, msg.sender, _tokenId, _price, standard);

            collection.safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId,
                1,
                ""
            ); /// Transfer NFT to marketplace contract for custody

        } else revert standardNotRecognized();

    }

    /**
     * @notice               modify the sale's price
     * @param _marketOfferId index of the saleOrder
     * @param _newPrice      the new price of the sale
     */
    function modifySale(uint256 _marketOfferId, uint256 _newPrice) external {
        if (msg.sender != marketOffers[_marketOfferId].seller)
            revert notOwner("");
        marketOffers[_marketOfferId].price = _newPrice;
    }

    /**
     * @notice               cancel a sale.
     * @param _marketOfferId index of the saleOrder
     */
    function cancelSale(uint256 _marketOfferId) external nonReentrant {
        SaleOrder memory saleOrder = marketOffers[_marketOfferId];
        if (saleOrder.closed) revert offerClosed(); /// offer must still be ongoing to cancel
        if (msg.sender != saleOrder.seller) revert notOwner("caller is not owner");

        marketOffers[_marketOfferId].closed = true; /// sale is over

        if (saleOrder.standard == type(IERC721).interfaceId) {
            ERC721(saleOrder.contractAddress).safeTransferFrom(
                address(this),
                msg.sender,
                saleOrder.tokenId
            ); /// sale is canceled and erc721 NFt sent back to its owner
        } else if (saleOrder.standard == type(IERC1155).interfaceId) {
            ERC1155(saleOrder.contractAddress).safeTransferFrom(
                address(this),
                msg.sender,
                saleOrder.tokenId,
                1,
                ""
            ); /// sale is canceled and erc1155 NFT sent back to its owner
        } else revert standardNotRecognized();

        emit SaleCanceled(_marketOfferId);
    }

    //TODO: verify is not a contract
    //CHECK: use send or transfer over call ?
    /**
     *@notice               allows anyone to buy instantly a NFT at asked price.
     *@dev                  fees SHOULD be automatically soustracted
     *@param _marketOfferId index of the saleOrder
     * emits a {SaleSuccesful} event
     */
    function buySale(uint256 _marketOfferId) external payable nonReentrant {
        require(
            msg.value == marketOffers[_marketOfferId].price,
            "not the right amount"
        ); /// give the exact amount to buy

        if (marketOffers[_marketOfferId].closed) revert offerClosed();

        marketOffers[_marketOfferId].buyer = msg.sender; /// update buyer
        marketOffers[_marketOfferId].closed = true; /// sale is closed

        SaleOrder memory offer = marketOffers[_marketOfferId];

        /// Fees of the marketplace
        uint256 afterFees = msg.value - ((msg.value * marketPlaceFee) / 100);
        ethFees += ((msg.value * marketPlaceFee) / 100);

        if (
            ERC721(offer.contractAddress).supportsInterface(
                type(IERC721).interfaceId /// check if NFT is a erc721 standard NFT
            )
        )
            ERC721(offer.contractAddress).safeTransferFrom(
                address(this),
                msg.sender,
                offer.tokenId
            ); /// transfer NFT ERC721 to new owner
        else if (
            ERC1155(offer.contractAddress).supportsInterface(
                type(IERC1155).interfaceId /// check if NFT is a erc1155 standard NFT
            )
        )
            ERC1155(offer.contractAddress).safeTransferFrom(
                address(this),
                msg.sender,
                offer.tokenId,
                1,
                ""
            ); /// transfer NFT ERC1155 to new owner
        else revert standardNotRecognized();

        (bool sent2, ) = marketOffers[_marketOfferId].seller.call{
            value: afterFees
        }(""); /// send sale price to previous owner
        if (!sent2) revert failedToSendEther();

        emit SaleSuccessful(
            _marketOfferId,
            marketOffers[_marketOfferId].seller,
            msg.sender,
            marketOffers[_marketOfferId].price
        );
    }

    // =========================================
    //      Secondary offers
    // =========================================

    /**
     * @notice make an offer. Offer is made and sent in WETH.
     * @param _marketOfferId index of the saleOrder
     * @param _amount price of the offer
     * @param  _duration duration of the offer
     *
     * emits a {OfferSubmitted} event
     */
    function createOffer(
        uint256 _marketOfferId,
        uint _amount,
        uint _duration
    ) external nonReentrant {
        require(_amount > 0, "amount can't be zero");
        if (marketOffers[_marketOfferId].closed) revert offerClosed(); ///Only if offer is still ongoing
        require(
            WETH.allowance(msg.sender, address(this)) >= _amount,
            "not enough balance allowed"
        );

        //TODO: to remove after testing
        Offer memory temp; ///new offer price
        temp.sender = msg.sender; ///new caller
        temp.offerTime = block.timestamp;
        temp.offerPrice = _amount;
        temp.duration = _duration;
        marketOffers[_marketOfferId].offers.push(temp);
        emit OfferSubmitted(_marketOfferId, msg.sender, _amount);
    }


    //ALERT: unsafe erc20 safeTransfer and unsafe erc721 && erc1155 transfers
    /**
     * @notice               a third party made an offer below the asked price and seller accepts
     * @dev                  fees SHOULD be automatically substracted
     * @param _marketOfferId id of the sale
     *
     * Emits a {SaleSuccesful} event
     */
    function acceptOffer(
        uint256 _marketOfferId,
        uint _index //ALERT: order price and bought at price are different
    ) external nonReentrant {
        SaleOrder storage order = marketOffers[_marketOfferId];
        Offer memory offer = order.offers[_index];

        if (order.seller != msg.sender) revert notOwner("caller is not owner");
        require(!order.closed, "sale is closed"); /// owner of the token - sale
        require(_index < order.offers.length, "index out of bound");
        require(
            block.timestamp < offer.offerTime + offer.duration,
            "offer expired"
        );
        require(
            WETH.balanceOf(offer.sender) > offer.offerPrice,
            "WETH: not enough balance"
        );
        require(
            WETH.allowance(offer.sender, address(this)) >=
                order.offers[_index].offerPrice,
            "not enough allowance"
        );

        order.buyer = offer.sender; /// update buyer
        order.price = offer.offerPrice; /// update sell price
        order.closed = true; /// offer is now over

        /// Fees of the marketplace
        uint256 afterFees = offer.offerPrice -
            ((offer.offerPrice * marketPlaceFee) / 100);
        wethFees += (offer.offerPrice * marketPlaceFee) / 100;

        if (order.standard == type(IERC721).interfaceId)
            ERC721(order.contractAddress).safeTransferFrom(
                address(this),
                order.buyer,
                order.tokenId
            ); /// transfer NFT to new owner
        else if (order.standard == type(IERC1155).interfaceId)
            ERC1155(order.contractAddress).safeTransferFrom(
                address(this),
                msg.sender,
                order.tokenId,
                1,
                ""
            ); /// transfer NFT ERC1155 to new owner
        else revert standardNotRecognized();

        bool sent1 = ERC20(WETH).transferFrom(
            order.offers[_index].sender,
            msg.sender,
            afterFees
        );
        if (!sent1) revert failedToSendEther();

        bool sent2 = ERC20(WETH).transferFrom(
            order.offers[_index].sender,
            address(this),
            (offer.offerPrice * marketPlaceFee) / 100
        );
        if (!sent2) revert failedToSendEther();

        emit SaleSuccessful(
            _marketOfferId,
            order.seller,
            order.buyer,
            offer.offerPrice
        );
    }

    function modifyOffer() external {}

    /**
     * @notice               cancel an offer made.
     * @param _marketOfferId id of the sale
     *
     * Emits a {offerCanceled} event
     */
    function cancelOffer(uint256 _marketOfferId, uint _index) external {
        require(
            msg.sender == marketOffers[_marketOfferId].offers[_index].sender,
            "not the offerer"
        );

        marketOffers[_marketOfferId].offers[_index] = marketOffers[
            _marketOfferId
        ].offers[marketOffers[_marketOfferId].offers.length - 1];
        marketOffers[_marketOfferId].offers.pop();

        emit OfferCanceled(_marketOfferId, msg.sender, 0);
    }

    /// ================================
    ///    INTERNAL
    /// ================================

    function _createSale(
        address _contractAddress,
        address _seller,
        uint256 _tokenId,
        uint256 _price,
        bytes4 _standard
    ) internal {
        SaleOrder storage order = marketOffers[marketOffersNonce];

        order.contractAddress = _contractAddress; /// collection address
        order.seller = _seller; /// seller address , cannot be msg.sender since internal
        order.price = _price; ///sale price
        order.tokenId = _tokenId;
        order.standard = _standard; ///NFT's standard

        emit SaleCreated(
            marketOffersNonce, ///id of the new offer
            _seller, ///seller address
            _tokenId,
            _contractAddress,
            _standard,
            _price
        );
        marketOffersNonce++;
    }

    /// ===============================
    ///         Security fallbacks
    /// ===============================

    /**
     * @notice allow a user to withdraw its balance if ETH was sent
     */
    function withdrawEth() external {
        uint amount = balanceOfEth[msg.sender];
        delete balanceOfEth[msg.sender];
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success);
    }

    /**
     * @notice security function to allow marketplace to send NFT.
     */
    function unlockNFT(
        address _contract,
        uint _tokenId,
        address _to
    ) external onlyOwner {
        require(address(this) == ERC721(_contract).ownerOf(_tokenId), "contract is not owner");
        ERC721(_contract).safeTransferFrom(address(this), _to, _tokenId);
    }

    /// ================================
    ///       Getters
    /// ================================

    /**
     * @notice               get all informations of a sale order by calling its id
     * @param _marketOfferId id of the sale
     */
    function getSaleOrder(
        uint256 _marketOfferId
    ) external view returns (SaleOrder memory) {
        return marketOffers[_marketOfferId];
    }

    /**
     * @notice get all fees in ETH collected
     */
    function getEthFees() external view onlyOwner returns (uint) {
        return ethFees;
    }

    /**
     * @notice get all fees in WETH collected
     */
    function getWEthFees() external view onlyOwner returns (uint) {
        return wethFees;
    }
}

// Reentrancy: The contract doesn't seem to protect against reentrancy attacks in the buy function. It's important to prevent a malicious user from being able to re-enter the buy function before it has finished executing.

// Integer Overflow/Underflow: There are several places where integer overflow/underflow could occur. For example, in the _createSale function, the marketOffersNonce variable is incremented without checking if it has already reached its maximum value. This could result in an integer overflow. Similarly, in the buy function, the contract should check that the amount sent by the buyer is greater than or equal to the sale price, to avoid integer underflows.

// Lack of Access Controls: The unlockNFT function can be called by anyone, which could be a potential security issue if it's not intended to be publicly accessible.

// Lack of Input Validation: There's no input validation in the _hasBalance function, which could allow a malicious user to pass invalid inputs that could cause unexpected behavior in the function.

// Potential DoS Attack: The getSaleOrder function could be used to consume a large amount of gas, potentially resulting in a DoS attack if an attacker repeatedly calls this function with a large number.

// The _createSale function could potentially result in an unintended transfer of ownership of an NFT if the _seller address is not the owner of the NFT being sold. This can happen if the _seller address is not updated after an NFT transfer or if the _seller address is set to an arbitrary address that doesn't actually own the NFT. This can lead to unauthorized sales of NFTs.

// The onlyOwner modifier is used in some functions, but it is not defined in the contract. It is unclear who the owner is or how it is determined.

    // ///ALERT: for now only order of one ERC1155 token by one can be issued, but is several will need to count amounts;
    // function _hasBalance(
    //     address _contractAddres,
    //     uint _tokenId,
    //     address _creator
    // ) internal view returns (bool enough) {
    //     // uint[] memory ex_Orders;
    //     uint j;
    //     for (uint i = 1; i <= marketOffersNonce; ++i) {
    //         if (
    //             marketOffers[i].contractAddress == _contractAddres &&
    //             marketOffers[i].tokenId == _tokenId &&
    //             marketOffers[i].seller == msg.sender
    //         ) {
    //             j++;
    //         }
    //         ERC1155(_contractAddres).balanceOf(_creator, _tokenId) > j
    //             ? enough = true
    //             : enough = false;
    //     }
    // }

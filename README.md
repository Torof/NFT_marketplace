## Marketplace

**This repository contains 2 models of NFT marketplace; One follows a custodial model, and the other a non custodial model**

__Custodial Sale__
The creator of a sale sends its NFT to the marketplace for custody.
It ensures that the NFT cannot be sold or sent outside of the marketplace as long as the sale is not completed or cancelled

__support for erc721 and erc1155__
 for now only single transfers and sales of a single NFT are allowed.
 -Feature of batch sales of the same ERC1155 token id WILL be implemented
 -Feature of batch sales of different token ids COULD be implemented (erc721 & erc1155)

 __Non custodial bid system__
 -The marketplace allows users to make a bid at a different price than the sale price. 

 -WETH is used to allow non custodial transfer upon seller's acceptation of a bid.
 
 -The marketplace verifies that the bidder has enough funds and given enough allowance to the marketplace at the time of bidding

- **Custodial MarketPlace**

- **Non Custodial Marketplace**


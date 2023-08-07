# Marketplace

**This repository contains 2 models of NFT marketplace; One follows a custodial model, and the other a non custodial model**

### Support for erc721 and erc1155
 *For now* only **single transfers** and **single NFT sales** are allowed.

 - Feature of batch sales of the same ERC1155 token id WILL be implemented

 - Feature of batch sales of different token ids COULD be implemented (erc721 & erc1155)

 - SafeTransferFrom() is used for creation of new orders.

 ### Non custodial bid system

 - The marketplace allows users to make a bid at a different price than the sale price.**

 - WETH is used to allow non custodial transfer upon seller's acceptation of a bid.
 
 - The marketplace verifies that the bidder has enough funds and given enough allowance to the marketplace at the time of bidding**

 ### Fees

 - The marketplace can set a fee in percentage of a sale. Cannot be more than 10%

 ### Royalties

 - ***to be implemented soon***

 ## Custodial MarketPlace

 #### Custodial Sale

The **creator** of a sale *sends its NFT to the marketplace for* ***custody***.
It ensures that the NFT cannot be sold or sent outside of the marketplace as long as the sale is not completed or cancelled.

- Implement IERC721Receiver and IERC1155Receiver to allow receiving NFTs for custody.

- The seller MUST send its NFT to the marketplace to create a sale order

- If the seller cancels the sale, the NFT is sent back to him.

- If an external user buys the sale, the NFT is sent from the marketplace contract directly to the buyer. 

 ## Non Custodial Marketplace


 ------------------------------------------------------------------------

 # Download, Install & Test

 ### Download with git

 ```
 git clone https://github.com/Torof/marketplace_foundry.git
 
 ```

 ### Foundry unit test

 ```
 forge test -vv
 ```

 ### Foundry test coverage

 ```
 forge coverage
 ```

 ### Slither

```
slither .
```







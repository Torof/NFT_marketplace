// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract NFT1155 is ERC1155Supply {
    constructor(uint256 _amount) ERC1155("https://ipfs.io/ipfs/") {
        _mint(msg.sender, 1, _amount, "");
    }

    function mint(uint256 id, uint256 amount) external {
        _mint(msg.sender, id, amount, "");
    }
}

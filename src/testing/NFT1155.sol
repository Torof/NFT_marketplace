// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract NFT1155 is ERC1155Supply{

uint public constant POTIONS = 1;
uint public constant SWORDS = 2;
uint public constant SHIELD = 3;
uint public constant BOOTS = 4;
uint public constant HELMET = 5;

constructor(uint256 _amount) ERC1155("https://ipfs.io/ipfs/") {
    _mint(msg.sender, 1, _amount, "potions");
}

function mint(uint _id, uint _amount, string memory _name) external {
    _mint(msg.sender, _id, _amount, bytes(_name));
}


}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ServiceNFT_A is ERC721URIStorage, Ownable {
    uint256 private _currentTokenId = 0;

    constructor(string memory _name, string memory _symbol) 
        ERC721(_name, _symbol) 
        Ownable(msg.sender)
    {}

    function mintTo(address _recipient, string memory _uri) public onlyOwner returns (uint256) {
        uint256 newTokenId = _currentTokenId++;
        _mint(_recipient, newTokenId);
        _setTokenURI(newTokenId, _uri);

        return newTokenId;
    }
}
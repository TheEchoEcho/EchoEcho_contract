// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IServiceNFT_A.sol";

contract ServiceNFT_A is IServiceNFT_A, ERC721URIStorage, Ownable(msg.sender) {
    uint256 private _currentTokenId = 0;

    constructor(string memory _name, string memory _symbol) 
        ERC721(_name, _symbol) 
    {}

    function mint_A(address _recipient, string memory _uri) public returns (uint256) {
        uint256 newTokenId = _currentTokenId++;
        _mint(_recipient, newTokenId);
        _setTokenURI(newTokenId, _uri);

        return newTokenId;
    }
}
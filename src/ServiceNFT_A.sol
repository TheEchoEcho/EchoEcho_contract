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

        emit Minted(_recipient, newTokenId);
        return newTokenId;
    }

    // override transferFrom to disable transfer
    function transferFrom(address, address, uint256) public pure override(ERC721, IERC721) {
        revert("SoulboundToken: transferFrom disabled");
    }

    // override safeTransferFrom to disable transfer
    function safeTransferFrom(address, address, uint256, bytes memory) public pure override(ERC721, IERC721) {
        revert("SoulboundToken: safeTransferFrom(data) disabled");
    }
}
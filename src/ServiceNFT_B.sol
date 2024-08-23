//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ServiceNFT_B is ERC721Enumerable, Ownable(msg.sender) {
    string private BASE_URI;

    uint256 private nextTokenId = 0;
    constructor(string memory _name, string memory _symbol, string memory base_uri) ERC721(_name, _symbol) {
        BASE_URI = base_uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return BASE_URI;
    }

    function Mint_B(uint256 _amount) external onlyOwner {
        require(_amount <= 5, "You call mint up to 5 tokens at once");
        uint256 nextTokenId_ = nextTokenId;

        for (uint256 i = 0; i < _amount; i++) {
            _safeMint(msg.sender, nextTokenId_);
            nextTokenId_++;
        }

        nextTokenId = nextTokenId_;
    }
}
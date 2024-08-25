// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
interface IServiceNFT_A is IERC721 {
    function mint_A(address _recipient, string memory _uri) external returns (uint256);
}
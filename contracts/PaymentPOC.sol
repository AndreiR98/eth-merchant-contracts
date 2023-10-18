// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PaymentWithERC721 is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(uint256 => string) public receipts;
    mapping(uint256 => bytes32) public uniqueHashes;

    event PaymentReceived(address indexed payer, uint256 amount, uint256 tokenId, bytes32 uniqueHash);

    constructor() ERC721("PaymentWithERC721", "PW721") {}

    function buyNFT(string memory uri, string memory receiptJson, bytes32 uniqueHash) public payable {
        require(msg.value > 0, "Payment required to mint NFT");

        // Increment the token ID
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        // Mint the NFT to the sender
        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, uri);

        // Store the receipt JSON string and uniqueHash
        receipts[newTokenId] = receiptJson;
        uniqueHashes[newTokenId] = uniqueHash;

        emit PaymentReceived(msg.sender, msg.value, newTokenId, uniqueHash);
    }

    function getReceipt(uint256 tokenId) public view returns (string memory) {
        return receipts[tokenId];
    }

    function getUniqueHash(uint256 tokenId) public view returns (bytes32) {
        return uniqueHashes[tokenId];
    }
}
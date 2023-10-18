// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/*
Receipt NFT this token is mint when a successfull ayment to the contract as proof
 */
contract Receipt is Context{
    //Token data
    struct ReceiptDetails {
        bytes32 uniqueHash;
        string metadataJSON;
        address client;
    }

    //State variables
    mapping(uint256 => ReceiptDetails) public receiptDetails;
    mapping(uint256 => address) public tokenOwners;
    mapping(address => uint256[]) public tokensOfOwner;
    uint256 public nextTokenId;

    //Events
    event Minted(address indexed owner, uint256 indexed tokenId, string metadataJSON);
    event DebugMint(bytes32 uniqueHash, string metadataJSON);

    function _mint(bytes32 _uniqueHash, string memory _metadataJSON) internal virtual{

        ReceiptDetails memory receiptDetailsDTO = ReceiptDetails({uniqueHash: _uniqueHash, 
        metadataJSON: _metadataJSON, client:msg.sender});

        receiptDetails[nextTokenId] = receiptDetailsDTO;
        tokenOwners[nextTokenId] = msg.sender;
        tokensOfOwner[msg.sender].push(nextTokenId);

        emit Minted(msg.sender, nextTokenId, _metadataJSON);
        //emit DebugMint(_uniqueHash, _metadataJSON);

        nextTokenId++;
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

//import "./Receipt.sol";

interface IPaymentSplitter {
    struct Details {
        uint256 amount;
        bytes32 uniqueHash;
        string data;
        bool processed;
        uint256 splitsTotal;
        uint256 splitsProcessed;
    }
    // Events
    event Deposited(address indexed from, uint256 value, bytes32 uniqueHash, string data);
    event OwnerAdded(address indexed newOwner);
    event OwnerRemoved(address indexed removedOwner);

    // Function signatures
    function addOwner(address newOwner) external;
    function removeOwner(address ownerToRemove) external;
    function processPayment(bytes32 _uniqueHash, string memory _data) external payable;
    function processSplit(address _to, address _from, bytes32 _uniqueHash, string memory _dataJSON, uint256 _amount) external payable;
    function getDetail(address _user, bytes32 _uniqueHash) external view returns (uint256, bytes32, string memory);
    function getAllDetailsForUser(address _user) external view returns (Details[] memory);
    function getBalance(address account) external view returns (uint256);
}

/**
Create a receipt NFT for the client
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

        nextTokenId++;
    }
}

contract Confirmation is Context {
    struct ConfirmationDetails {
        bytes32 uniqueHash;
        string splitDetails;
        address client;
        address owner;
        uint256 amount;
    }

    //State variables
    mapping(uint256 => ConfirmationDetails) public confirmationDetails;
    mapping(uint256 => address) public confirmationOwners;
    mapping(address => uint256[]) public confirmationsOfOwner;
    uint256 public nextID;

    //Events
    event SplitConfirmed(address indexed owner, address indexed client, uint256 indexed tokenId, string metadataJSON);

    function _confirmSplit(address _to, address _from, bytes32 _uniqueHash, string memory _metadataJSON, uint256 _amount) internal virtual{

        ConfirmationDetails memory confirmDetailsDTO = ConfirmationDetails({
            uniqueHash: _uniqueHash, 
            splitDetails: _metadataJSON, 
            client:_from,
            owner:_to,
            amount: _amount
        });

        confirmationDetails[nextID] = confirmDetailsDTO;
        confirmationOwners[nextID] = _to;
        confirmationsOfOwner[_to].push(nextID);

        emit SplitConfirmed(_to,  _from, nextID, _metadataJSON);

        nextID++;
    }
}

contract PaymentSplitter is IPaymentSplitter, Receipt, Confirmation, Ownable{
   //address private owner;
    address private _owner;
    

    mapping(address => bool) public isOwner;
    mapping(address => uint256) public deposits;
    mapping(address => mapping(bytes32 => Details)) public userDetails;
    mapping(address => bytes32[]) public userUniqueHashes;

    constructor() {
        _owner = msg.sender;
        isOwner[msg.sender] = true;
        emit OwnerAdded(msg.sender);
    }

    function addOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid address!");
        require(!isOwner[newOwner], "Address is already an owner!");
        isOwner[newOwner] = true;

        emit OwnerAdded(newOwner);
    }

     function removeOwner(address ownerToRemove) public onlyOwner {
        require(ownerToRemove != address(0), "Invalid address!");
        require(isOwner[ownerToRemove], "Address is not an owner");
        isOwner[ownerToRemove] = false;
        emit OwnerRemoved(ownerToRemove);
    }

    function processPayment(bytes32 _uniqueHash, string memory _dataJSON) public payable {
        require(msg.value > 0, "Must send a positive amount!");
        require(userDetails[msg.sender][_uniqueHash].uniqueHash == 0, "Hash must be unique!");

        deposits[msg.sender] += msg.value;

        uint256 tokenId = uint256(_uniqueHash);

        Details memory newDetail = Details({
            amount: msg.value,
            uniqueHash: _uniqueHash,
            data: _dataJSON,
            processed: false,
            splitsTotal: 0,
            splitsProcessed: 0
        });

        userDetails[msg.sender][_uniqueHash] = newDetail;
        userUniqueHashes[msg.sender].push(_uniqueHash);

    
        emit Deposited(msg.sender, msg.value, _uniqueHash, _dataJSON);

        _mint(_uniqueHash, _dataJSON);
    }

    function processSplit(address _to, address _from, bytes32 _uniqueHash, string memory _dataJSON, uint256 _amount) public payable {
        //Retrieve hash details
        Details memory retrievedDetail = userDetails[_from][_uniqueHash];

        uint256 _splitsProcessed = retrievedDetail.splitsProcessed++;

        bool _processedFlag = false;

        // if(_splitsProcessed == retrievedDetail.splitsProcessed) {
        //     _processedFlag = true;
        // }

        // Create a new Detail
        Details memory newDetail = Details({
            amount: retrievedDetail.amount - _amount,
            uniqueHash: _uniqueHash,
            data: _dataJSON,
            processed: _processedFlag,
            splitsProcessed: _splitsProcessed,
            splitsTotal: retrievedDetail.splitsTotal
        });

        userDetails[_from][_uniqueHash] = newDetail;
        deposits[_from] -= _amount;

        address payable to = payable(_to);
        to.transfer(_amount); 

        _confirmSplit(_to, _from, _uniqueHash, _dataJSON, _amount);
    }

    function getDetail(address _user, bytes32 _uniqueHash) public view returns(uint256, bytes32, string memory) {
        Details memory detail = userDetails[_user][_uniqueHash];
        require(detail.uniqueHash != 0, "Detail not found!");
        return (detail.amount, detail.uniqueHash, detail.data);
    }

    function getAllDetailsForUser(address _user) public view returns (Details[] memory) {
        uint256 length = userUniqueHashes[_user].length;
        Details[] memory detailsList = new Details[](length);

        for (uint256 i = 0; i < length; i++) {
            bytes32 uniqueHash = userUniqueHashes[_user][i];
            Details memory detail = userDetails[_user][uniqueHash];
            detailsList[i] = detail;
        }

        return detailsList;
    }

    function getBalance(address account) public view returns (uint256) {
        return deposits[account];
    }
}


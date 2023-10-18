// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";

interface ITransactionSplitter {
    event Deposited(address indexed from, uint256 value, string uniqueHash, string data);
}

contract ClientSplit is Context {}

/**
NFT for merchant to confirm the split
*/
contract MerchantSplit is Context {}

interface IStructure {
    struct Payment {
        string uniqueHash;
        uint256 amount;
        bool processed;
        uint256 totalSplits;
        uint256 processedSplits;
        string paymentDetails;
    }

    struct clientDetails {
        address _address;
        uint256 balance;
        mapping(string => Payment) payments;
    }
}
/**
Split and process the payment
*/
contract TransactionSplitter is ITransactionSplitter, IStructure {
    address private _owner;

    mapping(address => clientDetails) private clients;

    constructor() {
        _owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == _owner, "Only the contract owner can call this function");
        _;
    }

    /**
    Process payment
    */
    function processPayment(string memory _uniqueHash, string memory _dataJSON, uint256 _totalSplits) public payable {
        require(msg.value > 0, "Must send a positive amount!");

        bytes memory checkHash = bytes(clients[msg.sender].payments[_uniqueHash].uniqueHash);
        require(checkHash.length == 0, "Hash must be unique!");

        Payment memory payment = Payment({
            uniqueHash: _uniqueHash,
            amount: msg.value,
            processed: false,
            totalSplits: _totalSplits,
            processedSplits: 0,
            paymentDetails: _dataJSON
        });

        //Update client balance
        clients[msg.sender].balance = clients[msg.sender].balance + msg.value;

        clients[msg.sender].payments[_uniqueHash] = payment;

        emit Deposited();

        _createPaymentProof();
        
    }

    function processSplit() public onlyOwner {}

    function checkClientAccount() public {}

    function checkPaymentDetails() public {}

    function checkSplitProof() private {}

    function checkMerchantSplits() private {}
}
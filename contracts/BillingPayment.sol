// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

struct Payment {
    string uniquePaymentId;
    uint256 amount;
    string timeStamp;
    string billUniqueId;
    address clientAddress;
}

struct BillModel {
    string billUniqueId;
    uint256 billAmount;
    uint256 txAmount;
    uint256 tipAmount;
    uint256 revenueAmount;
    uint256 payedAmount;
    bool processed;
    string processDate;
    string[] payments;
    string billTimeStamp;
    address payable merchantAddress;
    address payable processorAddress;
    string metaData;
}

struct BillDetails {
    string billUniqueId;
    uint256 billAmount;
    uint256 txAmount;
    uint256 tipAmount;
    string billTimeStamp;
    string metaData;
}

struct ReceiptModel {
    string uniquePaymentId;
    string timeStamp;
    uint256 billAmount;
    string billUniqueId;
    uint256 amount;
}

struct BillingDTO {
    string uniquePaymentId;
    string timeStamp;
    uint256 billAmount;
    string billUniqueId;
    uint256 amount;
    uint256 tipAmount;
    string billTimeStamp;
    string metaData;
}

/**
Bill interface and structure
*/
interface IBillingPayment {
    /**
    Events
    */
    /**
    * Emit a success or error when generating a new bill
    */
    event BillGenerated(string _billUniqueId, BillModel _bill);
    event BillProcessed(string _billUniqueId, BillModel _bill);
    event PaymentReceived(string _paymentUniqueId, Payment _payment);
    //event ReceiptGenerated(string _receiptUniqueId, Receipt _receipt);

    /**
    *Contract functions
    */
    //Payment processor creates bill for client
    //Can create bill enriched with process payment taxes
    function createBill(
        string memory _billUniqueId,
        uint256 _billAmount, 
        uint256 _txAmount, 
        uint256 _tipAmount,
        uint256 _revenueAmount, 
        string memory _processDate, 
        string memory _billTimeStamp, 
        address payable _merchantAddress,
        address payable processorAddress,
        string memory _metaData) external;

    //All addresses can pay if the bill is non processed or exists than execute payment otherwise revert
    function pay(
        string memory _billUniqueId, 
        string memory _uniquePaymentId,
        uint256 _amount,
        uint256 _splitNumber,
        string memory _splitType,
        string memory _timeStamp) external payable;

    //Get all receipts for specific address
    function getReceiptsPerAddress(address _address) external view returns (BillingDTO[] memory);

    function getBillsForMerchant(address _merchantAddress) external view returns (BillModel[] memory);

    function getBillDetails(string memory _billUniqueId) external view returns (BillDetails memory);
}

/**
Main contract functionalities such as pay, createBill, checkBills, checkReceipts
*/
contract BillingPayment is IBillingPayment, Ownable, ReentrancyGuard {
    mapping(string => Payment) private paymentsStorage;
    mapping(string => BillModel) private billsStorage;
    mapping(address => ReceiptModel[]) private receiptsStorage;

    mapping(address => string[]) private merchantBillsStorage;

    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

   
    function createBill(
        string memory _billUniqueId,
        uint256 _billAmount, 
        uint256 _txAmount, 
        uint256 _tipAmount,
        uint256 _revenueAmount,
        string memory _processDate, 
        string memory _billTimeStamp, 
        address payable _merchantAddress,
        address payable _processorAddress,
        string memory _metaData) external override onlyOwner {

            BillModel memory newBill = BillModel({
            billUniqueId: _billUniqueId,
            billAmount: _billAmount,
            txAmount: _txAmount,
            tipAmount: _tipAmount,
            revenueAmount: _revenueAmount,
            payedAmount: 0,
            processed: false,
            processDate: _processDate,
            payments: new string[](0),
            billTimeStamp: _billTimeStamp,
            merchantAddress: _merchantAddress,
            processorAddress: _processorAddress,
            metaData: _metaData
        });

        //Add the bill to the storage
        billsStorage[_billUniqueId] = newBill;

        //Add bill unique id to merchant address
        merchantBillsStorage[_merchantAddress].push(_billUniqueId);

        //Broadcast bill
        emit BillGenerated(_billUniqueId, newBill);
        }

    function pay(
        string memory _billUniqueId, 
        string memory _uniquePaymentId,
        uint256 _amount,
        uint256 _splitNumber,
        string memory _splitType,
        string memory _timeStamp) external payable {
            //Retrieve the bill from the storage
            // Retrieve the bill from storage
            BillModel storage bill = billsStorage[_billUniqueId];

            require(msg.value > 0, "Payment should be greater than 0");
            require(bill.payedAmount < bill.billAmount, "Bill is already fully paid");
            require(bill.payedAmount + msg.value <= bill.billAmount, "Payment exceeds bill amount");

            // Check if payment ID already exists in the array
            bool idExists = false;
            for (uint256 i = 0; i < bill.payments.length; i++) {
                if (keccak256(abi.encodePacked(bill.payments[i])) == keccak256(abi.encodePacked(_uniquePaymentId))) {
                    idExists = true;
                    break;
                }
            }
            require(!idExists, "Payment ID already used");

            bill.payedAmount += msg.value;
            bill.payments.push(_uniquePaymentId);

            Payment memory payment = Payment({
                uniquePaymentId: _uniquePaymentId,
                amount: _amount,
                timeStamp: _timeStamp,
                billUniqueId: _billUniqueId,
                clientAddress: msg.sender
            });

            paymentsStorage[_uniquePaymentId] = payment;

            ReceiptModel memory receipt = ReceiptModel({
                uniquePaymentId: _uniquePaymentId,
                timeStamp: _timeStamp,
                billAmount: bill.billAmount,
                billUniqueId: _billUniqueId,
                amount: _amount
            });

            receiptsStorage[msg.sender].push(receipt);

            emit PaymentReceived(_uniquePaymentId, payment);

            if(bill.payedAmount == bill.billAmount) {
                bill.processed = true;

                emit BillProcessed(_billUniqueId, bill);

                bill.merchantAddress.transfer(bill.revenueAmount);
                bill.processorAddress.transfer(bill.txAmount);
            }
        }


    /**
    *Return the all bills for a specific merchant address
    */
    function getBillsForMerchant(address _merchantAddress) external view returns (BillModel[] memory) {
        string[] memory billsIds = merchantBillsStorage[_merchantAddress];
        BillModel[] memory result = new BillModel[](billsIds.length);

        for(uint256 i = 0; i < billsIds.length; i++) {
            result[i] = billsStorage[billsIds[i]];
        }

        return result;
    }

    /**
    *Return payment details for each payment
    */
    function getPaymentDetails(string memory _paymentUniqueId) external view returns (Payment memory) {
        Payment storage payment = paymentsStorage[_paymentUniqueId];
        return payment;
    }

    /**
    *Return the missing amount from the bill billAmount - payedAmount
    */
    function getMissingAmount(string memory _billUniqueId) external view returns (uint256) {
        BillModel storage bill = billsStorage[_billUniqueId];
        require(bytes(bill.billUniqueId).length > 0, "Bill does not exist");
        return bill.billAmount - bill.payedAmount;
    }

    function getBillDetails(string memory _billUniqueId) external view returns (BillDetails memory) {
        BillModel storage bill = billsStorage[_billUniqueId];

        require(bytes(bill.billUniqueId).length > 0, "Bill does not exist");

        BillDetails memory details;
        details.billUniqueId = _billUniqueId;
        details.billAmount = bill.billAmount;
        details.txAmount = bill.txAmount;
        details.tipAmount = bill.tipAmount;
        details.billTimeStamp = bill.billTimeStamp;
        details.metaData = bill.metaData;
        
        return details;
    }

    function getReceiptsPerAddress(address _address) external view returns (BillingDTO[] memory) {
        ReceiptModel[] storage receipts = receiptsStorage[_address];
        BillingDTO[] memory billingDTOs = new BillingDTO[](receipts.length);

        for(uint256 i = 0; i < receipts.length; i++) {
            BillModel storage bill = billsStorage[receipts[i].billUniqueId];
            require(bytes(bill.billUniqueId).length > 0, "Bill does not exist");

            BillingDTO memory dto = BillingDTO({
                uniquePaymentId: receipts[i].uniquePaymentId,
                timeStamp: receipts[i].timeStamp,
                billAmount: bill.billAmount,
                billUniqueId: bill.billUniqueId,
                amount: receipts[i].amount,
                tipAmount: bill.tipAmount,
                billTimeStamp: bill.billTimeStamp,
                metaData: bill.metaData
            });

            billingDTOs[i] = dto;
        }

        return billingDTOs;
    }
}


/**
Receipt token
*/
//contract Receipt is IBillingPayment, Ownable, Context {}

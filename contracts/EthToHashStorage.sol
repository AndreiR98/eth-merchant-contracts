// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract EthToHashStorage {
    // Mapping to store ETH amount against transaction hash
    mapping(bytes32 => uint256) public hashToAmount;
    
    // Event to log transactions
    event AmountStored(bytes32 indexed txHash, uint256 amount);
    
    // Function to send ETH to contract
    function sendEth() public payable {
        // Ensure some ETH is sent
        require(msg.value > 0, "No ETH sent.");
        
        // Compute a hash based on transaction details (this hash is not exactly the transaction hash but works for demonstration)
        bytes32 txHash = keccak256(abi.encodePacked(msg.sender, msg.value, block.number));
        
        // Store the ETH amount against the hash
        hashToAmount[txHash] = msg.value;
        
        // Emit event
        emit AmountStored(txHash, msg.value);
    }
    
    // Function to check stored amount for a particular hash (mostly for demonstration, since the mapping is public)
    function checkStoredAmount(bytes32 _txHash) public view returns (uint256) {
        return hashToAmount[_txHash];
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ContractAccount.sol";

/**
 * @title ContractAccountFactory
 * @dev This contract allows the deployment of ContractAccount instances and ensures that each user can only deploy one ContractAccount.
 */
contract ContractAccountFactory {
    // Mapping from user address to deployed ContractAccount address
    mapping(address => address) public deployedContracts;
    
    // Event emitted when a ContractAccount is created
    event ContractAccountCreated(address indexed owner, address contractAccount);

    // Error thrown if user tries to create more than one ContractAccount
    error AccountAlreadyExists(address owner, address contractAccount);

    /**
     * @notice Creates a new ContractAccount if the user does not have one already.
     */
    function createContractAccount() external {
        address owner = msg.sender;

        // Check if the user already has a deployed ContractAccount
        if (deployedContracts[owner] != address(0)) {
            revert AccountAlreadyExists(owner, deployedContracts[owner]);
        }

        // Deploy new ContractAccount and set the owner
        ContractAccount newAccount = new ContractAccount(owner);
        
        // Store the deployed contract address against the owner
        deployedContracts[owner] = address(newAccount);

        // Emit an event for the contract creation
        emit ContractAccountCreated(owner, address(newAccount));
    }

    /**
     * @notice Returns the address of the ContractAccount associated with the sender.
     * @return The address of the sender's ContractAccount.
     */
    function getDeployedContract() external view returns (address) {
        return deployedContracts[msg.sender];
    }
}
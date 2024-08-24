// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Vault-v6.sol";

contract VaultFactory {
    mapping(address => address) public heirToVault;
    mapping(address => address) public predecessorToVault;
    event VaultCreated(address indexed vault, address[] owners);

    Vault_v6[] public vaults;

    function createVault(address[] memory _owners, address _predecessor) public returns (address) {
        Vault_v6 newVault = new Vault_v6(_owners, _predecessor);
        vaults.push(newVault);
        
        emit VaultCreated(address(newVault), _owners);
        for (uint i = 0; i < _owners.length; i++) {
            heirToVault[_owners[i]] = address(newVault);
        }
        predecessorToVault[msg.sender] = address(newVault);
        return address(newVault);
    }

    function getVaults() public view returns (Vault_v6[] memory) {
        return vaults;
    }

    function getVaultCount() public view returns (uint) {
        return vaults.length;
    }


    // function userAdjustOwner(address _oldOwner, address _newOwner) public {
    //     address vaultAddress = ownedContracts[msg.sender];
    //     Vault_v2 vault = Vault_v2(vaultAddress);
    //     vault.adjustOwner(_oldOwner, _newOwner);
    // }
}
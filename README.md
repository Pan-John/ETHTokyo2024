# ETHTokyo2024
### TL;DR
We are building an inheritance management project to help secure and distribute assets.

## Project Abstraction
<img width="800" alt="截圖 2024-08-25 07 21 20" src="https://github.com/user-attachments/assets/bf2d7417-7999-40ba-8396-620494dd7aae">

 Our system consists of two smart contract accounts:

`Predecessor Contract Account (Predecessor CA)` : For the asset owner

`Vault Contract Account (Vault)` : For the heirs

Through a mechanism, we can transfer assets from the Predecessor CA to the Vault. The distribution of assets to heirs then depends on two scenarios:

- If the predecessor has made a will: The assets are distributed according to the predetermined will.
- If no will exists: The heirs must reach a consensus on how to distribute the assets among themselves.

This system ensures a transparent and secure way to manage inheritance, respecting the wishes of the predecessor while also allowing for flexibility when necessary.

## About the mechanism
<img width="800" alt="截圖 2024-08-25 08 14 49" src="https://github.com/user-attachments/assets/eb70af04-2eec-4506-be4d-09437ba8da8c">

The diagram shows a timeline representing the activity of the Predecessor CA.

- `Last Activity` : This indicates the time of the Predecessor's last recorded action.
- `T` : This marks the moment when the Heir submits a reques, indicateing that the Heir has submitted an inheritance claim at this point.
- `T+timeset` : This represents the point at which assets can be withdrawn. If the Predecessor didn't have any new activity to during the waiting period, the Heir can withdraw the assets.

The purpose of this mechanism is to allow Heirs to access assets after a certain waiting period, once it's confirmed that the Predecessor can no longer operate the account (possibly due to death). This waiting period likely serves to ensure the system's security and accuracy, providing sufficient time to verify the Predecessor's status and the Heir's identity.

## Other features we may like to add
### - About monitoring the predecessor's activity
- Rather then only monitoring Predecessor CA, keeping track of some other account the predecessor mainly uses may be a more realistic implementation.
- Moreover, expand DID method (e.g. predecessor choose to monitor some social account activity like twitter ) or using oracle to get the death certificate may improve the accuracy to check the predecessor's death.

### - ENS
- using ENS for the heirs' address is a good idea, this allows heirs to use easily memorable names instead of complex Ethereum addresses, significantly improving accessibility and user experience.

### - Other application usecase
- In addition to transfer the asset to heirs' wallet once and for all, can implement a  

## How to Use? 
During the hackathon we were only able to implement the smart contract part without a workable front/backend integration project, you can still see our progress on the integration [here](https://github.com/tjjd4/hackathon_tokyo), let me introduce how do you operate it on the blockchain explorer:

0. Prepare at least 3 account, account1 act as Predecessor and account2,3 act as Heirs.
1. connect account1, deploy Predecessor CA from the ContractAccountFactory, simply call the first function `createContractAccount`.
2. connect account1, deploy Vault from the VaultFactory, make sure to input the owner[] and the Predecessor CA address you deployed in the first step.
3. On Predecessor CA, account1 as the Predecessor set `nominee` to the Vault address you deployed in the second step and set `timeset`. For testing, you can try 100. 
   - (optional: account1 as a Predecessor can also make a will using `makeAWill()` on Vault, make sure to input all the Heirs address and the portion you want to set)
4. On Vault, account2 and account3 as the Heir can use `callPredecessorCA()` and input 1 to issue a request (calling `requestInActiveAccount()` on Predecessor CA), after 100 sec (let's assume the predecessor has really passed away), input 2 to withdraw asset (calling `withdrawAllToNominee()` on Predecessor CA )
5. Once the assets is transfered to the Vault,
   - if the Predecessor had made a will, Heirs could only call `withdrawWillPortions()` on the Vault and get the portion of asset is decided by the will
   - if there's no will, Heirs can discuss how they want to split the asset. Once they have a consensus, they can call `submitConsensus()` with input and call `confirmTransaction()`

## deployed & verified addresses
### Sepolia
[VaultFactory](https://sepolia.etherscan.io/address/0x33c2a24Db6e82C0eDEfE0dE8Eb0798187dC12381#code)

[ContractAccountFactory](https://sepolia.etherscan.io/address/0x38006Af1E6cF18A9CbeCcC998c74d8F7cEE3CDA8#code)

### Scroll Sepolia
[VaultFactory](https://sepolia.scrollscan.com/address/0xaB2907Fe390e6D1E733c19E3Fcd5A7F5E2d014aD#code)

[ContractAccountFactory](https://sepolia.scrollscan.com/address/0x8aef521Bd442DE59f795458046da820942265595#code)

### Linea Sepolia
[VaultFactory](https://sepolia.lineascan.build/address/address/0x7954c3a1ee7f61F5301457F3F832F3d152DC8fe5#code)

[ContractAccountFactory]()

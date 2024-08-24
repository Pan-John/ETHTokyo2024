// SPDX-License-Identifier: MIT
// v2 added batch withdrawal and signer adjustment
// v3 added call UserAccountWithDeadman.requestInactiveAccount and withdraw
// v4 added:
//  i. can only have one pending tx a time
//  ii. adjust requestInactiveAccount and withdrawAllToNominee to let confirmations be set to 2 and execute directly
// v5 added:
//  i. confirm, execute the latest transaction directly, doesn't require inputting the txIndex
//  ii. User set predecessor's address at deploy, also requestInactiveAccount withdrawAllToNominee no longer needs input predecessor's address
//  iii. numConfirmationsRequired is set to the number of signers (in constructor)
// v6 added:
//  i. adjust name
//  ii. User can set the portion (like a will), once is set, the signer can onlu withdraw the portion, and can't submit a batch withdrawal
//  iii. get who has/n't signed the tx -> isConfirmedList

pragma solidity ^0.8.24;

contract Vault_v6 {
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed signer,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed signer, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed signer, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed signer, uint256 indexed txIndex);
    event SubmitConsensus(
        address indexed signer,
        uint256 indexed txIndex,
        address[] recipients,
        uint256[] portions
    );
    event SignerAdjusted(address indexed oldSigner, address indexed newSigner);    

    address[] public signers;
    address public predecessorCA;
    address[] internal willSeq;
    mapping(address => bool) public isSigner;
    //mapping(address => uint256) public willPortions;
    uint256[] willPortions;
    uint256 public numConfirmationsRequired;
    bool public predecessorMakeAWill; 
    bool public alreadyWithdrawnWill;
    

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
        address[] recipients;
        uint256[] portions;
        bool isBatchWithdrawal;
    }

    // mapping from tx index => signer => bool
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;

    modifier onlySigner() {
        require(isSigner[msg.sender], "not signer");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    modifier onlyPredecessorCA() { // for adjust signer function
        require(msg.sender == predecessorCA, "only predecessorCA can call this function");
        _;
    }


    // input a list of signers and the number of confirmations required to execute a transaction to create vault
    constructor(address[] memory _signers, address _predecessorCA) {
        require(_signers.length > 0, "signers required");

        for (uint i = 0; i < _signers.length; i++) {
            address signer = _signers[i];

            require(signer != address(0), "invalid signer");
            require(!isSigner[signer], "signer not unique");

            isSigner[signer] = true;
            signers.push(signer);
        }

        numConfirmationsRequired = _signers.length;
        predecessorCA = _predecessorCA;
        predecessorMakeAWill = false;
        alreadyWithdrawnWill = false;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
    
    function adjustSigner(address _from, address _to) public onlyPredecessorCA  {
        require(_from != address(0) && _to != address(0), "invalid address");
        require(isSigner[_from], "from address is not an signer");
        require(!isSigner[_to], "to address is already an signer");

        isSigner[_from] = false;
        isSigner[_to] = true;

        for (uint i = 0; i < signers.length; i++) {
            if (signers[i] == _from) {
                signers[i] = _to;
                break;
            }
        }

        emit SignerAdjusted(_from, _to);
    }    

    function MakeAWill(address[] memory _recipient, uint256[] memory _portion) public onlyPredecessorCA {
        require(_recipient.length == _portion.length, "recipients and portions length mismatch");
        require(_recipient.length > 0, "no recipients specified");
        require(_recipient.length == signers.length, "num of recipients dosen't signers");
        for(uint i = 0; i < _recipient.length; i++) {
            require(isSigner[_recipient[i]], "there's recipient not a signer");
        }

        for(uint i = 0; i < signers.length; i++) {
            willPortions.push(_portion[i]);
            willSeq.push(_recipient[i]);
        }

        predecessorMakeAWill = true;
    }

    function withdrawWillPortions() public onlySigner {
        require(predecessorMakeAWill, "Predecessor has not made a will");
        require(!alreadyWithdrawnWill, "Already withdrawn will");

        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: address(0),
                value: 0,
                data: "",
                executed: false,
                numConfirmations: numConfirmationsRequired,
                recipients: willSeq,
                portions: willPortions,
                isBatchWithdrawal: true
            })
        );
        
        emit SubmitConsensus(msg.sender, txIndex, willSeq, willPortions);
        executeTransaction();
    }

    // submit a transaction to send ETH to an address
    function submitTransaction(address _to, uint256 _value, bytes memory _data) public onlySigner {
        if(transactions.length > 0) {
            require(transactions[transactions.length-1].executed, "cannot submit another tx until the previous one is executed");
        }

        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 1,
                recipients: new address[](1),
                portions: new uint256[](1),
                isBatchWithdrawal: false
            })
        );
        isConfirmed[txIndex][msg.sender] = true;
        // transactions[txIndex].recipients[0] = _to;
        // transactions[txIndex].portions[0] = _value;

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    // submit a transaction to send ETH to multiple addresses
    function submitConsensus(address[] memory _recipients, uint256[] memory _portions) public onlySigner {
        require(!predecessorMakeAWill , "Predecessor has made a will");
        require(_recipients.length == _portions.length, "recipients and portions length mismatch");
        require(_recipients.length > 0, "no recipients specified");

        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: address(0),
                value: 0,
                data: "",
                executed: false,
                numConfirmations: 1,
                recipients: _recipients,
                portions: _portions,
                isBatchWithdrawal: true
            })
        );
        isConfirmed[txIndex][msg.sender] = true;
        emit SubmitConsensus(msg.sender, txIndex, _recipients, _portions);
    }

    // confirm the latest transaction
    function confirmTransaction() public onlySigner txExists(transactions.length-1) notExecuted(transactions.length-1) notConfirmed(transactions.length-1) {
        Transaction storage transaction = transactions[transactions.length-1];
        transaction.numConfirmations += 1;
        isConfirmed[transactions.length-1][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, transactions.length-1);
    }

    // execute the latest transaction
    // if the transaction is a batch withdrawal, the ETH will be sent to the recipients based on the portions
    function executeTransaction() public onlySigner txExists(transactions.length-1) notExecuted(transactions.length-1) {
        Transaction storage transaction = transactions[transactions.length-1];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx (not enough confirmations)"
        );

        if (transaction.isBatchWithdrawal) {
            executeBatchWithdrawal();
        } else {
            require(address(this).balance >= transaction.value, "insufficient balance");
            (bool success, ) = transaction.to.call{value: transaction.value }(
                transaction.data
            );
            require(success, "tx failed");
        }

        transaction.executed = true;

        emit ExecuteTransaction(msg.sender, transactions.length-1);
    }

    // this function is called when a batch withdrawal transaction is executed
    function executeBatchWithdrawal() internal {
        Transaction storage transaction = transactions[transactions.length-1];
        uint256 totalBalance = address(this).balance;
        uint256 totalPortions = 0;

        for (uint256 i = 0; i < transaction.portions.length; i++) {
            totalPortions += transaction.portions[i];
        }

        for (uint256 i = 0; i < transaction.recipients.length; i++) {
            uint256 amount = (totalBalance * transaction.portions[i]) / totalPortions;
            (bool success, ) = transaction.recipients[i].call{value: amount}("");
            require(success, "batch withdrawal failed");
        }
    }

    function revokeConfirmation() public onlySigner txExists(transactions.length-1) notExecuted(transactions.length-1) {
        Transaction storage transaction = transactions[transactions.length-1];

        require(isConfirmed[transactions.length-1][msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[transactions.length-1][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, transactions.length-1);
    }

    function getSigners() public view returns (address[] memory) {
        return signers;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction()
        public
        view
        returns (
            bytes memory data,
            bool executed,
            uint256 numConfirmations,
            address[] memory recipients,
            uint256[] memory portions,
            bool isBatchWithdrawal
        )
    {
        Transaction storage transaction = transactions[transactions.length-1];

        return (
            transaction.data,
            transaction.executed,
            transaction.numConfirmations,
            transaction.recipients,
            transaction.portions,
            transaction.isBatchWithdrawal
        );
    }

    function getConfirmList() public view returns (address[] memory _confirmedList, address[] memory _unconfirmedList) {
        address[] memory confirmedList = new address[](signers.length);
        address[] memory unconfirmedList = new address[](signers.length);
        uint256 confirmedIndex = 0;
        uint256 unconfirmedIndex = 0;

        for (uint256 i = 0; i < signers.length; i++) {
            if (isConfirmed[transactions.length-1][signers[i]]) {
                confirmedList[confirmedIndex] = signers[i];
                confirmedIndex++;
            } else {
                unconfirmedList[unconfirmedIndex] = signers[i];
                unconfirmedIndex++;
            }
        }

        return (confirmedList, unconfirmedList);
    }

    enum CAAction { RequestInactiveAccount, WithdrawAllToNominee }

    function callPredecessorCA(CAAction action) public onlySigner {
        bytes memory data;
        if (action == CAAction.RequestInactiveAccount) {
            data = abi.encodeWithSignature("requestInactiveAccount()");
        } else if (action == CAAction.WithdrawAllToNominee) {
            data = abi.encodeWithSignature("withdrawAllToNominee()");
        } else {
            revert("Invalid action");
        }

        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: predecessorCA,
                value: 0,
                data: data,
                executed: false,
                numConfirmations: numConfirmationsRequired, // numConfirmations set to all to directly execute the transaction
                recipients: new address[](1),
                portions: new uint256[](1),
                isBatchWithdrawal: false
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, predecessorCA, 0, data);

        executeTransaction();
    }

    // function requestInactiveAccount() public onlySigner {
    //     bytes memory data = abi.encodeWithSignature("requestInactiveAccount()");
    //     uint256 txIndex = transactions.length;

    //     transactions.push(
    //         Transaction({
    //             to: predecessorCA,
    //             value: 0,
    //             data: data,
    //             executed: false,
    //             numConfirmations: numConfirmationsRequired, // numConfirmations set to all to directly execute the transaction
    //             recipients: new address[](1),
    //             portions: new uint256[](1),
    //             isBatchWithdrawal: false
    //         })
    //     );

    //     emit SubmitTransaction(msg.sender, txIndex, predecessorCA, 0, data);

    //     executeTransaction();
    // }
    
    // function withdrawAllToNominee() public onlySigner {
    //     bytes memory data = abi.encodeWithSignature("withdrawAllToNominee()");
    //     uint256 txIndex = transactions.length;

    //     transactions.push(
    //         Transaction({
    //             to: predecessorCA,
    //             value: 0,
    //             data: data,
    //             executed: false,
    //             numConfirmations: numConfirmationsRequired, // numConfirmations set to all to directly execute the transaction
    //             recipients: new address[](1),
    //             portions: new uint256[](1),
    //             isBatchWithdrawal: false
    //         })
    //     );

    //     emit SubmitTransaction(msg.sender, txIndex, predecessorCA, 0, data);

    //     executeTransaction();
    // }

}
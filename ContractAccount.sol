// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract ContractAccount {
    address public owner;

    struct DeadmanSwitchStorage {
        uint48 lastAccess;
        uint48 timeout;
        uint48 lastRequest;
        address nominee;
    }

    DeadmanSwitchStorage public config;

    event PreHookExecuted(address indexed owner, string message);
    event SendExecuted(address indexed to, uint256 value);
    event NomineeSet(address indexed account, address nominee);
    event TimeoutSet(address indexed account, uint48 timeout);
    event requestEcecuted(address indexed account, uint48 requestTime);

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyNominee() {
        require(config.nominee != address(0), "Nominee not set");
        require(msg.sender == config.nominee, "Not authorized nominee");
        _;
    }

    modifier onlyIfTimeoutSet() {
        require(config.timeout != 0, "Timeout not set");
        _;
    }

    function setNominee(address nominee) external onlyOwner {
        preHook();
        address account = msg.sender;
        // set the nominee
        config.nominee = nominee;

        emit NomineeSet(account, nominee);
    }

    function setTimeout(uint48 timeout) external onlyOwner {
        preHook();
        address account = msg.sender;
        // set the timeout
        config.timeout = timeout;

        emit TimeoutSet(account, timeout);
    }

    function requestInactiveAccount() external onlyNominee onlyIfTimeoutSet {
        require(!isWithdrawable(), "already able to withdraw!");
        require(config.lastAccess > config.lastRequest, "already request pending!");
        config.lastRequest = uint48(block.timestamp);
        emit requestEcecuted(config.nominee, config.lastRequest);
    }

    function preHook() internal {
        config.lastAccess = uint48(block.timestamp);
        emit PreHookExecuted(owner, "Udpate last access time stamp");
    }

    function sendEther(address payable to, uint256 amount) external onlyOwner {
        preHook();
        require(address(this).balance >= amount, "Insufficient balance");
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "Failed to send Ether");
        emit SendExecuted(to, amount);
    }

    function executeTransaction(
        address to,
        uint256 value,
        bytes memory data
    ) public onlyOwner returns (bytes memory) {
        preHook();
        (bool success, bytes memory result) = to.call{value: value}(data);
        require(success, "Transaction failed");
        return result;
    }

    function withdrawAllToNominee() public onlyNominee {
        require(isWithdrawable(), "Cannot withdraw!");

        address nominee = config.nominee;
        uint256 allBalance = address(this).balance;

        (bool sent, ) = nominee.call{value: allBalance}("");
        require(sent, "Failed to send Ether");
        emit SendExecuted(nominee, allBalance);
    }

    function isWithdrawable() public view returns (bool) {
        bool state = false;
        uint48 currentTime = uint48(block.timestamp);
        if (currentTime > config.timeout + config.lastRequest && config.lastRequest > config.lastAccess) {
            state = true;
        }
        return state;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
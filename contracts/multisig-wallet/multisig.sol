// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Wallet {
    address public owner;
    uint public ownerLimit;
    mapping (address => uint) public allowances;
    mapping (bytes32 => Payment) public payments;

    MultiSig public multiSig;
    uint public currentGuardiansCount;

    Voting public changeOwnerVoting;
    Voting public paymentVoting;
    VotingMode public votingMode;

    struct MultiSig {
        uint min;
        uint max;
        mapping (address => bool) guardians;
    }

    struct Payment {
        address receiver;
        address sender;
        uint amount;
        uint when;
        bool approved;
    }

    struct Voting {
        State state;
        mapping (address => mapping (bool => address[])) changeOwnerVotes;
        mapping (bytes32 => mapping (bool => address[])) paymentVotes;
        mapping (address => bool) hasVoted;
    }

    enum VotingMode { Payment, ChangeOwner }
    enum State { Stopped, Started, Running, Ended }

    constructor(uint _min, uint _max) payable {
        owner = msg.sender;
        multiSig.min = _min;
        multiSig.max = _max;
    }

    receive() external payable { }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner is allowed to run this");
        _;
    }

    modifier notOwner() {
        require(msg.sender != owner, "Owner is not allowed to run this");
        _;
    }

    modifier onlyGuardian() {
        require(multiSig.guardians[msg.sender], "You are not a guardian. You cannot vote");
        _;
    }

    modifier onlyOwnerOrGuardian() {
        require((multiSig.guardians[msg.sender] || msg.sender == owner), "You are not a guardian or the owner");
        _;
    }

    function getCurrentGuardiansCount() public view returns (uint) {
        return currentGuardiansCount;
    }

    function getPaymentId(Payment memory _payment) public pure returns (bytes32) {
        return keccak256(abi.encode(_payment));
    }

    function createPayment(address _to, uint _amount, uint _when) external onlyOwnerOrGuardian {
        Payment memory payment = Payment({ receiver: _to, sender: msg.sender, amount: _amount , when: _when, approved: false });
        payments[getPaymentId(payment)] = payment;
    }

    function setAllowance(address _to, uint _amount) external onlyOwner {
        allowances[_to] = _amount;
    }

    function addAllowance(address _to, uint _amount) external onlyOwner {
        allowances[_to] = allowances[_to] + _amount;
    }

    function reduceAllowance(address _to, uint _amount) external onlyOwner {
        require(allowances[_to] >= _amount, "Try reducing allowance by smaller");
        allowances[_to] = allowances[_to] - _amount;
    }

    function addGuardian(address _guardian) external onlyOwner {
        require(currentGuardiansCount < multiSig.max, "Maximum allowed guardians reached");
        require(owner != _guardian, "Owner cannot be added as guardian");
        require(!multiSig.guardians[_guardian], "Cannot add same address as guardian again");

        currentGuardiansCount++;
        multiSig.guardians[_guardian] = true;
    }

    function startVoting(VotingMode _votingMode) external onlyOwnerOrGuardian {
        require(currentGuardiansCount == multiSig.max, "You have not reached the required number of guardians");
        if (_votingMode == VotingMode.Payment) {
            paymentVoting.state = State.Started;
        } else {
            changeOwnerVoting.state = State.Started;
        }
    }

    function stopVoting(VotingMode _votingMode) external onlyOwnerOrGuardian {
        if (_votingMode == VotingMode.Payment) {
            paymentVoting.state = State.Stopped;
        } else {
            changeOwnerVoting.state = State.Stopped;
        }
    }

    function changeOwner(address _to, bool _vote) external notOwner onlyGuardian {
        require(changeOwnerVoting.state == State.Started || changeOwnerVoting.state == State.Running, "Voting has either not started or already ended");
        require(!changeOwnerVoting.hasVoted[msg.sender], "You have already voted. You are not allowed to vote again!");
        require(_vote == true, "You are attempting to change owner for false value!");

        if (changeOwnerVoting.state == State.Started) {
            changeOwnerVoting.state = State.Running;
        }
        
        changeOwnerVoting.hasVoted[msg.sender] = true;
        changeOwnerVoting.changeOwnerVotes[_to][_vote].push(msg.sender);

        if (changeOwnerVoting.changeOwnerVotes[_to][true].length >= multiSig.min) {
            owner = _to;
            changeOwnerVoting.state = State.Ended;
        }
    }

    function approvePayment(bytes32 _paymentId, bool _vote) external onlyOwnerOrGuardian {
        require(paymentVoting.state == State.Started || paymentVoting.state == State.Running, "Voting has either not started or already ended");
        
        Payment storage payment = payments[_paymentId];

        require(payment.amount != 0, "You are attempting to spend 0 funds");

        if ((payment.sender == owner && payment.amount <= ownerLimit) || allowances[payment.sender] >= payment.amount) {
            if (allowances[payment.sender] != 0) {
                allowances[payment.sender] = allowances[payment.sender] - payment.amount;
            }
            paymentVoting.state = State.Ended;
            payment.approved = true;
            return;
        } 

        require(!payment.approved, "You cannot approve funds that are already approved!");
        require(!paymentVoting.hasVoted[msg.sender], "You have already voted");
        require(_vote == true, "You are attempting to approve payment for false value!");

        require (payment.receiver != address(0), "_paymentId does not exist");
        
        paymentVoting.hasVoted[msg.sender] = true;
        paymentVoting.paymentVotes[_paymentId][true].push(msg.sender);

        if (paymentVoting.paymentVotes[_paymentId][true].length >= multiSig.min) {
            payments[_paymentId] = payment;
            payment.approved = true;
            paymentVoting.state = State.Ended;
        }
    }

    function spendFunds(bytes32 _paymentId) external {
        Payment memory payment = payments[_paymentId];

        require(paymentVoting.state == State.Ended && payment.approved, "Payment is still being voted or not approved");
        
        payable(payments[_paymentId].receiver).transfer(payment.amount);
    }

    function getBalance() public view returns(uint){
        return address(this).balance;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;
 
// events to emit
event ContributeEvent(address _sender, uint _value);
event CreateRequestEvent(string _description, address _recipient, uint _value);
event MakePaymentEvent(address _recipient, uint _value);

// state of the voting
enum VoteState { Undefined, Yes, No }

// Spending Request
struct Request {
    string description;
    address payable recipient;
    uint value;
    bool completed;
    uint noOfVoters;
    mapping(address => VoteState) voters;
}

contract CrowdFunding {
    mapping(address => uint) public contributors;
    address public admin;
    uint public noOfContributors;
    uint public minimumContribution;
    uint public deadline; //timestamp
    uint public goal;
    uint public raisedAmount;
    
    // mapping of spending requests
    // the key is the spending request number (index) - starts from zero
    // the value is a Request struct
    mapping(uint => Request) public requests;
    uint public numRequests;
    
    constructor(uint _goal, uint _deadline) {
        goal = _goal;
        deadline = block.timestamp + _deadline;
        admin = msg.sender;
        minimumContribution = 100 wei;
    }
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can execute this");
        _;
    }

    modifier isOpen() {
        require(block.timestamp < deadline, "Deadline has passed.");
        _;
    }

    modifier isClosed() {
        require(block.timestamp > deadline, "Crowdfunding is still open.");
        _;
    }
    
    function contribute() public payable isOpen {
        require(msg.value >= minimumContribution, "The Minimum Contribution not met!");
        
        // incrementing the no. of contributors the first time when 
        // someone sends eth to the contract
        if(contributors[msg.sender] == 0) {
            noOfContributors++;
        }
        
        contributors[msg.sender] += msg.value;
        raisedAmount += msg.value;
        
        emit ContributeEvent(msg.sender, msg.value);
    }
    
    function getBalance() public view returns(uint) {
        return address(this).balance;
    }
    
    // a contributor can get a refund if goal was not reached within the deadline
    function getRefund() public isClosed {
        require(raisedAmount < goal, "The goal was met");
        require(contributors[msg.sender] > 0);
        
        address payable recipient = payable(msg.sender);
        uint value = contributors[msg.sender];
        
        // resetting the value sent by the contributor and transfering the value
        contributors[msg.sender] = 0;  
        recipient.transfer(value);
        // equivalent to:
        // payable(msg.sender).transfer(contributors[msg.sender]);
    }
    
    function createRequest(string calldata _description, address payable _recipient, uint _value) public onlyAdmin {
        //numRequests starts from zero
        Request storage newRequest = requests[numRequests];
        numRequests++;
        
        newRequest.description = _description;
        newRequest.recipient = _recipient;
        newRequest.value = _value;
        newRequest.completed = false;
        newRequest.noOfVoters = 0;
        
        emit CreateRequestEvent(_description, _recipient, _value);
    }
    
    
    function voteRequest(uint _requestNo, bool _voteState) public {
        require(contributors[msg.sender] > 0, "You must be a contributor to vote!");
        
        Request storage thisRequest = requests[_requestNo];
        require(thisRequest.voters[msg.sender] != VoteState.Undefined , "You have already voted!");
        
        if (_voteState) {
            thisRequest.voters[msg.sender] = VoteState.Yes;
        } else {
            thisRequest.voters[msg.sender] = VoteState.No;
        }
        thisRequest.noOfVoters++;
    }
    
    
    function makePayment(uint _requestNo) public onlyAdmin {
        Request storage thisRequest = requests[_requestNo];
        require(thisRequest.completed == false, "The request has been already completed!");
        
        require(thisRequest.noOfVoters > noOfContributors / 2, "The request needs more than 50% of the contributors.");
        
        // setting thisRequest as being completed and transfering the money
        thisRequest.completed = true;
        thisRequest.recipient.transfer(thisRequest.value);
        
        emit MakePaymentEvent(thisRequest.recipient, thisRequest.value);
    }  
}

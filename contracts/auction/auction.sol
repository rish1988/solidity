//SPDX-License-Identifier: MIT
 
pragma solidity >=0.8.0 <0.9.0;

enum State { Running, Started, Ended, Cancelled }

contract AuctionCreator {
    Auction[] public auctions;
    
    function createAuction() public {
        Auction newAuction = new Auction(msg.sender);
        auctions.push(newAuction);
    }
}

contract Auction {
    address payable public owner;
    uint public startBlock;
    uint public endBlock;
    string public ipfsHash;
    State public auctionState;
    uint public highestBindingBid;
    address payable public highestBidder;    
    mapping(address => uint) public bids;
    uint public bidIncrement;
    //the owner can finalize the auction and get the highestBindingBid only once
    bool public ownerFinalized = false;

    constructor(address eoa) {
        owner = payable(eoa);
        bidIncrement = 100;
        startBlock = block.number;
        endBlock = startBlock + 40320;
        auctionState = State.Running;
        ipfsHash = "";
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner is allowed");
        _;
    }

    modifier notOwner() {
        require(owner != msg.sender, "Owner is not allowed to bid");
        _;
    }

    modifier afterStart() {
        require(block.number >= startBlock, "Auction can only start after start block has been mined");
        _;
    }

    modifier beforeEnd() {
        require(block.number <= endBlock, "Bids cannot be placed after end block of auction has been mined");
        _;
    }

    function min(uint a, uint b) pure internal returns(uint) {
        if (a <= b) {
            return a;
        }
        return b;
    }

    function placeBid() public payable notOwner afterStart beforeEnd {
        require(auctionState == State.Running);
        require(msg.value >= 100, "Minimum bid amount is 100 wei");

        uint currentBid = bids[msg.sender] + msg.value;

        require(currentBid > highestBindingBid);

        bids[msg.sender] = currentBid;

        if (currentBid <= bids[highestBidder]) {
            highestBindingBid = min(currentBid + bidIncrement, bids[highestBidder]);
        } else {
            highestBindingBid = min(currentBid, bids[highestBidder] + bidIncrement);
            highestBidder = payable(msg.sender);
        }
    }

    function cancelAuction() public onlyOwner {
        auctionState = State.Cancelled;
    }

    function finalizeAuction() public{
       // the auction has been Canceled or Ended
       require(auctionState == State.Cancelled || block.number > endBlock); 
       
       // only the owner or a bidder can finalize the auction
       require(msg.sender == owner || bids[msg.sender] > 0);
       
       // the recipient will get the value
       address payable recipient;
       uint value;
       
       if (auctionState == State.Cancelled) { // auction canceled, not ended
           recipient = payable(msg.sender);
           value = bids[msg.sender];
       } else {// auction ended, not canceled
           if (msg.sender == owner && ownerFinalized == false){ //the owner finalizes the auction
               recipient = owner;
               value = highestBindingBid;
               
               //the owner can finalize the auction and get the highestBindingBid only once
               ownerFinalized = true; 
            } else if (msg.sender == highestBidder) { // another user (not the owner) finalizes the auction
                   recipient = highestBidder;
                   value = bids[highestBidder] - highestBindingBid;
            } else { //this is neither the owner nor the highest bidder (it's a regular bidder)
                   recipient = payable(msg.sender);
                   value = bids[msg.sender];
            }
       }
       
       // resetting the bids of the recipient to avoid multiple transfers to the same recipient
       bids[recipient] = 0;
       
       //sends value to the recipient
       recipient.transfer(value);
    }
}

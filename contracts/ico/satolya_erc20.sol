//SPDX-License-Identifier: GPL-3.0
 
pragma solidity ^0.8.0;
// ----------------------------------------------------------------------------
// EIP-20: ERC-20 Token Standard
// https://eips.ethereum.org/EIPS/eip-20
// -----------------------------------------
 
interface ERC20Interface {
    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function transfer(address to, uint tokens) external returns (bool success);
    
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
    
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}
 
 
contract Satolya is ERC20Interface {
    string public name = "Satolya";
    string public symbol = "SAT";
    uint public decimals = 18; //18 is very common
    uint public override totalSupply;
    
    address public founder;
    mapping(address => uint) public balances;
    
    mapping(address => mapping(address => uint)) allowed;
    
    constructor() {
        totalSupply = 21000000;
        founder = msg.sender;
        balances[founder] = totalSupply;
    }
    
    
    function balanceOf(address tokenOwner) public view override returns (uint balance) {
        return balances[tokenOwner];
    }
    
    
    function transfer(address to, uint tokens) public virtual override returns(bool success) {
        require(balances[msg.sender] >= tokens);
        
        balances[to] = balances[to] + tokens;
        balances[msg.sender] = balances[msg.sender] - tokens;
        emit Transfer(msg.sender, to, tokens);
        
        return true;
    }
    
    
    function allowance(address tokenOwner, address spender) view public override returns(uint) {
        return allowed[tokenOwner][spender];
    }
    
    
    function approve(address spender, uint tokens) public override returns (bool success) {
        require(balances[msg.sender] >= tokens);
        require(tokens != 0);
        
        allowed[msg.sender][spender] = tokens;
        
        emit Approval(msg.sender, spender, tokens);
        return true;
    }
    
    
    function transferFrom(address from, address to, uint tokens) public virtual override returns (bool success) {
         require(allowed[from][msg.sender] >= tokens);
         require(balances[from] >= tokens);
         
         balances[from] = balances[from] + tokens;
         allowed[from][msg.sender] = allowed[from][msg.sender] + tokens;
         balances[to] = balances[to] + tokens;
 
         emit Transfer(from, to, tokens);
         
         return true;
     }
}

contract SatolyaICO is Satolya {
    address public admin;
    address payable public deposit;
    uint tokenPrice = 0.001 ether;  // 1 ETH = 1000 CRTP, 1 CRPT = 0.001
    uint public hardCap = 300 ether;
    uint public raisedAmount; // this value will be in wei
    uint public saleStart = block.timestamp;
    uint public saleEnd = block.timestamp + 604800; //one week
    
    uint public tokenTradeStart = saleEnd + 604800; //transferable in a week after saleEnd
    uint public maxInvestment = 5 ether;
    uint public minInvestment = 0.1 ether;
    
    enum State { beforeStart, running, afterEnd, halted} // ICO states 
    State public icoState;
    
    constructor(address payable _deposit) {
        deposit = _deposit; 
        admin = msg.sender; 
        icoState = State.beforeStart;
    }
 
    
    modifier onlyAdmin(){
        require(msg.sender == admin);
        _;
    }
    
    
    // emergency stop
    function halt() external onlyAdmin {
        icoState = State.halted;
    }
    
    
    function resume() external onlyAdmin {
        icoState = State.running;
    }
    
    
    function changeDepositAddress(address payable newDeposit) external onlyAdmin {
        deposit = newDeposit;
    }
    
    
    function getCurrentState() public view returns(State) {
        if(icoState == State.halted){
            return State.halted;
        }else if(block.timestamp < saleStart){
            return State.beforeStart;
        }else if(block.timestamp >= saleStart && block.timestamp <= saleEnd){
            return State.running;
        }else{
            return State.afterEnd;
        }
    }
 
 
    event Invest(address investor, uint value, uint tokens);
    
    
    // function called when sending eth to the contract
    function invest() payable public returns(bool) { 
        icoState = getCurrentState();
        require(icoState == State.running);
        require(msg.value >= minInvestment && msg.value <= maxInvestment);
        
        raisedAmount = raisedAmount + msg.value;
        require(raisedAmount <= hardCap);
        
        uint tokens = msg.value / tokenPrice;
 
        // adding tokens to the inverstor's balance from the founder's balance
        balances[msg.sender] = balances[msg.sender] + tokens;
        balances[founder] = balances[founder] - tokens; 
        deposit.transfer(msg.value); // transfering the value sent to the ICO to the deposit address
        
        emit Invest(msg.sender, msg.value, tokens);
        
        return true;
    }
   
   
   // this function is called automatically when someone sends ETH to the contract's address
   receive () payable external {
        invest();
    }
  
    
    // burning unsold tokens
    function burn() public returns(bool) {
        icoState = getCurrentState();
        require(icoState == State.afterEnd);
        balances[founder] = 0;
        return true;
        
    }
    
    
    function transfer(address to, uint tokens) public override returns (bool success) {
        require(block.timestamp > tokenTradeStart); // the token will be transferable only after tokenTradeStart
        
        // calling the transfer function of the base contract
        super.transfer(to, tokens);  // same as Satolya.transfer(to, tokens);
        return true;
    }
    
    
    function transferFrom(address from, address to, uint tokens) public override returns (bool success) {
        require(block.timestamp > tokenTradeStart); // the token will be transferable only after tokenTradeStart
       
        Satolya.transferFrom(from, to, tokens);  // same as super.transferFrom(to, tokens);
        return true;
    }
}

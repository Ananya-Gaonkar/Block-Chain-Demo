// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
 This contract demonstrates:
 1. State Variables
 2. Constructor
 3. Functions (view, pure, public, private)
 4. Mappings
 5. Arrays
 6. Events
 7. Require() validation
 8. Modifiers (onlyOwner)
 9. Payable functions
10. Ether Transfer
11. Smart contract balance
12. Ownership management
*/

contract FullDemoContract {

    // -------------------------
    // 1. STATE VARIABLES
    // -------------------------

    address public owner;              // stores owner address
    string public message = "Hello";   // simple string variable
    uint public number;                // unsigned integer
    uint[] public values;              // dynamic array
    mapping(address => uint) public balances; // mapping to store payments


    // -------------------------
    // 2. CONSTRUCTOR
    // -------------------------
    constructor() {
        owner = msg.sender;    // person who deploys contract becomes owner
    }


    // -------------------------
    // 3. MODIFIER (access control)
    // -------------------------
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner!");
        _;
    }


    // -------------------------
    // 4. FUNCTIONS
    // -------------------------

    // Update message
    function setMessage(string memory newMsg) public {
        message = newMsg;
    }

    // Set a number
    function setNumber(uint x) public {
        number = x;
        values.push(x); // also store in array
    }

    // Get array length
    function getValuesCount() public view returns(uint) {
        return values.length;
    }

    // Pure function example (no state access)
    function add(uint a, uint b) public pure returns(uint) {
        return a + b;
    }


    // -------------------------
    // 5. PAYABLE FUNCTIONS
    // -------------------------
    
    // Receive Ether and store sender’s balance
    

    // Withdraw contract balance (owner only)
    function withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
        emit Withdraw(owner, address(this).balance);
    }


    // -------------------------
    // 6. EVENTS
    // -------------------------
    event PaymentReceived(address from, uint amount);
    event Withdraw(address to, uint amount);


    // -------------------------
    // 7. FALLBACK & RECEIVE
    // -------------------------
    
    // When someone sends Ether without calling a function
    receive() external payable {
        balances[msg.sender] += msg.value;
        emit PaymentReceived(msg.sender, msg.value);
    }

    // Fallback catches unknown function calls
    fallback() external payable {
        balances[msg.sender] += msg.value;
        emit PaymentReceived(msg.sender, msg.value);
    }
}

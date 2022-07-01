// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Governance {
    string question;

    function set(string memory value) public {
        question = value;
    }

    function get() public view returns (string memory storedValue) {
        return question;
    }
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

contract Governance {
    string question;

    function set(string memory value) public {
        question = value;
    }

    function get() public view returns (string memory storedValue) {
        return question;
    }
}

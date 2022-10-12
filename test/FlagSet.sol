// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

contract FlagSet {
    bool public isSet = false;

    function set() external {
        isSet = true;
    }
}

contract ValueSet {
    mapping(address => uint256) public _valueSet;

    function set(uint256 value) external {
        set(msg.sender, value);
    }

    function set(address sender, uint256 value) public {
        _valueSet[sender] = value;
    }

    function valueOf(address sender) external view returns (uint256) {
        return _valueSet[sender];
    }
}

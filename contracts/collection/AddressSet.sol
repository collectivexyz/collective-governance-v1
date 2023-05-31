// SPDX-License-Identifier: BSD-3-Clause
/*
 *                          88  88                                   88
 *                          88  88                            ,d     ""
 *                          88  88                            88
 *  ,adPPYba,   ,adPPYba,   88  88   ,adPPYba,   ,adPPYba,  MM88MMM  88  8b       d8   ,adPPYba,
 * a8"     ""  a8"     "8a  88  88  a8P_____88  a8"     ""    88     88  `8b     d8'  a8P_____88
 * 8b          8b       d8  88  88  8PP"""""""  8b            88     88   `8b   d8'   8PP"""""""
 * "8a,   ,aa  "8a,   ,a8"  88  88  "8b,   ,aa  "8a,   ,aa    88,    88    `8b,d8'    "8b,   ,aa
 *  `"Ybbd8"'   `"YbbdP"'   88  88   `"Ybbd8"'   `"Ybbd8"'    "Y888  88      "8"       `"Ybbd8"'
 *
 */
/*
 * BSD 3-Clause License
 *
 * Copyright (c) 2023, collective
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
pragma solidity ^0.8.15;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface AddressCollection {
    error IndexInvalid(uint256 index);
    error DuplicateAddress(address _address);

    event AddressAdded(address element);
    event AddressRemoved(address element);

    function add(address _element) external returns (uint256);

    function set(address _element) external returns (bool);

    function size() external view returns (uint256);

    function get(uint256 index) external view returns (address);

    function contains(address _element) external view returns (bool);

    function erase(address _element) external returns (bool);
}

/// @title dynamic collection of addresses
contract AddressSet is Ownable, AddressCollection {
    uint256 private _elementCount;

    mapping(uint256 => address) private _elementMap;

    mapping(address => uint256) private _elementPresent;

    constructor() {
        _elementCount = 0;
    }

    modifier requireValidIndex(uint256 index) {
        if (index == 0 || index > _elementCount) revert IndexInvalid(index);
        _;
    }

    /// @notice add an element
    /// @param _element the address
    /// @return uint256 the elementId of the transaction
    function add(address _element) public onlyOwner returns (uint256) {
        uint256 elementIndex = ++_elementCount;
        _elementMap[elementIndex] = _element;
        if (_elementPresent[_element] > 0) revert DuplicateAddress(_element);
        _elementPresent[_element] = elementIndex;
        emit AddressAdded(_element);
        return elementIndex;
    }

    /// @notice set value
    /// @param _element the address
    /// @return bool true if added false otherwise
    function set(address _element) external onlyOwner returns (bool) {
        if (_elementPresent[_element] > 0) return false;
        add(_element);
        return true;
    }

    /// @notice erase an element
    /// @dev swaps element to end and deletes the end
    /// @param _index The address to erase
    /// @return bool True if element was removed
    function erase(uint256 _index) external onlyOwner returns (bool) {
        address _element = _elementMap[_index];
        return erase(_element);
    }

    /// @notice erase an element
    /// @dev swaps element to end and deletes the end
    /// @param _element The address to erase
    /// @return bool True if element was removed
    function erase(address _element) public onlyOwner returns (bool) {
        uint256 elementIndex = _elementPresent[_element];
        if (elementIndex > 0) {
            address _lastElement = _elementMap[_elementCount];
            _elementMap[elementIndex] = _lastElement;
            _elementPresent[_lastElement] = elementIndex;
            _elementMap[_elementCount] = address(0x0);
            _elementPresent[_element] = 0;
            delete _elementMap[_elementCount];
            delete _elementPresent[_element];
            _elementCount--;
            emit AddressRemoved(_element);
            return true;
        }
        return false;
    }

    /// @return uint256 The size of the set
    function size() external view returns (uint256) {
        return _elementCount;
    }

    /// @param index The index to return
    /// @return address The requested address
    function get(uint256 index) external view requireValidIndex(index) returns (address) {
        return _elementMap[index];
    }

    /// @param _element The element to test
    /// @return bool True if address is contained
    function contains(address _element) external view returns (bool) {
        return find(_element) > 0;
    }

    /// @param _element The element to find
    /// @return uint256 The index associated with element
    function find(address _element) public view returns (uint256) {
        return _elementPresent[_element];
    }
}

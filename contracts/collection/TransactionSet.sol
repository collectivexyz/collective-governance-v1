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
 * Copyright (c) 2022, collective
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

import "../../contracts/Constant.sol";

/// @notice The executable transaction
struct Transaction {
    /// @notice target for call instruction
    address target;
    /// @notice value to pass
    uint256 value;
    /// @notice signature for call
    string signature;
    /// @notice call data of the call
    bytes _calldata;
    /// @notice future dated start time for call within the TimeLocked grace period
    uint256 scheduleTime;
}

// solhint-disable-next-line func-visibility
function getTxHash(Transaction memory transaction) pure returns (bytes32) {
    return
        Constant.getTxHash(
            transaction.target,
            transaction.value,
            transaction.signature,
            transaction._calldata,
            transaction.scheduleTime
        );
}

/// @title dynamic collection of transaction
contract TransactionSet {
    error IndexInvalid(uint256 index);
    error HashCollision(bytes32 txId);

    event TransactionAdded(bytes32 transactionHash);

    uint256 private _elementCount;

    mapping(uint256 => Transaction) private _elementMap;
    mapping(bytes32 => bool) private _elementPresent;

    constructor() {
        _elementCount = 0;
    }

    modifier requireValidIndex(uint256 index) {
        if (index == 0 || index > _elementCount) revert IndexInvalid(index);
        _;
    }

    function add(Transaction memory _element) external returns (uint256) {
        uint256 elementIndex = ++_elementCount;
        _elementMap[elementIndex] = _element;
        bytes32 _elementHash = getTxHash(_element);
        if (_elementPresent[_elementHash]) revert HashCollision(_elementHash);
        _elementPresent[_elementHash] = true;
        emit TransactionAdded(_elementHash);
        return elementIndex;
    }

    function size() external view returns (uint256) {
        return _elementCount;
    }

    function get(uint256 index) external view requireValidIndex(index) returns (Transaction memory) {
        return _elementMap[index];
    }
}

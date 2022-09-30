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

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../contracts/Constant.sol";
import "../contracts/VoterClass.sol";

/// @title interface for VoterPool
/// @notice sets the requirements for contracts implementing a VoterPool
/// @custom:type interface
interface VoterPool {
    /// @notice add voter to pool
    /// @param _wallet the address of the wallet
    function addVoter(address _wallet) external;

    /// @notice remove voter from the pool
    /// @param _wallet the address of the wallet
    function removeVoter(address _wallet) external;

    /// @notice test if the pool if final
    /// @return bool true if pool if final
    function isFinal() external view returns (bool);

    /// @notice mark the VoterPool as final
    function makeFinal() external;
}

/// @title VoterClassVoterPool contract
/// @notice This contract supports voting for a specific list of wallet addresses.   Each address must be added
/// to the contract prior to voting at which time the pool must be marked as final so that it becomes impossible
/// to modify
contract VoterClassVoterPool is VoterClass, ERC165, Ownable {
    event RegisterVoter(address voter);
    event BurnVoter(address voter);

    string public constant NAME = "collective.xyz VoterClassVoterPool";

    uint256 private immutable _weight;

    bool private _isPoolFinal;

    // whitelisted voters
    mapping(address => bool) private _voterPool;

    /// @param _voteWeight The integral weight to apply to each token held by the wallet
    constructor(uint256 _voteWeight) {
        _weight = _voteWeight;
        _isPoolFinal = false;
    }

    modifier requireValidAddress(address _wallet) {
        require(_wallet != address(0), "Not a valid wallet");
        _;
    }

    modifier requireValidShare(address _wallet, uint256 _shareId) {
        require(_shareId > 0 && _shareId == uint160(_wallet), "Not a valid share");
        _;
    }

    modifier requireNotFinal() {
        require(!_isPoolFinal, "Voter pool is not modifiable");
        _;
    }

    modifier requireFinal() {
        require(_isPoolFinal, "Voter pool is modifiable");
        _;
    }

    modifier requireVoter(address _wallet) {
        require(_voterPool[_wallet], "Not voter");
        _;
    }

    /// @notice add a voter to the voter pool
    /// @dev only possible if not final
    /// @param _wallet the address to add
    function addVoter(address _wallet) external requireValidAddress(_wallet) onlyOwner requireNotFinal {
        if (!_voterPool[_wallet]) {
            _voterPool[_wallet] = true;
            emit RegisterVoter(_wallet);
        } else {
            revert("Voter already registered");
        }
    }

    /// @notice remove a voter from the voter pool
    /// @dev only possible if not final
    /// @param _wallet the address to add
    function removeVoter(address _wallet) external requireValidAddress(_wallet) onlyOwner requireNotFinal {
        if (_voterPool[_wallet]) {
            _voterPool[_wallet] = false;
            emit BurnVoter(_wallet);
        } else {
            revert("Voter not registered");
        }
    }

    /// @notice test if voterclass is modifiable such as to add or remove voters from a pool
    /// @return bool true if class is final
    function isFinal() external view returns (bool) {
        return _isPoolFinal;
    }

    /// @notice test if wallet represents an allowed voter for this class
    /// @return bool true if wallet is a voter
    function isVoter(address _wallet) external view requireValidAddress(_wallet) returns (bool) {
        return _voterPool[_wallet];
    }

    /// @notice discover an array of shareIds associated with the specified wallet
    /// @return uint256[] array in memory of share ids
    function discover(address _wallet) external view requireVoter(_wallet) requireFinal returns (uint256[] memory) {
        uint256[] memory shareList = new uint256[](1);
        shareList[0] = uint160(_wallet);
        return shareList;
    }

    /// @notice confirm shareid is associated with wallet for voting
    /// @return uint256 The number of weighted votes confirmed
    function confirm(address _wallet, uint256 _shareId)
        external
        view
        requireFinal
        requireVoter(_wallet)
        requireValidShare(_wallet, _shareId)
        returns (uint256)
    {
        return _weight;
    }

    /// @notice return voting weight of each confirmed share
    function weight() external view returns (uint256) {
        return _weight;
    }

    /// @notice set the voterpool final.   No further changes may be made to the voting pool.
    function makeFinal() external requireNotFinal {
        _isPoolFinal = true;
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(VoterPool).interfaceId ||
            interfaceId == type(VoterClass).interfaceId ||
            interfaceId == type(Ownable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure virtual returns (string memory) {
        return NAME;
    }

    /// @notice return the version of this implementation
    /// @return uint32 version number
    function version() external pure returns (uint32) {
        return Constant.VERSION_1;
    }
}

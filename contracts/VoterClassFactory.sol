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

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "../contracts/VoterClass.sol";
import "../contracts/VoterClassOpenVote.sol";
import "../contracts/VoterClassVoterPool.sol";
import "../contracts/VoterClassERC721.sol";
import "../contracts/VoterClassClosedERC721.sol";
import "../contracts/VoterClassCreator.sol";
import "../contracts/access/Versioned.sol";
import "../contracts/access/VersionedContract.sol";

/// @title Creator for VoterClass implementations
/// @notice A simple factory for VoterClass instances.
contract VoterClassFactory is VoterClassCreator, VersionedContract, ERC165 {
    /// @notice create a VoterClass for open voting
    /// @param _weight The weight associated with each vote
    /// @return address The address of the resulting voter class
    function createOpenVote(uint256 _weight) external returns (address) {
        VoterClass _class = new VoterClassOpenVote(_weight);
        address _classAddr = address(_class);
        emit VoterClassCreated(_classAddr, msg.sender);
        return _classAddr;
    }

    /// @notice create a VoterClass for pooled voting
    /// @param _weight The weight associated with each vote
    /// @return address The address of the resulting voter class
    function createVoterPool(uint256 _weight) external returns (address) {
        VoterClass _class = new VoterClassVoterPool(_weight);
        address _classAddr = address(_class);
        emit VoterClassCreated(_classAddr, msg.sender);
        return _classAddr;
    }

    /// @notice create a VoterClass for token holding members
    /// @param _erc721 The address of the ERC-721 contract for voting
    /// @param _weight The weight associated with each vote
    /// @return address The address of the resulting voter class
    function createERC721(address _erc721, uint256 _weight) external returns (address) {
        return createERC721(_erc721, 1, _weight, false);
    }

    /// @notice create a VoterClass for token holding members
    /// @param _erc721 The address of the ERC-721 contract for voting
    /// @param _tokenRequirement The number of tokens required for a proposal
    /// @param _weight The weight associated with each vote
    /// @param _isClosed True if class should be closed, false otherwise
    /// @return address The address of the resulting voter class
    function createERC721(
        address _erc721,
        uint256 _tokenRequirement,
        uint256 _weight,
        bool _isClosed
    ) public returns (address) {
        VoterClass _class;
        if (_isClosed) {
            _class = new VoterClassClosedERC721(_erc721, _tokenRequirement, _weight);
        } else {
            _class = new VoterClassERC721(_erc721, _weight);
        }
        address _classAddr = address(_class);
        emit VoterClassCreated(_classAddr, _erc721);
        return _classAddr;
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(VoterClassCreator).interfaceId ||
            interfaceId == type(Versioned).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: BSD-3-Clause
/*
 * BSD 3-Clause License
 *
 * Copyright (c) 2022, Collective.XYZ
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

import "./VoterClass.sol";

interface VoterPool {
    function addVoter(address _wallet) external;

    function removeVoter(address _wallet) external;

    function isFinal() external view returns (bool);

    function makeFinal() external;
}

/// @notice voting class for ERC-721 contract
contract VoterClassVoterPool is VoterClass, ERC165 {
    event RegisterVoter(address voter);
    event BurnVoter(address voter);

    string public constant NAME = "collective.xyz VoterClassVoterPool";
    uint32 public constant VERSION_1 = 1;

    address private immutable _cognate;

    uint256 private immutable _weight;

    bool private _isPoolFinal;

    // whitelisted voters
    mapping(address => bool) private _voterPool;

    constructor(uint256 _voteWeight) {
        _cognate = msg.sender;
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

    modifier requireCognate() {
        require(_cognate == msg.sender, "Not permitted");
        _;
    }

    function addVoter(address _wallet) external requireValidAddress(_wallet) requireCognate requireNotFinal {
        if (!_voterPool[_wallet]) {
            _voterPool[_wallet] = true;
            emit RegisterVoter(_wallet);
        } else {
            revert("Voter already registered");
        }
    }

    function removeVoter(address _wallet) external requireValidAddress(_wallet) requireCognate requireNotFinal {
        if (_voterPool[_wallet]) {
            _voterPool[_wallet] = false;
            emit BurnVoter(_wallet);
        } else {
            revert("Voter not registered");
        }
    }

    function isFinal() external view returns (bool) {
        return _isPoolFinal;
    }

    function isVoter(address _wallet) external view requireValidAddress(_wallet) returns (bool) {
        return _voterPool[_wallet];
    }

    function discover(address _wallet) external view requireVoter(_wallet) requireFinal returns (uint256[] memory) {
        uint256[] memory shareList = new uint256[](1);
        shareList[0] = uint160(_wallet);
        return shareList;
    }

    /// @notice commit votes for shareId return number voted
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

    function makeFinal() external requireNotFinal {
        _isPoolFinal = true;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return
            interfaceId == type(VoterPool).interfaceId ||
            interfaceId == type(VoterClass).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function name() external pure virtual returns (string memory) {
        return NAME;
    }

    function version() external pure returns (uint32) {
        return VERSION_1;
    }
}

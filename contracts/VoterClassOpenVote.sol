// SPDX-License-Identifier: BSD-3-Clause
/*
 * Copyright 2022 collective.xyz
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
pragma solidity ^0.8.15;

import "./VoterClass.sol";

/// @notice voting class to include every address
contract VoterClassOpenVote is VoterClass {
    uint256 private _weight;

    mapping(uint256 => bool) private _committedVote;

    address private _cognate;

    constructor(uint256 _voteWeight) {
        _cognate = msg.sender;
        _weight = _voteWeight;
    }

    modifier requireCognate() {
        require(_cognate == msg.sender, "Not permitted");
        _;
    }

    modifier requireValidAddress(address _wallet) {
        require(_wallet != address(0), "Not a valid wallet");
        _;
    }

    modifier requireValidShare(address _wallet, uint256 _shareId) {
        require(_shareId > 0 && _shareId == uint160(_wallet), "Not a valid share");
        _;
    }

    function isVoter(address _wallet) external pure requireValidAddress(_wallet) returns (bool) {
        return true;
    }

    function discover(address _wallet) external pure requireValidAddress(_wallet) returns (uint256[] memory) {
        uint256[] memory shareList = new uint256[](1);
        shareList[0] = uint160(_wallet);
        return shareList;
    }

    /// @notice commit votes for shareId return number voted
    function confirm(address _wallet, uint256 _shareId)
        external
        requireCognate
        requireValidShare(_wallet, _shareId)
        returns (uint256)
    {
        require(!_committedVote[_shareId], "Share committed");
        _committedVote[_shareId] = true;
        emit VoteCommitted(_shareId, _weight);
        return _weight;
    }

    /// @notice return voting weight of each confirmed share
    function weight() external view returns (uint256) {
        return _weight;
    }
}

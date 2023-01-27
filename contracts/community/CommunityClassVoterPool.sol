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

import "../../contracts/access/ConfigurableMutable.sol";
import "../../contracts/collection/AddressSet.sol";
import "../../contracts/community/ScheduledCommunityClass.sol";

/// @title interface for VoterPool
/// @notice sets the requirements for contracts implementing a VoterPool
/// @custom:type interface
interface VoterPool {
    error DuplicateRegistration(address voter);
    event RegisterVoter(address voter);
    event BurnVoter(address voter);

    /// @notice add voter to pool
    /// @param _wallet the address of the wallet
    function addVoter(address _wallet) external;

    /// @notice remove voter from the pool
    /// @param _wallet the address of the wallet
    function removeVoter(address _wallet) external;
}

/// @title CommunityClassVoterPool contract
/// @notice This contract supports voting for a specific list of wallet addresses.   Each address must be added
/// to the contract prior to voting at which time the pool must be marked as final so that it becomes impossible
/// to modify
contract CommunityClassVoterPool is ScheduledCommunityClass, ConfigurableMutable, VoterPool {
    string public constant NAME = "CommunityClassVoterPool";

    uint256 private immutable _weight;

    // whitelisted voters
    AddressSet private _voterPool;

    /// @param _voteWeight The integral weight to apply to each token held by the wallet
    /// @param _minimumQuorum the least possible quorum for any vote
    /// @param _minimumDelay the least possible vote delay
    /// @param _maximumDelay the least possible vote delay
    /// @param _minimumDuration the least possible voting duration
    /// @param _maximumDuration the least possible voting duration
    constructor(
        uint256 _voteWeight,
        uint256 _minimumQuorum,
        uint256 _minimumDelay,
        uint256 _maximumDelay,
        uint256 _minimumDuration,
        uint256 _maximumDuration
    ) ScheduledCommunityClass(_minimumQuorum, _minimumDelay, _maximumDelay, _minimumDuration, _maximumDuration) {
        _weight = _voteWeight;
        _voterPool = new AddressSet();
    }

    modifier requireValidShare(address _wallet, uint256 _shareId) {
        if (_shareId == 0 || _shareId != uint160(_wallet)) revert UnknownToken(_shareId);
        _;
    }

    modifier requireVoter(address _wallet) {
        if (!_voterPool.contains(_wallet)) revert NotVoter(_wallet);
        _;
    }

    /// @notice add a voter to the voter pool
    /// @dev only possible if not final
    /// @param _wallet the address to add
    function addVoter(address _wallet) external onlyOwner onlyMutable {
        if (!_voterPool.contains(_wallet)) {
            _voterPool.add(_wallet);
            emit RegisterVoter(_wallet);
        } else {
            revert DuplicateRegistration(_wallet);
        }
    }

    /// @notice remove a voter from the voter pool
    /// @dev only possible if not final
    /// @param _wallet the address to add
    function removeVoter(address _wallet) external onlyOwner onlyMutable {
        if (!_voterPool.erase(_wallet)) revert NotVoter(_wallet);
        emit BurnVoter(_wallet);
    }

    /// @notice test if wallet represents an allowed voter for this class
    /// @return bool true if wallet is a voter
    function isVoter(address _wallet) public view returns (bool) {
        return _voterPool.contains(_wallet);
    }

    /// @notice determine if adding a proposal is approved for this voter
    /// @dev listed voter is required for proposal
    /// @param _sender The address of the sender
    /// @return bool true if this address is approved
    function canPropose(address _sender) external view returns (bool) {
        return isVoter(_sender);
    }

    /// @notice discover an array of shareIds associated with the specified wallet
    /// @return uint256[] array in memory of share ids
    function discover(address _wallet) external view requireVoter(_wallet) onlyFinal returns (uint256[] memory) {
        uint256[] memory shareList = new uint256[](1);
        shareList[0] = uint160(_wallet);
        return shareList;
    }

    /// @notice confirm shareid is associated with wallet for voting
    /// @return uint256 The number of weighted votes confirmed
    function confirm(
        address _wallet,
        uint256 _shareId
    ) external view onlyFinal requireVoter(_wallet) requireValidShare(_wallet, _shareId) returns (uint256) {
        return _weight;
    }

    /// @notice return voting weight of each confirmed share
    function weight() external view returns (uint256) {
        return _weight;
    }

    /// @notice set the voterpool final.   No further changes may be made to the voting pool.
    function makeFinal() public override(ConfigurableMutable) onlyOwner {
        if (_voterPool.size() == 0) revert EmptyCommunity();
        super.makeFinal();
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ScheduledCommunityClass) returns (bool) {
        return interfaceId == type(VoterPool).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure virtual returns (string memory) {
        return NAME;
    }
}

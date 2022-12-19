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

import "@openzeppelin/contracts/access/Ownable.sol";

import "../contracts/GovernanceCreator.sol";
import "../contracts/Governance.sol";
import "../contracts/access/UpgradeableContract.sol";
import "../contracts/VoterClassCreator.sol";

contract System is Ownable, UpgradeableContract {
    string public constant NAME = "Governance System Creator";

    error NotGovernanceCreator(address creator);
    error NotVoterClassCreator(address creator);
    error VersionMismatch(uint256 expected, uint256 provided);

    uint256 public constant MINIMUM_DELAY = 1 hours;
    uint256 public constant MINIMUM_DURATION = 1 days;

    GovernanceCreator private _creator;

    VoterClassCreator private _classCreator;

    /// @notice System factory
    /// @param _creatorAddress address of GovernanceCreator
    /// @param _voterCreator address of VoterClassCreator
    constructor(address _creatorAddress, address _voterCreator) {
        GovernanceCreator _govCreator = GovernanceCreator(_creatorAddress);
        VoterClassCreator _voterFactory = VoterClassCreator(_voterCreator);
        if (!_govCreator.supportsInterface(type(GovernanceCreator).interfaceId)) revert NotGovernanceCreator(_creatorAddress);
        if (!_voterFactory.supportsInterface(type(VoterClassCreator).interfaceId)) revert NotVoterClassCreator(_voterCreator);
        _creator = _govCreator;
        _classCreator = _voterFactory;
    }

    /// @notice one-shot factory creation method for Collective Governance System
    /// @dev this is useful for front end code or minimizing transactions
    /// @param _name the project name
    /// @param _url the project url
    /// @param _description the project description
    /// @param _erc721 address of ERC-721 contract
    /// @param _quorum the project quorum requirement
    /// @return governanceAddress address of the new Governance contract
    /// @return storageAddress address of the storage contract
    /// @return metaAddress address of the meta contract
    function create(
        bytes32 _name,
        string memory _url,
        string memory _description,
        address _erc721,
        uint256 _quorum
    )
        external
        returns (
            address payable governanceAddress,
            address storageAddress,
            address metaAddress
        )
    {
        address erc721Class = _classCreator.createERC721(_erc721, 1);
        address supervisor = msg.sender;
        return
            _creator
                .aGovernance()
                .withSupervisor(supervisor)
                .withVoterClassAddress(erc721Class)
                .withDescription(_name, _url, _description)
                .withMinimumDelay(MINIMUM_DELAY)
                .withMinimumDuration(MINIMUM_DURATION)
                .withProjectQuorum(_quorum)
                .build();
    }

    /// @notice one-shot factory creation method for Collective Governance System
    /// @dev this is useful for front end code or minimizing transactions
    /// @param _name the project name
    /// @param _url the project url
    /// @param _description the project description
    /// @param _erc721 address of ERC-721 contract
    /// @param _quorum the project quorum requirement
    /// @param _isClosed True if closed to non voters
    /// @return governanceAddress address of the new Governance contract
    /// @return storageAddress address of the storage contract
    /// @return metaAddress address of the meta contract
    function create(
        bytes32 _name,
        string memory _url,
        string memory _description,
        address _erc721,
        uint256 _quorum,
        uint256 _minimumDelay,
        uint256 _minimumDuration,
        bool _isClosed
    )
        external
        returns (
            address payable governanceAddress,
            address storageAddress,
            address metaAddress
        )
    {
        address erc721Class = _classCreator.createERC721(_erc721, 1, _isClosed);
        address supervisor = msg.sender;
        return
            _creator
                .aGovernance()
                .withSupervisor(supervisor)
                .withVoterClassAddress(erc721Class)
                .withDescription(_name, _url, _description)
                .withMinimumDelay(_minimumDelay)
                .withMinimumDuration(_minimumDuration)
                .withProjectQuorum(_quorum)
                .build();
    }

    /// @notice System factory upgrade
    /// @dev onlyOwner
    /// @param _creatorAddress address of GovernanceCreator
    /// @param _voterCreator address of VoterClassCreator
    function upgrade(address _creatorAddress, address _voterCreator) external onlyOwner {
        GovernanceCreator _govCreator = GovernanceCreator(_creatorAddress);
        VoterClassCreator _voterFactory = VoterClassCreator(_voterCreator);
        if (!_govCreator.supportsInterface(type(GovernanceCreator).interfaceId)) revert NotGovernanceCreator(_creatorAddress);
        if (!_voterFactory.supportsInterface(type(VoterClassCreator).interfaceId)) revert NotVoterClassCreator(_voterCreator);
        if (_govCreator.version() < _voterFactory.version())
            revert VersionMismatch(_voterFactory.version(), _govCreator.version());
        _creator = _govCreator;
        _classCreator = _voterFactory;
    }

    // @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure virtual returns (string memory) {
        return NAME;
    }
}

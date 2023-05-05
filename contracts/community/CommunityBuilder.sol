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

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import { Constant } from "../../contracts/Constant.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";
import { VersionedContract } from "../../contracts/access/VersionedContract.sol";
import { AddressCollection } from "../../contracts/collection/AddressSet.sol";
import { WeightedCommunityClass } from "../../contracts/community/CommunityClass.sol";
import { WeightedClassFactory, ProjectClassFactory, TokenClassFactory } from "../../contracts/community/CommunityFactory.sol";
import { CommunityClassVoterPool } from "../../contracts/community/CommunityClassVoterPool.sol";
import { CommunityClassOpenVote } from "../../contracts/community/CommunityClassOpenVote.sol";
import { CommunityClassERC721 } from "../../contracts/community/CommunityClassERC721.sol";
import { CommunityClassClosedERC721 } from "../../contracts/community/CommunityClassClosedERC721.sol";
import { CommunityClassERC20 } from "../../contracts/community/CommunityClassERC20.sol";
import { CommunityClassClosedERC20 } from "../../contracts/community/CommunityClassClosedERC20.sol";

import { OwnableInitializable } from "../../contracts/access/OwnableInitializable.sol";

/// @title CommunityBuilder
/// @notice This builder is for creating a community class for use with the Collective
/// Governance contract
contract CommunityBuilder is VersionedContract, ERC165, OwnableInitializable, UUPSUpgradeable, Initializable {
    string public constant NAME = "community builder";
    uint256 public constant DEFAULT_WEIGHT = 1;

    error CommunityTypeRequired();
    error CommunityTypeChange();
    error ProjectTokenRequired(address tokenAddress);
    error TokenThresholdRequired(uint256 tokenThreshold);
    error NonZeroWeightRequired(uint256 weight);
    error NonZeroQuorumRequired(uint256 quorum);
    error VoterRequired();
    error VoterPoolRequired();

    event UpgradeAuthorized(address sender, address owner);
    event Initialized(address weightedClassFactory, address tokenClassFactory);
    event Upgraded(address weightedClassFactory, address tokenClassFactory, uint8 version);

    event CommunityClassInitialized(address sender);
    event CommunityClassType(CommunityType communityType);
    event CommunityVoter(address voter);
    event CommunityClassWeight(uint256 weight);
    event CommunityClassQuorum(uint256 quorum);
    event CommunityClassMinimumVoteDelay(uint256 delay);
    event CommunityClassMaximumVoteDelay(uint256 delay);
    event CommunityClassMinimumVoteDuration(uint256 duration);
    event CommunityClassMaximumVoteDuration(uint256 duration);
    event CommunityClassGasUsedRebate(uint256 gasRebate);
    event CommunityClassBaseFeeRebate(uint256 baseFeeRebate);
    event CommunityClassSupervisor(address supervisor);
    event CommunityClassCreated(address class);

    enum CommunityType {
        NONE,
        OPEN,
        POOL,
        ERC721,
        ERC721_CLOSED,
        ERC20,
        ERC20_CLOSED
    }

    struct CommunityProperties {
        uint256 weight;
        uint256 minimumProjectQuorum;
        uint256 minimumVoteDelay;
        uint256 maximumVoteDelay;
        uint256 minimumVoteDuration;
        uint256 maximumVoteDuration;
        uint256 maximumGasUsedRebate;
        uint256 maximumBaseFeeRebate;
        AddressCollection communitySupervisor;
        CommunityType communityType;
        address projectToken;
        uint256 tokenThreshold;
        AddressCollection poolSet;
    }

    mapping(address => CommunityProperties) private _buildMap;

    WeightedClassFactory private _weightedFactory;

    ProjectClassFactory private _projectFactory;

    TokenClassFactory private _tokenFactory;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _weighted, address _project, address _token) public initializer {
        ownerInitialize(msg.sender);
        _weightedFactory = WeightedClassFactory(_weighted);
        _projectFactory = ProjectClassFactory(_project);
        _tokenFactory = TokenClassFactory(_token);
        emit Initialized(_weighted, _project);
    }

    function upgrade(
        address _weighted,
        address _project,
        address _token,
        uint8 _version
    ) public onlyOwner reinitializer(_version) {
        _weightedFactory = WeightedClassFactory(_weighted);
        _projectFactory = ProjectClassFactory(_project);
        _tokenFactory = TokenClassFactory(_token);
        emit Upgraded(_weighted, _project, _version);
    }

    modifier requirePool() {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        if (_properties.communityType != CommunityType.POOL) revert VoterPoolRequired();
        _;
    }

    modifier requireNone() {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        if (_properties.communityType != CommunityType.NONE) revert CommunityTypeChange();
        _;
    }

    /**
     * reset the community class builder for this address
     *
     * @return CommunityBuilder - this contract
     */
    function aCommunity() external returns (CommunityBuilder) {
        clear(msg.sender);
        emit CommunityClassInitialized(msg.sender);
        return this;
    }

    /**
     * build an open community
     *
     * @return CommunityBuilder - this contract
     */
    function asOpenCommunity() external requireNone returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.communityType = CommunityType.OPEN;
        emit CommunityClassType(CommunityType.OPEN);
        return this;
    }

    /**
     * build a pool community
     *
     * @return CommunityBuilder - this contract
     */
    function asPoolCommunity() external requireNone returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.communityType = CommunityType.POOL;
        _properties.poolSet = Constant.createAddressSet();
        emit CommunityClassType(CommunityType.POOL);
        return this;
    }

    /**
     * build ERC-721 community
     *
     * @param project the token contract address
     *
     * @return CommunityBuilder - this contract
     */
    function asErc721Community(address project) external requireNone returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.communityType = CommunityType.ERC721;
        _properties.projectToken = project;
        emit CommunityClassType(CommunityType.ERC721);
        return this;
    }

    /**
     * build Closed ERC-721 community
     *
     * @dev community is closed to external proposals
     *
     * @param project the token contract address
     * @param tokenThreshold the number of tokens required to propose
     *
     * @return CommunityBuilder - this contract
     */
    function asClosedErc721Community(address project, uint256 tokenThreshold) external requireNone returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.communityType = CommunityType.ERC721_CLOSED;
        _properties.projectToken = project;
        _properties.tokenThreshold = tokenThreshold;
        emit CommunityClassType(CommunityType.ERC721_CLOSED);
        return this;
    }

    /**
     * build ERC-20 community
     *
     * @param project the token contract address
     *
     * @return CommunityBuilder - this contract
     */
    function asErc20Community(address project) external requireNone returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.communityType = CommunityType.ERC20;
        _properties.projectToken = project;
        emit CommunityClassType(CommunityType.ERC20);
        return this;
    }

    /**
     * build Closed ERC-20 community
     *
     * @dev community is closed to external proposals
     *
     * @param project the token contract address
     * @param tokenThreshold the number of tokens required to propose
     *
     * @return CommunityBuilder - this contract
     */
    function asClosedErc20Community(address project, uint256 tokenThreshold) external requireNone returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.communityType = CommunityType.ERC20_CLOSED;
        _properties.projectToken = project;
        _properties.tokenThreshold = tokenThreshold;
        emit CommunityClassType(CommunityType.ERC20_CLOSED);
        return this;
    }

    /**
     * append a voter for a pool community
     *
     * @param voter the wallet address
     *
     * @return CommunityBuilder - this contract
     */
    function withVoter(address voter) external requirePool returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.poolSet.add(voter);
        emit CommunityVoter(voter);
        return this;
    }

    /**
     * set the voting weight for each authorized voter
     *
     * @param _weight the voting weight
     *
     * @return CommunityBuilder - this contract
     */
    function withWeight(uint256 _weight) external returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.weight = _weight;
        emit CommunityClassWeight(_weight);
        return this;
    }

    /**
     * set the minimum quorum for this community
     *
     * @param _quorum the minimum quorum
     *
     * @return CommunityBuilder - this contract
     */
    function withQuorum(uint256 _quorum) external returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.minimumProjectQuorum = _quorum;
        emit CommunityClassQuorum(_quorum);
        return this;
    }

    /**
     * set the minimum vote delay for the community
     *
     * @param _delay - minimum vote delay in Ethereum (epoch) seconds
     *
     * @return CommunityBuilder - this contract
     */
    function withMinimumVoteDelay(uint256 _delay) external returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.minimumVoteDelay = _delay;
        emit CommunityClassMinimumVoteDelay(_delay);
        return this;
    }

    /**
     * set the maximum vote delay for the community
     *
     * @param _delay - maximum vote delay in Ethereum (epoch) seconds
     *
     * @return CommunityBuilder - this contract
     */
    function withMaximumVoteDelay(uint256 _delay) external returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.maximumVoteDelay = _delay;
        emit CommunityClassMaximumVoteDelay(_delay);
        return this;
    }

    /**
     * set the minimum vote duration for the community
     *
     * @param _duration - minimum vote duration in Ethereum (epoch) seconds
     *
     * @return CommunityBuilder - this contract
     */
    function withMinimumVoteDuration(uint256 _duration) external returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.minimumVoteDuration = _duration;
        emit CommunityClassMinimumVoteDuration(_duration);
        return this;
    }

    /**
     * set the maximum vote duration for the community
     *
     * @param _duration - maximum vote duration in Ethereum (epoch) seconds
     *
     * @return CommunityBuilder - this contract
     */
    function withMaximumVoteDuration(uint256 _duration) external returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.maximumVoteDuration = _duration;
        emit CommunityClassMaximumVoteDuration(_duration);
        return this;
    }

    /**
     * set the maximum gas used rebate
     *
     * @param _gasRebate the gas used rebate
     *
     * @return CommunityBuilder - this contract
     */
    function withMaximumGasUsedRebate(uint256 _gasRebate) external returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.maximumGasUsedRebate = _gasRebate;
        emit CommunityClassGasUsedRebate(_gasRebate);
        return this;
    }

    /**
     * set the maximum base fee rebate
     *
     * @param _baseFeeRebate the base fee rebate
     *
     * @return CommunityBuilder - this contract
     */
    function withMaximumBaseFeeRebate(uint256 _baseFeeRebate) external returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.maximumBaseFeeRebate = _baseFeeRebate;
        emit CommunityClassBaseFeeRebate(_baseFeeRebate);
        return this;
    }

    /**
     * add community supervisor
     *
     * @param _supervisor the supervisor address
     *
     * @return CommunityBuilder - this contract
     */
    function withCommunitySupervisor(address _supervisor) external returns (CommunityBuilder) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        _properties.communitySupervisor.add(_supervisor);
        emit CommunityClassSupervisor(_supervisor);
        return this;
    }

    /**
     * Build the contract with the configured settings.
     *
     * @return address - The address of the newly created contract
     */
    function build() public returns (address payable) {
        CommunityProperties storage _properties = _buildMap[msg.sender];
        WeightedCommunityClass _proxy;
        if (_properties.weight < 1) revert NonZeroWeightRequired(_properties.weight);
        if (_properties.minimumProjectQuorum < 1) revert NonZeroQuorumRequired(_properties.minimumProjectQuorum);
        if (_properties.communityType == CommunityType.ERC721_CLOSED) {
            if (_properties.projectToken == address(0x0)) revert ProjectTokenRequired(_properties.projectToken);
            if (_properties.tokenThreshold == 0) revert TokenThresholdRequired(_properties.tokenThreshold);
            _proxy = _projectFactory.createClosedErc721(
                _properties.projectToken,
                _properties.tokenThreshold,
                _properties.weight,
                _properties.minimumProjectQuorum,
                _properties.minimumVoteDelay,
                _properties.maximumVoteDelay,
                _properties.minimumVoteDuration,
                _properties.maximumVoteDuration,
                _properties.maximumGasUsedRebate,
                _properties.maximumBaseFeeRebate,
                _properties.communitySupervisor
            );
        } else if (_properties.communityType == CommunityType.ERC20_CLOSED) {
            if (_properties.projectToken == address(0x0)) revert ProjectTokenRequired(_properties.projectToken);
            if (_properties.tokenThreshold == 0) revert TokenThresholdRequired(_properties.tokenThreshold);
            _proxy = _tokenFactory.createClosedErc20(
                _properties.projectToken,
                _properties.tokenThreshold,
                _properties.weight,
                _properties.minimumProjectQuorum,
                _properties.minimumVoteDelay,
                _properties.maximumVoteDelay,
                _properties.minimumVoteDuration,
                _properties.maximumVoteDuration,
                _properties.maximumGasUsedRebate,
                _properties.maximumBaseFeeRebate,
                _properties.communitySupervisor
            );
        } else if (_properties.communityType == CommunityType.ERC721) {
            if (_properties.projectToken == address(0x0)) revert ProjectTokenRequired(_properties.projectToken);
            _proxy = _projectFactory.createErc721(
                _properties.projectToken,
                _properties.weight,
                _properties.minimumProjectQuorum,
                _properties.minimumVoteDelay,
                _properties.maximumVoteDelay,
                _properties.minimumVoteDuration,
                _properties.maximumVoteDuration,
                _properties.maximumGasUsedRebate,
                _properties.maximumBaseFeeRebate,
                _properties.communitySupervisor
            );
        } else if (_properties.communityType == CommunityType.ERC20) {
            if (_properties.projectToken == address(0x0)) revert ProjectTokenRequired(_properties.projectToken);
            _proxy = _tokenFactory.createErc20(
                _properties.projectToken,
                _properties.weight,
                _properties.minimumProjectQuorum,
                _properties.minimumVoteDelay,
                _properties.maximumVoteDelay,
                _properties.minimumVoteDuration,
                _properties.maximumVoteDuration,
                _properties.maximumGasUsedRebate,
                _properties.maximumBaseFeeRebate,
                _properties.communitySupervisor
            );
        } else if (_properties.communityType == CommunityType.OPEN) {
            _proxy = _weightedFactory.createOpenVote(
                _properties.weight,
                _properties.minimumProjectQuorum,
                _properties.minimumVoteDelay,
                _properties.maximumVoteDelay,
                _properties.minimumVoteDuration,
                _properties.maximumVoteDuration,
                _properties.maximumGasUsedRebate,
                _properties.maximumBaseFeeRebate,
                _properties.communitySupervisor
            );
        } else if (_properties.communityType == CommunityType.POOL) {
            CommunityClassVoterPool _pool = _weightedFactory.createVoterPool(
                _properties.weight,
                _properties.minimumProjectQuorum,
                _properties.minimumVoteDelay,
                _properties.maximumVoteDelay,
                _properties.minimumVoteDuration,
                _properties.maximumVoteDuration,
                _properties.maximumGasUsedRebate,
                _properties.maximumBaseFeeRebate,
                _properties.communitySupervisor
            );
            if (_properties.poolSet.size() == 0) revert VoterRequired();
            for (uint256 i = 1; i <= _properties.poolSet.size(); ++i) {
                _pool.addVoter(_properties.poolSet.get(i));
            }
            _pool.makeFinal();
            _proxy = _pool;
        } else {
            revert CommunityTypeRequired();
        }

        address payable proxyAddress = payable(address(_proxy));
        OwnableInitializable _ownable = OwnableInitializable(proxyAddress);
        _ownable.transferOwnership(msg.sender);
        emit CommunityClassCreated(proxyAddress);
        return proxyAddress;
    }

    function name() external pure virtual returns (string memory) {
        return NAME;
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return
            interfaceId == type(Versioned).interfaceId ||
            interfaceId == type(OwnableInitializable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice remove storage used by builder
    function reset() external {
        clear(msg.sender);
        delete _buildMap[msg.sender];
    }

    function clear(address sender) internal {
        CommunityProperties storage _properties = _buildMap[sender];
        _properties.weight = DEFAULT_WEIGHT;
        _properties.communityType = CommunityType.NONE;
        _properties.minimumProjectQuorum = 0;
        _properties.minimumVoteDelay = Constant.MINIMUM_VOTE_DELAY;
        _properties.maximumVoteDelay = Constant.MAXIMUM_VOTE_DELAY;
        _properties.minimumVoteDuration = Constant.MINIMUM_VOTE_DURATION;
        _properties.maximumVoteDuration = Constant.MAXIMUM_VOTE_DURATION;
        _properties.maximumGasUsedRebate = Constant.MAXIMUM_REBATE_GAS_USED;
        _properties.maximumBaseFeeRebate = Constant.MAXIMUM_REBATE_BASE_FEE;
        _properties.communitySupervisor = Constant.createAddressSet();
    }

    /// see UUPSUpgradeable
    function _authorizeUpgrade(address _caller) internal virtual override(UUPSUpgradeable) onlyOwner {
        emit UpgradeAuthorized(_caller, owner());
    }
}

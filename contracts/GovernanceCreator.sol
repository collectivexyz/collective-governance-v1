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

import "../contracts/CommunityClass.sol";
import "../contracts/access/Versioned.sol";

/// @title Governance GovernanceCreator interface
/// @notice Requirements for Governance GovernanceCreator implementation
/// @custom:type interface
interface GovernanceCreator is Versioned, IERC165 {
    error StorageFactoryRequired(address _storage);
    error MetaStorageFactoryRequired(address meta);
    error GovernanceFactoryRequired(address governance);
    error StorageVersionMismatch(address _storage, uint32 expected, uint32 provided);
    error MetaVersionMismatch(address meta, uint32 expected, uint32 provided);
    error CommunityClassRequired(address voterClass);

    /// @notice new contract created
    event GovernanceContractCreated(
        address creator,
        bytes32 name,
        address _storage,
        address metaStorage,
        address timeLock,
        address governance
    );
    /// @notice initialized local state for sender
    event GovernanceContractInitialized(address creator);
    /// @notice add supervisor
    event GovernanceContractWithSupervisor(address creator, address supervisor);
    /// @notice set voterclass
    event GovernanceContractwithCommunityClass(address creator, address class, string name, uint32 version);
    /// @notice set minimum delay
    event GovernanceContractWithMinimumVoteDelay(address creator, uint256 delay);
    /// @notice set maximum delay
    event GovernanceContractWithMaximumVoteDelay(address creator, uint256 delay);
    /// @notice set minimum duration
    event GovernanceContractWithMinimumDuration(address creator, uint256 duration);
    /// @notice set maximum duration
    event GovernanceContractWithMaximumDuration(address creator, uint256 duration);
    /// @notice set minimum quorum
    event GovernanceContractWithMinimumQuorum(address creator, uint256 quorum);
    /// @notice add name
    event GovernanceContractWithName(address creator, bytes32 name);
    /// @notice add url
    event GovernanceContractWithUrl(address creator, string url);
    /// @notice add description
    event GovernanceContractWithDescription(address creator, string description);

    /// @notice The timelock created
    event TimeLockCreated(address timeLock, uint256 lockTime);

    /// @notice settings state used by builder for creating Governance contract
    struct GovernanceProperties {
        /// @notice community name
        bytes32 name;
        /// @notice community url
        string url;
        /// @notice community description
        string description;
        /// @notice max gas used for rebate
        uint256 maxGasUsed;
        /// @notice max base fee for rebate
        uint256 maxBaseFee;
        /// @notice array of supervisors
        address[] supervisorList;
        /// @notice voting class
        CommunityClass class;
    }

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure returns (string memory);

    /// @notice initialize and create a new builder context for this sender
    /// @return GovernanceCreator this contract
    function aGovernance() external returns (GovernanceCreator);

    /// @notice add a supervisor to the supervisor list for the next constructed contract contract
    /// @dev maintains an internal list which increases with every call
    /// @param _supervisor the address of the wallet representing a supervisor for the project
    /// @return GovernanceCreator this contract
    function withSupervisor(address _supervisor) external returns (GovernanceCreator);

    /// @notice set the CommunityClass to be used for the next constructed contract
    /// @param _classAddress the address of the CommunityClass contract
    /// @return GovernanceCreator this contract
    function withCommunityClassAddress(address _classAddress) external returns (GovernanceCreator);

    /// @notice set the VoterClass to be used for the next constructed contract
    /// @dev the type safe VoterClass for use within Solidity code
    /// @param _class the address of the VoterClass contract
    /// @return GovernanceCreator this contract
    function withCommunityClass(CommunityClass _class) external returns (GovernanceCreator);

    /// @notice set the community information
    /// @dev this helper calls withName, withUrl and WithDescription
    /// @param _name the name
    /// @param _url the url
    /// @param _description the description
    /// @return GovernanceCreator this contract
    function withDescription(
        bytes32 _name,
        string memory _url,
        string memory _description
    ) external returns (GovernanceCreator);

    /// @notice set the community name
    /// @param _name the name
    /// @return GovernanceCreator this contract
    function withName(bytes32 _name) external returns (GovernanceCreator);

    /// @notice set the community url
    /// @param _url the url
    /// @return GovernanceCreator this contract
    function withUrl(string memory _url) external returns (GovernanceCreator);

    /// @notice set the community description
    /// @dev limit 1k
    /// @param _description the description
    /// @return GovernanceCreator this contract
    function withDescription(string memory _description) external returns (GovernanceCreator);

    /// @notice setup gas rebate parameters
    /// @param _gasUsed the maximum gas used for rebate
    /// @param _baseFee the maximum base fee for rebate
    /// @return GovernanceCreator this contract
    function withGasRebate(uint256 _gasUsed, uint256 _baseFee) external returns (GovernanceCreator);

    /// @notice build the specified contract
    /// @dev Contructs a new contract and may require a large gas fee.  Build does not reinitialize context.
    /// If you wish to reset the settings call reset or aGovernance directly.
    /// @return governanceAddress address of the new Governance contract
    /// @return storageAddress address of the storage contract
    /// @return metaAddress address of the meta contract
    function build()
        external
        returns (
            address payable governanceAddress,
            address storageAddress,
            address metaAddress
        );

    /// @notice clear and reset resources associated with sender build requests
    function reset() external;

    /// @notice identify a contract that was created by this builder
    /// @return bool True if contract was created by this builder
    function contractRegistered(address _contract) external view returns (bool);

    /// @notice upgrade factories
    /// @dev owner required
    function upgrade(
        address _governance,
        address _storage,
        address _meta
    ) external;
}

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
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import { OwnableInitializable } from "../../contracts/access/OwnableInitializable.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";
import { VersionedContract } from "../../contracts/access/VersionedContract.sol";
import { Constant } from "../../contracts/Constant.sol";
import { AddressCollection } from "../../contracts/collection/AddressSet.sol";
import { Treasury } from "../../contracts/treasury/Treasury.sol";

/**
 * @notice TreasuryBuilder is designed to help building up an on-chain treasury.
 */
contract TreasuryBuilder is VersionedContract, ERC165, OwnableInitializable, UUPSUpgradeable, Initializable {
    string public constant NAME = "treasury builder";

    error AtLeastOneApprovalIsRequired(address sender);
    error TimeLockDelayIsNotPermitted(address sender, uint256 timeLockTime, uint256 timeLockMinimum);
    error RequiresAdditionalApprovers(address sender, uint256 numberOfApprovers, uint256 requiredNumber);

    event Initialized();
    /// settings initialized
    event TreasuryInitialized(address sender);
    /// approver added
    event TreasuryApprover(address sender, address approver);
    /// required approvers set
    event TreasuryMinimumRequirement(address sender, uint256 requirement);
    /// timelock time is set
    event TreasuryTimeLock(address sender, uint256 timelockDelay);
    /// build successful
    event TreasuryCreated(address sender, address instance);

    /// UUPS authorization
    event UpgradeAuthorized(address caller, address owner);

    /// @notice the properties of a treasury as it is being built
    struct TreasuryProperties {
        /// @notice the number of approvers required for a transaction
        uint256 approvalRequirement;
        /// @notice the minumum timelock time
        uint256 timeLockTime;
        /// @notice the set of all allowed approvers
        AddressCollection approver;
    }

    mapping(address => TreasuryProperties) private _treasuryMap;

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        ownerInitialize(msg.sender);
        emit Initialized();
    }

    /**
     * @notice begin the process of building the treasury by
     * creating a new mapping for sender
     * @return TreasuryBuilder this contract
     */
    function aTreasury() external returns (TreasuryBuilder) {
        clear();
        emit TreasuryInitialized(msg.sender);
        return this;
    }

    /**
     * @notice set the approval requirement
     * @param _requirement The minimum requirement
     * @return TreasuryBuilder this contract
     */
    function withMinimumApprovalRequirement(uint256 _requirement) external returns (TreasuryBuilder) {
        TreasuryProperties storage _properties = _treasuryMap[msg.sender];
        _properties.approvalRequirement = _requirement;
        emit TreasuryMinimumRequirement(msg.sender, _requirement);
        return this;
    }

    /**
     * @notice set the minimum timelock delay
     * @param _timelockDelay the minimum delay
     * @return TreasuryBuilder this contract
     */
    function withTimeLockDelay(uint256 _timelockDelay) external returns (TreasuryBuilder) {
        TreasuryProperties storage _properties = _treasuryMap[msg.sender];
        _properties.timeLockTime = _timelockDelay;
        emit TreasuryTimeLock(msg.sender, _timelockDelay);
        return this;
    }

    /**
     * @notice add an approver
     * @param _approver the approver address
     */
    function withApprover(address _approver) external returns (TreasuryBuilder) {
        TreasuryProperties storage _properties = _treasuryMap[msg.sender];
        _properties.approver.add(_approver);
        emit TreasuryApprover(msg.sender, _approver);
        return this;
    }

    function build() external returns (address payable) {
        TreasuryProperties memory _properties = _treasuryMap[msg.sender];
        if (_properties.approvalRequirement < 1) revert AtLeastOneApprovalIsRequired(msg.sender);
        if (_properties.timeLockTime < Constant.TIMELOCK_MINIMUM_DELAY)
            revert TimeLockDelayIsNotPermitted(msg.sender, _properties.timeLockTime, Constant.TIMELOCK_MINIMUM_DELAY);
        if (_properties.timeLockTime > Constant.TIMELOCK_MAXIMUM_DELAY)
            revert TimeLockDelayIsNotPermitted(msg.sender, _properties.timeLockTime, Constant.TIMELOCK_MAXIMUM_DELAY);
        if (_properties.approver.size() < _properties.approvalRequirement)
            revert RequiresAdditionalApprovers(msg.sender, _properties.approver.size(), _properties.approvalRequirement);
        Treasury _instance = new Treasury(_properties.approvalRequirement, _properties.timeLockTime, _properties.approver);
        emit TreasuryCreated(msg.sender, address(_instance));
        return payable(address(_instance));
    }

    // @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure virtual returns (string memory) {
        return NAME;
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return
            interfaceId == type(Ownable).interfaceId ||
            interfaceId == type(Versioned).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function clear() public {
        TreasuryProperties storage _properties = _treasuryMap[msg.sender];

        _properties.approvalRequirement = 0;
        _properties.timeLockTime = Constant.TIMELOCK_MINIMUM_DELAY;
        _properties.approver = Constant.createAddressSet();
    }

    function reset() external {
        clear();
        delete _treasuryMap[msg.sender];
    }

    /// see UUPSUpgradeable
    function _authorizeUpgrade(address _caller) internal virtual override(UUPSUpgradeable) onlyOwner {
        emit UpgradeAuthorized(_caller, owner());
    }
}

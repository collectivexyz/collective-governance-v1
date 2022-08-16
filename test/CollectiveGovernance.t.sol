// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC721.sol";

import "forge-std/Test.sol";

import "../contracts/Storage.sol";
import "../contracts/GovernanceStorage.sol";
import "../contracts/VoteStrategy.sol";
import "../contracts/ElectorVoterPoolStrategy.sol";
import "../contracts/Governance.sol";
import "../contracts/CollectiveGovernance.sol";

import "./MockERC721.sol";

contract CollectiveGovernanceTest is Test {
    Governance private governance;
    Storage private _storage;

    address public immutable owner = msg.sender;
    address public immutable someoneElse = address(0x123);
    address public immutable voter = address(0xffee);
    uint32 private version;

    function setUp() public {
        governance = new CollectiveGovernance();
        _storage = new GovernanceStorage();
        version = new ElectorVoterPoolStrategy(_storage).version();
    }

    function testGetVoteStrategy() public {
        uint32 strategyVersion = governance.getCurrentStrategyVersion();
        assertEq(version, strategyVersion);
    }

    function testGetStorageAddress() public {
        address storageAddress = governance.getStorageAddress();
        assertFalse(storageAddress == address(0));
    }
}

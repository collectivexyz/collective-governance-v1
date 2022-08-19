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
    IERC721 private erc721;

    address public immutable owner = msg.sender;
    address public immutable someoneElse = address(0x123);
    address public immutable voter = address(0xffee);
    address public immutable nonvoter = address(0xffff);
    uint256 public immutable PROPOSAL_ID = 1;
    uint256 public immutable TOKEN_ID = 77;
    uint32 private version;

    function setUp() public {
        governance = new CollectiveGovernance();
        version = new ElectorVoterPoolStrategy(new GovernanceStorage()).version();
        erc721 = new MockERC721(voter, TOKEN_ID);
    }

    function testGetVoteStrategy() public {
        uint32 strategyVersion = governance.getStrategyVersion();
        assertEq(version, strategyVersion);
    }

    function testName() public {
        assertEq(governance.name(), "collective.xyz governance");
    }

    function testVersion() public {
        assertEq(governance.version(), 1);
    }

    function testPropose() public {
        uint256 id = governance.propose();
        assertEq(id, PROPOSAL_ID);
    }

    function testConfigure() public {
        vm.startPrank(owner, owner);
        uint256 id = governance.propose();
        governance.configure(id, 2, address(erc721), 2);
        vm.stopPrank();
        assertTrue(governance.isOpen(id));
        assertEq(governance.getQuorumRequired(id), 2);
        assertTrue(governance.isOpen(id));
    }

    function testCastSimpleVote() public {
        vm.startPrank(owner, owner);
        uint256 id = governance.propose();
        governance.configure(id, 2, address(erc721), 2);
        vm.stopPrank();
        vm.prank(voter);
        governance.voteFor(id);
    }

    function testFailNonVoter() public {
        vm.startPrank(owner, owner);
        uint256 id = governance.propose();
        governance.configure(id, 2, address(erc721), 2);
        vm.stopPrank();
        vm.prank(nonvoter);
        governance.voteFor(id);
    }

    function testVoteAgainst() public {
        vm.startPrank(owner, owner);
        uint256 id = governance.propose();
        governance.configure(id, 2, address(erc721), 2);
        vm.stopPrank();
        vm.prank(voter);
        governance.voteAgainst(id);
    }

    function testFailVoteAgainstNonVoter() public {
        vm.startPrank(owner, owner);
        uint256 id = governance.propose();
        governance.configure(id, 2, address(erc721), 2);
        vm.stopPrank();
        vm.prank(nonvoter);
        governance.voteAgainst(id);
    }

    function testAbstain() public {
        vm.startPrank(owner, owner);
        uint256 id = governance.propose();
        governance.configure(id, 2, address(erc721), 2);
        vm.stopPrank();
        vm.prank(voter);
        governance.abstainFromVote(id);
    }

    function testFailAbstentionNonVoter() public {
        vm.startPrank(owner, owner);
        uint256 id = governance.propose();
        governance.configure(id, 2, address(erc721), 2);
        vm.stopPrank();
        vm.prank(nonvoter);
        governance.abstainFromVote(id);
    }
}

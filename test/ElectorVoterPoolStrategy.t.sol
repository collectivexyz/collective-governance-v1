// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/ElectorVoterPoolStrategy.sol";
import "../contracts/VoterClass.sol";
import "./MockERC721.sol";

contract ElectorVoterPoolTest is Test {
    ElectorVoterPoolStrategy elector;

    address public immutable owner = msg.sender;
    address public immutable supervisor = address(0x123);
    address public immutable nonSupervisor = address(0x123eee);
    address public immutable voter1 = address(0xfff1);
    address public immutable voter2 = address(0xfff2);
    uint256 public immutable NONE = 0;
    uint256 public immutable PROPOSAL_ID = 1;

    function setUp() public {
        elector = new ElectorVoterPoolStrategy();
        elector.initializeProposal(elector);
    }

    function testOpenVoting() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.setQuorumThreshold(PROPOSAL_ID, 75);
        elector.makeReady(PROPOSAL_ID);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        elector.isOpen(PROPOSAL_ID);
    }

    function testFailOpenVotingRequiresReady() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        elector.openVoting(PROPOSAL_ID);
    }

    function testFailAddVoterIfOpen() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        elector.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVoting(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
    }

    function testFailBurnVoterIfOpen() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(supervisor);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        elector.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVoting(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.burnVoter(PROPOSAL_ID, voter1);
    }

    function testFailOwnerOpenVoting() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        elector.makeReady(PROPOSAL_ID);
        elector.openVoting(PROPOSAL_ID);
    }

    function testFailOwnerEndVoting() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        elector.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVoting(PROPOSAL_ID);
        vm.prank(owner);
        elector.endVoting(PROPOSAL_ID);
    }

    function testFailDoubleOpenVoting() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        elector.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVoting(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVoting(PROPOSAL_ID);
    }

    function testFailEndVotingWhenNotOpen() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        elector.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.endVoting(PROPOSAL_ID);
    }

    function testFailOwnerCastVote() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        elector.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVoting(PROPOSAL_ID);
        elector.voteFor(PROPOSAL_ID);
    }

    function testFailSupervisorCastVote() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        elector.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVoting(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.voteFor(PROPOSAL_ID);
    }

    function testCastOneVote() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.makeReady(PROPOSAL_ID);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        assertEq(elector.forVotes(PROPOSAL_ID), 1);
        assertEq(elector.totalParticipation(PROPOSAL_ID), 1);
    }

    function testCastOneVoteFromAll() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoterClassOpenVoting(PROPOSAL_ID);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.makeReady(PROPOSAL_ID);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        assertEq(elector.totalParticipation(PROPOSAL_ID), 1);
    }

    function testCastVoteFromERC721() public {
        uint256 tokenId = 0x71;
        IERC721 token = new MockERC721(voter2, tokenId);
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoterClassERC721(PROPOSAL_ID, address(token));
        elector.setQuorumThreshold(PROPOSAL_ID, 1);
        elector.makeReady(PROPOSAL_ID);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter2);
        elector.voteFor(PROPOSAL_ID);
        assertEq(elector.forVotes(PROPOSAL_ID), 1);
        assertEq(elector.againstVotes(PROPOSAL_ID), 0);
        assertEq(elector.abstentionCount(PROPOSAL_ID), 0);
        assertEq(elector.totalParticipation(PROPOSAL_ID), 1);
    }

    function testFailCastOneVoteWithBurnedClass() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoterClassOpenVoting(PROPOSAL_ID);
        elector.burnVoterClass(PROPOSAL_ID);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.makeReady(PROPOSAL_ID);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
    }

    function testFailCastVoteNotOpened() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
    }

    function testFailCastTwoVote() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
    }

    function testVoterMayChangeTheirMind() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.enableUndoVote(PROPOSAL_ID);
        elector.registerVoter(PROPOSAL_ID, voter1);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.makeReady(PROPOSAL_ID);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        assertEq(elector.totalParticipation(PROPOSAL_ID), 1);
        vm.prank(voter1);
        elector.undoVote(PROPOSAL_ID);
        assertEq(elector.totalParticipation(PROPOSAL_ID), NONE);
    }

    function testVoterMayOnlyUndoPreviousVote() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.enableUndoVote(PROPOSAL_ID);
        elector.registerVoter(PROPOSAL_ID, voter1);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.makeReady(PROPOSAL_ID);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.expectRevert("Voter required");
        elector.undoVote(PROPOSAL_ID);
    }

    function testFailUndoVoteNotDefaultEnabled() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.expectRevert();
        elector.undoVote(PROPOSAL_ID);
    }

    function testFailSupervisorMayNotUndoVote() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(supervisor);
        elector.openVoting(PROPOSAL_ID);
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.undoVote(PROPOSAL_ID);
    }

    function testFailOwnerMayNotUndoVote() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(owner);
        elector.undoVote(PROPOSAL_ID);
    }

    function testMeasureHasPassed() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        elector.registerVoter(PROPOSAL_ID, voter2);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.makeReady(PROPOSAL_ID);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(voter2);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.endVoting(PROPOSAL_ID);
        assertTrue(elector.getVoteSucceeded(PROPOSAL_ID));
    }

    function testMeasureFailed() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        elector.registerVoter(PROPOSAL_ID, voter2);
        elector.setQuorumThreshold(PROPOSAL_ID, 76);
        elector.makeReady(PROPOSAL_ID);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(voter2);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.endVoting(PROPOSAL_ID);
        assertFalse(elector.getVoteSucceeded(PROPOSAL_ID));
    }

    function testFailgetVoteSucceededOnOpenMeasure() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(supervisor);
        elector.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVoting(PROPOSAL_ID);
        elector.getVoteSucceeded(PROPOSAL_ID);
    }

    function testFailMeasureIsVeto() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        elector.registerVoter(PROPOSAL_ID, voter2);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.makeReady(PROPOSAL_ID);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(voter2);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.veto(PROPOSAL_ID);
        assertTrue(elector.isVeto(PROPOSAL_ID));
        vm.prank(supervisor);
        elector.endVoting(PROPOSAL_ID);
        elector.getVoteSucceeded(PROPOSAL_ID);
    }

    function testFailMeasureLateVeto() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        elector.registerVoter(PROPOSAL_ID, voter2);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.makeReady(PROPOSAL_ID);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(voter2);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.endVoting(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.veto(PROPOSAL_ID);
    }

    function testFailVoteAgainst() public {
        elector.voteAgainst(PROPOSAL_ID);
    }

    function testFailAbstainFromVote() public {
        elector.abstainFromVote(PROPOSAL_ID);
    }

    function testCastAgainstVote() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.makeReady(PROPOSAL_ID);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteAgainst(PROPOSAL_ID);
        assertEq(elector.forVotes(PROPOSAL_ID), 0);
        assertEq(elector.againstVotes(PROPOSAL_ID), 1);
        assertEq(elector.abstentionCount(PROPOSAL_ID), 0);
        assertEq(elector.totalParticipation(PROPOSAL_ID), 1);
    }

    function testAbstainFromVote() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.makeReady(PROPOSAL_ID);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.abstainFromVote(PROPOSAL_ID);
        assertEq(elector.forVotes(PROPOSAL_ID), 0);
        assertEq(elector.againstVotes(PROPOSAL_ID), 0);
        assertEq(elector.abstentionCount(PROPOSAL_ID), 1);
        assertEq(elector.totalParticipation(PROPOSAL_ID), 1);
    }
}

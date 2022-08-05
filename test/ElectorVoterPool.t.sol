// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/ElectorVoterPool.sol";
import "../contracts/VoterClass.sol";

contract ElectorVoterPoolTest is Test {
    ElectorVoterPool elector;

    address public immutable owner = msg.sender;
    address public immutable supervisor = address(0x123);
    address public immutable nonSupervisor = address(0x123eee);
    address public immutable voter1 = address(0xfff1);
    address public immutable voter2 = address(0xfff2);
    uint256 public immutable NONE = 0;
    uint256 public immutable PROPOSAL_ID = 1;

    function setUp() public {
        elector = new ElectorVoterPool();
        elector.initializeProposal(elector);
    }

    function testVotesCastZero() public {
        assertEq(elector.forVotes(PROPOSAL_ID), NONE);
        assertEq(elector.againstVotes(PROPOSAL_ID), NONE);
        assertEq(elector.abstentionCount(PROPOSAL_ID), NONE);
    }

    function testFailOnlyOneOwnerCanRegisterSupervisor() public {
        vm.prank(address(0));
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
    }

    function testRegisterSupervisor() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.setQuorumThreshold(PROPOSAL_ID, 100);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
    }

    function testFailRegisterSupervisorBadProposal() public {
        elector.registerSupervisor(0, supervisor);
    }

    function testFailRegisterSupervisorIfOpen() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.openVoting(PROPOSAL_ID);
        elector.registerSupervisor(PROPOSAL_ID, nonSupervisor);
    }

    function testRegisterAndBurnSupervisor() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        elector.burnSupervisor(PROPOSAL_ID, supervisor);
        assertFalse(elector.isSupervisor(PROPOSAL_ID, supervisor));
    }

    function testFailOpenByBurnedSupervisor() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        elector.burnSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.openVoting(PROPOSAL_ID);
    }

    function testFailVoterByBurnedSupervisor() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        elector.burnSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
    }

    function testFailBurnVoterByBurnedSupervisor() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        elector.burnSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.burnVoter(PROPOSAL_ID, voter1);
    }

    function testSupervisorRegisterVoter() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        assertTrue(elector.isVoter(PROPOSAL_ID, voter1));
    }

    function testSupervisorRegisterMoreThanOneVoter() public {
        address[] memory voter = new address[](2);
        voter[0] = voter1;
        voter[1] = voter2;

        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);

        elector.registerVoters(PROPOSAL_ID, voter);
        assertTrue(elector.isVoter(PROPOSAL_ID, voter1));
        assertTrue(elector.isVoter(PROPOSAL_ID, voter2));
    }

    function testSupervisorRegisterThenBurnVoter() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(supervisor);
        elector.burnVoter(PROPOSAL_ID, voter1);
        assertFalse(elector.isVoter(PROPOSAL_ID, voter1));
    }

    function testFailAddVoterIfOpen() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
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
        elector.openVoting(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.burnVoter(PROPOSAL_ID, voter1);
    }

    function testFailOwnerRegisterVoter() public {
        elector.registerVoter(PROPOSAL_ID, voter1);
    }

    function testFailOwnerBurnVoter() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(owner);
        elector.burnVoter(PROPOSAL_ID, voter1);
    }

    function testsetQuorumThreshold() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.setQuorumThreshold(PROPOSAL_ID, 100);
        assertEq(elector.quorumRequired(PROPOSAL_ID), 100);
    }

    function testRequiredParticipation() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.setRequiredParticipation(PROPOSAL_ID, 101);
        assertEq(elector.requiredParticipation(PROPOSAL_ID), 101);
    }

    function testFailOwnerOpenVoting() public {
        elector.openVoting(PROPOSAL_ID);
    }

    function testFailOwnerEndVoting() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.openVoting(PROPOSAL_ID);
        vm.prank(owner);
        elector.endVoting(PROPOSAL_ID);
    }

    function testFailDoubleOpenVoting() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.openVoting(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVoting(PROPOSAL_ID);
    }

    function testFailEndVotingWhenNotOpen() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.endVoting(PROPOSAL_ID);
    }

    function testFailOwnerCastVote() public {
        elector.voteFor(PROPOSAL_ID);
    }

    function testFailSupervisorCastVote() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        elector.voteFor(PROPOSAL_ID);
    }

    function testCastOneVote() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        assertEq(elector.totalParticipation(PROPOSAL_ID), 1);
    }

    function testCastOneVoteFromClass() public {
        VoterClass _voterClass = new VoterClassOpenAccess();
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoterClass(PROPOSAL_ID, _voterClass);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        assertEq(elector.totalParticipation(PROPOSAL_ID), 1);
    }

    function testCastTwoVoteFromClass() public {
        VoterClass _voterClass = new VoterClassTwoVote();
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoterClass(PROPOSAL_ID, _voterClass);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.openVoting(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        assertEq(elector.totalParticipation(PROPOSAL_ID), 2);
    }

    function testFailCastOneVoteWithBurnedClass() public {
        VoterClass _voterClass = new VoterClassOpenAccess();
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoterClass(PROPOSAL_ID, _voterClass);
        elector.burnVoterClass(PROPOSAL_ID);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
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
        elector.openVoting(PROPOSAL_ID);
        elector.getVoteSucceeded(PROPOSAL_ID);
    }

    function testFailMeasureIsVeto() public {
        elector.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        elector.registerVoter(PROPOSAL_ID, voter1);
        elector.registerVoter(PROPOSAL_ID, voter2);
        elector.setQuorumThreshold(PROPOSAL_ID, 2);
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
        vm.stopPrank();
        elector.openVoting(PROPOSAL_ID);
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(voter2);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.endVoting(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.veto(PROPOSAL_ID);
    }

    function testFailSetVoteDelay() public view {
        elector.setVoteDelay(PROPOSAL_ID, 100);
    }

    function testFailSetMinimumVoteDuration() public {
        elector.setRequiredVoteDuration(PROPOSAL_ID, 100);
    }

    function testFailSetFailMinimumVoteTally() public {
        elector.setRequiredParticipation(PROPOSAL_ID, 100);
    }

    function testFailVoteAgainst() public view {
        elector.voteAgainst(PROPOSAL_ID);
    }

    function testFailAbstainFromVote() public view {
        elector.abstainFromVote(PROPOSAL_ID);
    }
}

contract VoterClassOpenAccess is VoterClass {
    function isVoter(address) external pure returns (bool) {
        return true;
    }

    function votesAvailable(
        address /* _wallet */
    ) external pure returns (uint256) {
        return 1;
    }
}

contract VoterClassTwoVote is VoterClass {
    function isVoter(address) external pure returns (bool) {
        return true;
    }

    function votesAvailable(
        address /* _wallet */
    ) external pure returns (uint256) {
        return 2;
    }
}

contract ElectorVoter2 is ElectorVoterPool {
    
}

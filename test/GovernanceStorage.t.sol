// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable not-rely-on-time
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC721.sol";

import "forge-std/Test.sol";

import "../contracts/Constant.sol";
import "../contracts/GovernanceStorage.sol";
import "../contracts/CollectiveGovernance.sol";
import "../contracts/VoteStrategy.sol";
import "../contracts/VoterClass.sol";
import "../contracts/VoterClassVoterPool.sol";
import "../contracts/VoterClassERC721.sol";

import "./MockERC721.sol";

contract GovernanceStorageTest is Test {
    using stdStorage for StdStorage;

    address private constant _OWNER = address(0x155);
    address private constant _SUPERVISOR = address(0x123);
    address private constant _NOTSUPERVISOR = address(0x123eee);
    address private constant _VOTER1 = address(0xfff1);
    address private constant _VOTER2 = address(0xfff2);
    address private constant _VOTER3 = address(0xfff3);
    address private constant _NOBODY = address(0x0);
    uint256 private constant BLOCK = 0x300;
    uint256 private constant NONE = 0;
    uint256 private constant PROPOSAL_ID = 1;

    address private immutable _cognate = address(this);

    Storage private _storage;
    VoteStrategy private _strategy;

    function setUp() public {
        vm.clearMockedCalls();
        VoterClassVoterPool _voterClass = new VoterClassVoterPool(1);
        _voterClass.addVoter(_VOTER1);
        _voterClass.addVoter(_VOTER2);
        _voterClass.addVoter(_VOTER3);
        _voterClass.makeFinal();
        _storage = new GovernanceStorage(_voterClass, Constant.MINIMUM_VOTE_DURATION);
        _storage.initializeProposal(_OWNER);
    }

    function testVotesCastZero() public {
        assertEq(_storage.forVotes(PROPOSAL_ID), NONE);
        assertEq(_storage.againstVotes(PROPOSAL_ID), NONE);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), NONE);
        assertEq(_storage.quorum(PROPOSAL_ID), NONE);
    }

    function testFailMinimumDurationRequired() public {
        VoterClass _voterClass = new VoterClassNullObject();
        new GovernanceStorage(_voterClass, 1);
    }

    function testIsReady() public {
        assertFalse(_storage.isFinal(PROPOSAL_ID));
    }

    function testGetSender() public {
        address sender = _storage.getSender(PROPOSAL_ID);
        assertEq(sender, _OWNER);
    }

    function testOnlyOneOwnerCanRegisterSupervisor() public {
        vm.prank(_NOBODY);
        vm.expectRevert("Not permitted");
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _NOBODY);
    }

    function testRegisterSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        assertTrue(_storage.isSupervisor(PROPOSAL_ID, _SUPERVISOR));
    }

    function testOwnerRegisterSupervisor() public {
        vm.expectRevert("Not permitted");
        vm.prank(_OWNER);
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
    }

    function testRegisterSupervisorBadProposal() public {
        vm.expectRevert("Invalid proposal");
        _storage.registerSupervisor(0, _SUPERVISOR, _OWNER);
    }

    function testRegisterSupervisorIfOpen() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.registerSupervisor(PROPOSAL_ID, _NOTSUPERVISOR, _OWNER);
    }

    function testRegisterAndBurnSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.burnSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        assertFalse(_storage.isSupervisor(PROPOSAL_ID, _SUPERVISOR));
    }

    function testRegisterAndOwnerBurnSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Not permitted");
        vm.prank(_OWNER);
        _storage.burnSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
    }

    function testReadyByBurnedSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.burnSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Requires supervisor");
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
    }

    function testSetQuorumRequired() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(PROPOSAL_ID, 100, _SUPERVISOR);
        assertEq(_storage.quorumRequired(PROPOSAL_ID), 100);
    }

    function testSetQuorumRequiredDirect() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Not permitted");
        vm.prank(_SUPERVISOR);
        _storage.setQuorumRequired(PROPOSAL_ID, 100, _SUPERVISOR);
    }

    function testSetQuorumRequiredIfReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.setQuorumRequired(PROPOSAL_ID, 100, _SUPERVISOR);
    }

    function testSetVoteDelay() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setVoteDelay(PROPOSAL_ID, 3600, _SUPERVISOR);
        assertEq(_storage.voteDelay(PROPOSAL_ID), 3600);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        assertEq(_storage.startTime(PROPOSAL_ID), block.timestamp + 3600);
    }

    function testSetVoteDelayDirect() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Not permitted");
        vm.prank(_SUPERVISOR);
        _storage.setVoteDelay(PROPOSAL_ID, 100, _SUPERVISOR);
    }

    function testSetVoteDelayRequiresSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Not permitted");
        vm.prank(_OWNER);
        _storage.setVoteDelay(PROPOSAL_ID, 100, _OWNER);
    }

    function testSetVoteDelayIfReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.setVoteDelay(PROPOSAL_ID, 3600, _SUPERVISOR);
    }

    function testSetMinimumVoteDuration() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setVoteDuration(PROPOSAL_ID, Constant.MINIMUM_VOTE_DURATION, _SUPERVISOR);
        assertEq(_storage.voteDuration(PROPOSAL_ID), Constant.MINIMUM_VOTE_DURATION);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        assertEq(_storage.endTime(PROPOSAL_ID), block.timestamp + Constant.MINIMUM_VOTE_DURATION);
    }

    function testSetMinimumVoteDurationDirect() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Not permitted");
        vm.prank(_SUPERVISOR);
        _storage.setVoteDuration(PROPOSAL_ID, 10, _SUPERVISOR);
    }

    function testSetMinimumVoteDurationNonZero() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Short vote");
        _storage.setVoteDuration(PROPOSAL_ID, 0, _SUPERVISOR);
    }

    function testSetMinimumVoteDurationOneDay() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Short vote");
        _storage.setVoteDuration(PROPOSAL_ID, 86399, _SUPERVISOR);
    }

    function testSetMinimumVoteDurationIfReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.setVoteDuration(PROPOSAL_ID, 1, _SUPERVISOR);
    }

    function testSetMinimumVoteDurationRequiredSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Requires supervisor");
        _storage.setVoteDuration(PROPOSAL_ID, 0, _cognate);
    }

    function testMakeReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        assertTrue(_storage.isFinal(PROPOSAL_ID));
    }

    function testMakeReadyDirect() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Not permitted");
        vm.prank(_SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
    }

    function testMakeReadyDoubleCall() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
    }

    function testMakeReadyRequireSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Requires supervisor");
        _storage.makeFinal(PROPOSAL_ID, _cognate);
    }

    function testVeto() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        assertFalse(_storage.isVeto(PROPOSAL_ID));
        _storage.veto(PROPOSAL_ID, _SUPERVISOR);
        assertTrue(_storage.isVeto(PROPOSAL_ID));
    }

    function testVetoDirect() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Not permitted");
        vm.prank(_SUPERVISOR);
        _storage.veto(PROPOSAL_ID, _SUPERVISOR);
    }

    function testOwnerMayNotVeto() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Requires supervisor");
        _storage.veto(PROPOSAL_ID, _OWNER);
    }

    function testVoterMayNotVeto() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Requires supervisor");
        _storage.veto(PROPOSAL_ID, _VOTER1);
    }

    function testRevertInvalidProposal(uint256 _proposalId) public {
        vm.assume(_proposalId > PROPOSAL_ID);
        vm.expectRevert("Invalid proposal");
        _storage.validOrRevert(_proposalId);
    }

    function testAbstainFromVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        _storage.abstainForShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
        assertEq(_storage.forVotes(PROPOSAL_ID), 0);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 0);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 1);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testVoterDirectAbstainFromVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.expectRevert("Not permitted");
        vm.prank(_VOTER1);
        _storage.abstainForShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
    }

    function testCastAgainstVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        _storage.voteAgainstByShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
        assertEq(_storage.forVotes(PROPOSAL_ID), 0);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 1);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 0);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testVoterDirectCastAgainstVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.expectRevert("Not permitted");
        vm.prank(_VOTER1);
        _storage.voteAgainstByShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
    }

    function testCastOneVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        _storage.voteForByShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testVoterReceipt() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        _storage.voteForByShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));

        (uint256 shareId, uint256 shareFor, uint256 voteCast, bool abstention, bool isUndo) = _storage.voteReceipt(
            PROPOSAL_ID,
            uint160(_VOTER1)
        );

        assertEq(shareId, uint160(_VOTER1));
        assertEq(shareFor, 1);
        assertEq(voteCast, 1);
        assertFalse(abstention);
        assertFalse(isUndo);
    }

    function testVoterReceiptWithUndo() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.enableUndoVote(PROPOSAL_ID, _SUPERVISOR);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        _storage.voteForByShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
        _storage.undoVoteById(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));

        (uint256 shareId, uint256 shareFor, uint256 voteCast, bool abstention, bool isUndo) = _storage.voteReceipt(
            PROPOSAL_ID,
            uint160(_VOTER1)
        );

        assertEq(shareId, uint160(_VOTER1));
        assertEq(shareFor, 1);
        assertEq(voteCast, 1);
        assertFalse(abstention);
        assertTrue(isUndo);
    }

    function testAgainstWithUndo() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.enableUndoVote(PROPOSAL_ID, _SUPERVISOR);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        _storage.voteAgainstByShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
        vm.expectRevert("Vote not affirmative");
        _storage.undoVoteById(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
    }

    function testAbstainWithUndo() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.enableUndoVote(PROPOSAL_ID, _SUPERVISOR);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        _storage.abstainForShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
        vm.expectRevert("No affirmative vote");
        _storage.undoVoteById(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
    }

    function testVoteAgainstReceipt() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        _storage.voteAgainstByShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));

        (uint256 shareId, uint256 shareFor, uint256 voteCast, bool abstention, bool isUndo) = _storage.voteReceipt(
            PROPOSAL_ID,
            uint160(_VOTER1)
        );

        assertEq(shareId, uint160(_VOTER1));
        assertEq(shareFor, 0);
        assertEq(voteCast, 1);
        assertFalse(abstention);
        assertFalse(isUndo);
    }

    function testAbstentionReceipt() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        _storage.abstainForShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));

        (uint256 shareId, uint256 shareFor, uint256 voteCast, bool abstention, bool isUndo) = _storage.voteReceipt(
            PROPOSAL_ID,
            uint160(_VOTER1)
        );

        assertEq(shareId, uint160(_VOTER1));
        assertEq(shareFor, 0);
        assertEq(voteCast, 1);
        assertTrue(abstention);
        assertFalse(isUndo);
    }

    function testVoterDirectlyCastOneVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.expectRevert("Not permitted");
        vm.prank(_VOTER1);
        _storage.voteForByShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
    }

    function testQuorumAllThree() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        _storage.voteForByShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
        _storage.voteAgainstByShare(PROPOSAL_ID, _VOTER2, uint160(_VOTER2));
        assertEq(_storage.againstVotes(PROPOSAL_ID), 1);
        _storage.abstainForShare(PROPOSAL_ID, _VOTER3, uint160(_VOTER3));
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 1);
        assertEq(_storage.quorum(PROPOSAL_ID), 3);
    }

    function testCastOneVoteFromAll() public {
        _storage = new GovernanceStorage(new VoterClassOpenVote(1), Constant.MINIMUM_VOTE_DURATION);
        _storage.initializeProposal(_OWNER);
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        _storage.voteForByShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testCastVoteFromERC721() public {
        uint256 tokenId = 0x71;
        MockERC721 token = new MockERC721();
        token.mintTo(_VOTER2, tokenId);
        _storage = new GovernanceStorage(new VoterClassERC721(address(token), 1), Constant.MINIMUM_VOTE_DURATION);
        _storage.initializeProposal(_OWNER);
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(PROPOSAL_ID, 1, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        _storage.voteForByShare(PROPOSAL_ID, _VOTER2, tokenId);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 0);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 0);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testPermittedAfterObservingVoteDelay() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(PROPOSAL_ID, 1, _SUPERVISOR);
        _storage.setVoteDelay(PROPOSAL_ID, 3600, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        uint256 startTime = block.timestamp;
        vm.warp(startTime + 3600);
        _storage.voteForByShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
        assertEq(1, _storage.forVotes(PROPOSAL_ID));
    }

    function testVoteWithUndo() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.enableUndoVote(PROPOSAL_ID, _SUPERVISOR);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        _storage.voteForByShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
        _storage.undoVoteById(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
        assertEq(_storage.quorum(PROPOSAL_ID), NONE);
    }

    function testVoteWithDoubleUndo() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.enableUndoVote(PROPOSAL_ID, _SUPERVISOR);
        _storage.setQuorumRequired(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        _storage.voteForByShare(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
        _storage.undoVoteById(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
        vm.expectRevert("No affirmative vote");
        _storage.undoVoteById(PROPOSAL_ID, _VOTER1, uint160(_VOTER1));
    }

    function testName() public {
        assertEq(_storage.name(), "collective.xyz governance storage");
    }

    function testVersion() public {
        assertEq(_storage.version(), 1);
    }

    function testLatestProposal() public {
        uint256 latestProposalId = _storage.latestProposal(_OWNER);
        assertEq(PROPOSAL_ID, latestProposalId);
        _storage.registerSupervisor(latestProposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(latestProposalId, _SUPERVISOR);
        uint256 endTime = _storage.endTime(latestProposalId);
        vm.warp(endTime);
        uint256 nextId = _storage.initializeProposal(_OWNER);
        latestProposalId = _storage.latestProposal(_OWNER);
        assertEq(latestProposalId, nextId);
    }

    function testLatestRevertIfNone() public {
        vm.expectRevert("No current proposal");
        _storage.latestProposal(_SUPERVISOR);
    }

    function testLatestProposalRevertItsNotOverTillItsOver() public {
        uint256 latestProposalId = _storage.latestProposal(_OWNER);
        assertEq(PROPOSAL_ID, latestProposalId);
        _storage.registerSupervisor(latestProposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(latestProposalId, _SUPERVISOR);
        vm.expectRevert("Too many proposals");
        _storage.initializeProposal(_OWNER);
    }

    function testRevertOnSecondProposal() public {
        vm.expectRevert("Too many proposals");
        _storage.initializeProposal(_OWNER);
    }

    function testCancelProposalNotReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.cancel(PROPOSAL_ID, _SUPERVISOR);
        assertTrue(_storage.isCancel(PROPOSAL_ID));
    }

    function testCancelProposal() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        assertFalse(_storage.isCancel(PROPOSAL_ID));
        _storage.cancel(PROPOSAL_ID, _SUPERVISOR);
        assertTrue(_storage.isCancel(PROPOSAL_ID));
    }

    function testCancelFailIfNotSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.expectRevert("Requires supervisor");
        _storage.cancel(PROPOSAL_ID, _NOTSUPERVISOR);
    }
}

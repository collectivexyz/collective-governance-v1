// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable not-rely-on-time
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC721.sol";

import "forge-std/Test.sol";

import "../contracts/Constant.sol";
import "../contracts/StorageFactory.sol";
import "../contracts/CollectiveGovernance.sol";
import "../contracts/VoteStrategy.sol";
import "../contracts/VoterClass.sol";
import "../contracts/VoterClassVoterPool.sol";
import "../contracts/VoterClassERC721.sol";
import "./TestData.sol";

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
        _storage = StorageFactory.create(
            _voterClass,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION
        );
        _storage.initializeProposal(_OWNER);
    }

    function testMinimumVoteDelay() public {
        VoterClassVoterPool _voterClass = new VoterClassVoterPool(1);
        _voterClass.addVoter(_VOTER1);
        _voterClass.makeFinal();
        _storage = StorageFactory.create(_voterClass, Constant.MINIMUM_PROJECT_QUORUM, 333, Constant.MINIMUM_VOTE_DURATION);
        assertEq(_storage.minimumVoteDelay(), 333);
    }

    function testMinimumVoteDuration() public {
        VoterClassVoterPool _voterClass = new VoterClassVoterPool(1);
        _voterClass.addVoter(_VOTER1);
        _voterClass.makeFinal();
        _storage = StorageFactory.create(_voterClass, Constant.MINIMUM_PROJECT_QUORUM, Constant.MINIMUM_VOTE_DELAY, 22 days);
        assertEq(_storage.minimumVoteDuration(), 22 days);
    }

    function testMinimumProjectQuorum() public {
        VoterClassVoterPool _voterClass = new VoterClassVoterPool(1);
        _voterClass.addVoter(_VOTER1);
        _voterClass.makeFinal();
        _storage = StorageFactory.create(_voterClass, 11111, Constant.MINIMUM_VOTE_DELAY, Constant.MINIMUM_VOTE_DURATION);
        assertEq(_storage.minimumProjectQuorum(), 11111);
    }

    function testVotesCastZero() public {
        assertEq(_storage.forVotes(PROPOSAL_ID), NONE);
        assertEq(_storage.againstVotes(PROPOSAL_ID), NONE);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), NONE);
        assertEq(_storage.quorum(PROPOSAL_ID), NONE);
    }

    function testMinimumDelayNotEnforced() public {
        VoterClassVoterPool _voterClass = new VoterClassVoterPool(1);
        _voterClass.addVoter(_VOTER1);
        _voterClass.makeFinal();
        new GovernanceStorage(_voterClass, Constant.MINIMUM_PROJECT_QUORUM, 0, Constant.MINIMUM_VOTE_DURATION);
    }

    function testFailMinimumDurationRequired() public {
        VoterClass _voterClass = new VoterClassNullObject();
        new GovernanceStorage(
            _voterClass,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION - 1
        );
    }

    function testFailMinimumQuorumRequired() public {
        VoterClass _voterClass = new VoterClassNullObject();
        new GovernanceStorage(
            _voterClass,
            Constant.MINIMUM_PROJECT_QUORUM - 1,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION
        );
    }

    function testFailVoterClassNotFinal() public {
        VoterClass _class = new VoterClassVoterPool(1);
        new GovernanceStorage(
            _class,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION
        );
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
        vm.expectRevert("Ownable: caller is not the owner");
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _NOBODY);
    }

    function testRegisterSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        assertTrue(_storage.isSupervisor(PROPOSAL_ID, _SUPERVISOR));
    }

    function testOwnerRegisterSupervisor() public {
        vm.expectRevert("Ownable: caller is not the owner");
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

    function testRegisterProjectSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, true, _OWNER);
        assertTrue(_storage.isSupervisor(PROPOSAL_ID, _SUPERVISOR));
    }

    function testBurnProjectSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, true, _OWNER);
        vm.expectRevert("Supervisor change not permitted");
        _storage.burnSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
    }

    function testRegisterAndBurnSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.burnSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        assertFalse(_storage.isSupervisor(PROPOSAL_ID, _SUPERVISOR));
    }

    function testRegisterAndOwnerBurnSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
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
        vm.expectRevert("Ownable: caller is not the owner");
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
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.setVoteDelay(PROPOSAL_ID, 100, _SUPERVISOR);
    }

    function testSetVoteDelayRequiresSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
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
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.setVoteDuration(PROPOSAL_ID, 10, _SUPERVISOR);
    }

    function testSetMinimumVoteDurationNonZero() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Duration not allowed");
        _storage.setVoteDuration(PROPOSAL_ID, 0, _SUPERVISOR);
    }

    function testSetMinimumVoteDurationShort() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Duration not allowed");
        _storage.setVoteDuration(PROPOSAL_ID, Constant.MINIMUM_VOTE_DURATION - 1, _SUPERVISOR);
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
        _storage.setVoteDuration(PROPOSAL_ID, Constant.MINIMUM_VOTE_DURATION, _cognate);
    }

    function testMakeReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        assertTrue(_storage.isFinal(PROPOSAL_ID));
    }

    function testMakeReadyDirect() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
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
        vm.expectRevert("Ownable: caller is not the owner");
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
        vm.expectRevert("Ownable: caller is not the owner");
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
        vm.expectRevert("Ownable: caller is not the owner");
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
        vm.expectRevert("Ownable: caller is not the owner");
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
        _storage = new GovernanceStorage(
            new VoterClassOpenVote(1),
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION
        );
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
        _storage = new GovernanceStorage(
            new VoterClassERC721(address(token), 1),
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION
        );
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
        assertEq(_storage.name(), "collective governance storage");
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
        vm.expectRevert("No proposal");
        _storage.latestProposal(_SUPERVISOR);
    }

    function testAllowProposalIfFinal() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.warp(block.timestamp + Constant.MINIMUM_VOTE_DURATION + 1);
        uint256 nextProposalId = _storage.initializeProposal(_OWNER);
        assertTrue(nextProposalId > PROPOSAL_ID);
    }

    function testExemptFromDelayIfCancel() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.cancel(PROPOSAL_ID, _SUPERVISOR);
        uint256 nextProposalId = _storage.initializeProposal(_OWNER);
        assertTrue(nextProposalId > PROPOSAL_ID);
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

    function testFailTransferNotOwner() public {
        GovernanceStorage _gStorage = new GovernanceStorage(
            _storage.voterClass(),
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MINIMUM_PROJECT_QUORUM
        );
        vm.prank(_SUPERVISOR);
        _gStorage.transferOwnership(_SUPERVISOR);
    }

    function testAddTransaction() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        uint256 tid1 = _storage.addTransaction(PROPOSAL_ID, address(0x1), 0x10, "", "", scheduleTime, "", _OWNER);
        assertEq(tid1, 0);
        uint256 tid2 = _storage.addTransaction(PROPOSAL_ID, address(0x2), 0x20, "", "", scheduleTime, "", _OWNER);
        assertEq(tid2, 1);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
    }

    function testAddTransactionNotOwner() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Not creator");
        _storage.addTransaction(PROPOSAL_ID, address(0x1), 0x10, "", "", scheduleTime, "", _SUPERVISOR);
    }

    function testAddTransactionIfFinal() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.addTransaction(PROPOSAL_ID, address(0x1), 0x10, "", "", scheduleTime, "", _OWNER);
    }

    function testClearTransactionIfFinal() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        uint256 tid = _storage.addTransaction(PROPOSAL_ID, address(0x1), 0x10, "", "", scheduleTime, "", _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.clearTransaction(PROPOSAL_ID, tid, _OWNER);
    }

    function testGetTransaction() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        Storage.Transaction memory transaction = Storage.Transaction(address(0x1), 0x10, "ziggy", "a()", scheduleTime, "abc123");
        uint256 tid = _storage.addTransaction(
            PROPOSAL_ID,
            transaction.target,
            transaction.value,
            transaction.signature,
            transaction._calldata,
            transaction.scheduleTime,
            transaction.txHash,
            _OWNER
        );
        (
            address target,
            uint256 value,
            string memory signature,
            bytes memory _calldata,
            uint256 scheduleTimeRet,
            bytes32 txHash
        ) = _storage.getTransaction(PROPOSAL_ID, tid);
        assertEq(target, transaction.target);
        assertEq(value, transaction.value);
        assertEq(signature, transaction.signature);
        assertEq(_calldata, transaction._calldata);
        assertEq(scheduleTimeRet, transaction.scheduleTime);
        assertEq(txHash, transaction.txHash);
    }

    function testClearTransaction() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        uint256 tid1 = _storage.addTransaction(PROPOSAL_ID, address(0x1), 0x10, "", "", scheduleTime, "tx1", _OWNER);
        assertEq(tid1, 0);
        uint256 tid2 = _storage.addTransaction(PROPOSAL_ID, address(0x2), 0x20, "f()", "1", scheduleTime + 1, "tx2", _OWNER);
        assertEq(tid2, 1);
        _storage.clearTransaction(PROPOSAL_ID, tid1, _OWNER);
        (
            address target,
            uint256 value,
            string memory signature,
            bytes memory _calldata,
            uint256 scheduleTimeRet,
            bytes32 txHash
        ) = _storage.getTransaction(PROPOSAL_ID, tid1);
        assertEq(target, address(0x0));
        assertEq(value, 0);
        assertEq(signature, "");
        assertEq(_calldata, "");
        assertEq(scheduleTimeRet, 0);
        assertEq(txHash, "");

        (target, value, signature, _calldata, scheduleTimeRet, txHash) = _storage.getTransaction(PROPOSAL_ID, tid2);
        assertEq(target, address(0x2));
        assertEq(value, 0x20);
        assertEq(signature, "f()");
        assertEq(_calldata, "1");
        assertEq(scheduleTimeRet, scheduleTime + 1);
        assertEq(txHash, "tx2");
    }

    function testSetExecuted() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        assertFalse(_storage.isExecuted(PROPOSAL_ID));
        _storage.setExecuted(PROPOSAL_ID, _OWNER);
        assertTrue(_storage.isExecuted(PROPOSAL_ID));
    }

    function testSetExecutedNotOwner() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.expectRevert("Not creator");
        _storage.setExecuted(PROPOSAL_ID, _SUPERVISOR);
    }

    function testSetProposalUrl() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setProposalUrl(PROPOSAL_ID, "https://collective.xyz", _SUPERVISOR);
        assertEq(_storage.url(PROPOSAL_ID), "https://collective.xyz");
    }

    function testSetProposalUrlIfFinal() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.setProposalUrl(PROPOSAL_ID, "https://collective.xyz", _SUPERVISOR);
    }

    function testSetProposalUrlNotSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Requires supervisor");
        _storage.setProposalUrl(PROPOSAL_ID, "https://collective.xyz", _VOTER1);
    }

    function testSetProposalUrlNotOwner() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_VOTER1);
        _storage.setProposalUrl(PROPOSAL_ID, "https://collective.xyz", _SUPERVISOR);
    }

    function testFailSetProposalUrlTooLarge() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setProposalUrl(PROPOSAL_ID, TestData.pi1kplus(), _SUPERVISOR);
    }

    function testSetProposalDescription() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setProposalDescription(PROPOSAL_ID, "A project to build governance for all communities", _SUPERVISOR);
        assertEq(_storage.description(PROPOSAL_ID), "A project to build governance for all communities");
    }

    function testSetProposalDescriptionIfFinal() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.setProposalDescription(PROPOSAL_ID, "A project to build governance for all communities", _SUPERVISOR);
    }

    function testSetProposalDescriptionNotSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Requires supervisor");
        _storage.setProposalDescription(PROPOSAL_ID, "A project to build governance for all communities", _VOTER1);
    }

    function testSetProposalDescriptionNotOwner() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_VOTER1);
        _storage.setProposalDescription(PROPOSAL_ID, "Url", _SUPERVISOR);
    }

    function testFailSetProposalDescriptionTooLarge() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.setProposalDescription(PROPOSAL_ID, TestData.pi1kplus(), _SUPERVISOR);
    }

    function testMetaCountInitialValue() public {
        assertEq(_storage.metaCount(PROPOSAL_ID), 0);
    }

    function testMetaCount() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < 10; i++) {
            _storage.addMeta(PROPOSAL_ID, "a", "1", _SUPERVISOR);
        }
        assertEq(_storage.metaCount(PROPOSAL_ID), 10);
    }

    function testAddMeta() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        uint256 m1 = _storage.addMeta(PROPOSAL_ID, "a", "1", _SUPERVISOR);
        uint256 m2 = _storage.addMeta(PROPOSAL_ID, "b", "2", _SUPERVISOR);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        (bytes32 m1name, string memory m1value) = _storage.getMeta(PROPOSAL_ID, m1);
        assertEq(m1name, "a");
        assertEq(m1value, "1");
        (bytes32 m2name, string memory m2value) = _storage.getMeta(PROPOSAL_ID, m2);
        assertEq(m2name, "b");
        assertEq(m2value, "2");
    }

    function testAddMetaIfFinal() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.makeFinal(PROPOSAL_ID, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.addMeta(PROPOSAL_ID, "a", "1", _SUPERVISOR);
    }

    function testAddMetaNotOwner() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.addMeta(PROPOSAL_ID, "a", "1", _SUPERVISOR);
    }

    function testAddMetaNotSupervisor() public {
        vm.expectRevert("Requires supervisor");
        _storage.addMeta(PROPOSAL_ID, "a", "1", _VOTER1);
    }

    function testFailAddMetaValueTooLarge() public {
        _storage.registerSupervisor(PROPOSAL_ID, _SUPERVISOR, _OWNER);
        _storage.addMeta(PROPOSAL_ID, "a", TestData.pi1kplus(), _SUPERVISOR);
    }
}

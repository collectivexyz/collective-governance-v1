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

    StorageFactory private _storageFactory;
    Storage private _storage;
    VoteStrategy private _strategy;
    uint256 private _proposalId;

    function setUp() public {
        vm.clearMockedCalls();
        _storageFactory = new StorageFactory();
        VoterClassVoterPool _voterClass = new VoterClassVoterPool(1);
        _voterClass.addVoter(_VOTER1);
        _voterClass.addVoter(_VOTER2);
        _voterClass.addVoter(_VOTER3);
        _voterClass.makeFinal();
        _storage = _storageFactory.create(
            _voterClass,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            "",
            "",
            ""
        );
        _proposalId = _storage.initializeProposal(0, _OWNER);
        assertEq(_proposalId, PROPOSAL_ID);
    }

    function testMinimumVoteDelay() public {
        VoterClassVoterPool _voterClass = new VoterClassVoterPool(1);
        _voterClass.addVoter(_VOTER1);
        _voterClass.makeFinal();
        _storage = _storageFactory.create(
            _voterClass,
            Constant.MINIMUM_PROJECT_QUORUM,
            333,
            Constant.MINIMUM_VOTE_DURATION,
            "",
            "",
            ""
        );
        assertEq(_storage.minimumVoteDelay(), 333);
    }

    function testMinimumVoteDuration() public {
        VoterClassVoterPool _voterClass = new VoterClassVoterPool(1);
        _voterClass.addVoter(_VOTER1);
        _voterClass.makeFinal();
        _storage = _storageFactory.create(
            _voterClass,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            22 days,
            "",
            "",
            ""
        );
        assertEq(_storage.minimumVoteDuration(), 22 days);
    }

    function testMinimumProjectQuorum() public {
        VoterClassVoterPool _voterClass = new VoterClassVoterPool(1);
        _voterClass.addVoter(_VOTER1);
        _voterClass.makeFinal();
        _storage = _storageFactory.create(
            _voterClass,
            11111,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            "",
            "",
            ""
        );
        assertEq(_storage.minimumProjectQuorum(), 11111);
    }

    function testVotesCastZero() public {
        assertEq(_storage.forVotes(_proposalId), NONE);
        assertEq(_storage.againstVotes(_proposalId), NONE);
        assertEq(_storage.abstentionCount(_proposalId), NONE);
        assertEq(_storage.quorum(_proposalId), NONE);
    }

    function testMinimumDelayNotEnforced() public {
        VoterClassVoterPool _voterClass = new VoterClassVoterPool(1);
        _voterClass.addVoter(_VOTER1);
        _voterClass.makeFinal();
        new GovernanceStorage(_voterClass, Constant.MINIMUM_PROJECT_QUORUM, 0, Constant.MINIMUM_VOTE_DURATION, "", "", "");
    }

    function testFailMinimumDurationRequired() public {
        VoterClass _voterClass = new VoterClassNullObject();
        new GovernanceStorage(
            _voterClass,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION - 1,
            "",
            "",
            ""
        );
    }

    function testFailMinimumQuorumRequired() public {
        VoterClass _voterClass = new VoterClassNullObject();
        new GovernanceStorage(
            _voterClass,
            Constant.MINIMUM_PROJECT_QUORUM - 1,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            "",
            "",
            ""
        );
    }

    function testFailVoterClassNotFinal() public {
        VoterClass _class = new VoterClassVoterPool(1);
        new GovernanceStorage(
            _class,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            "",
            "",
            ""
        );
    }

    function testIsReady() public {
        assertFalse(_storage.isFinal(_proposalId));
    }

    function testGetSender() public {
        address sender = _storage.getSender(_proposalId);
        assertEq(sender, _OWNER);
    }

    function testOnlyOneOwnerCanRegisterSupervisor() public {
        vm.prank(_NOBODY);
        vm.expectRevert("Ownable: caller is not the owner");
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _NOBODY);
    }

    function testRegisterSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        assertTrue(_storage.isSupervisor(_proposalId, _SUPERVISOR));
    }

    function testOwnerRegisterSupervisor() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_OWNER);
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
    }

    function testRegisterSupervisorBadProposal() public {
        vm.expectRevert("Invalid proposal");
        _storage.registerSupervisor(0, _SUPERVISOR, _OWNER);
    }

    function testRegisterSupervisorIfOpen() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.registerSupervisor(_proposalId, _NOTSUPERVISOR, _OWNER);
    }

    function testRegisterProjectSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, true, _OWNER);
        assertTrue(_storage.isSupervisor(_proposalId, _SUPERVISOR));
    }

    function testBurnProjectSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, true, _OWNER);
        vm.expectRevert("Supervisor change not permitted");
        _storage.burnSupervisor(_proposalId, _SUPERVISOR, _OWNER);
    }

    function testRegisterAndBurnSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.burnSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        assertFalse(_storage.isSupervisor(_proposalId, _SUPERVISOR));
    }

    function testRegisterAndOwnerBurnSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_OWNER);
        _storage.burnSupervisor(_proposalId, _SUPERVISOR, _OWNER);
    }

    function testReadyByBurnedSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.burnSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Requires supervisor");
        _storage.makeFinal(_proposalId, _SUPERVISOR);
    }

    function testSetQuorumRequired() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 100, _SUPERVISOR);
        assertEq(_storage.quorumRequired(_proposalId), 100);
    }

    function testSetQuorumRequiredDirect() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.setQuorumRequired(_proposalId, 100, _SUPERVISOR);
    }

    function testSetQuorumRequiredIfReady() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.setQuorumRequired(_proposalId, 100, _SUPERVISOR);
    }

    function testSetVoteDelay() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setVoteDelay(_proposalId, 3600, _SUPERVISOR);
        assertEq(_storage.voteDelay(_proposalId), 3600);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        assertEq(_storage.startTime(_proposalId), block.timestamp + 3600);
    }

    function testSetVoteDelayDirect() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.setVoteDelay(_proposalId, 100, _SUPERVISOR);
    }

    function testSetVoteDelayRequiresSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_OWNER);
        _storage.setVoteDelay(_proposalId, 100, _OWNER);
    }

    function testSetVoteDelayIfReady() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.setVoteDelay(_proposalId, 3600, _SUPERVISOR);
    }

    function testSetMinimumVoteDuration() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setVoteDuration(_proposalId, Constant.MINIMUM_VOTE_DURATION, _SUPERVISOR);
        assertEq(_storage.voteDuration(_proposalId), Constant.MINIMUM_VOTE_DURATION);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        assertEq(_storage.endTime(_proposalId), block.timestamp + Constant.MINIMUM_VOTE_DURATION);
    }

    function testSetMinimumVoteDurationDirect() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.setVoteDuration(_proposalId, 10, _SUPERVISOR);
    }

    function testSetMinimumVoteDurationNonZero() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Duration not allowed");
        _storage.setVoteDuration(_proposalId, 0, _SUPERVISOR);
    }

    function testSetMinimumVoteDurationShort() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Duration not allowed");
        _storage.setVoteDuration(_proposalId, Constant.MINIMUM_VOTE_DURATION - 1, _SUPERVISOR);
    }

    function testSetMinimumVoteDurationIfReady() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.setVoteDuration(_proposalId, 1, _SUPERVISOR);
    }

    function testSetMinimumVoteDurationRequiredSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Requires supervisor");
        _storage.setVoteDuration(_proposalId, Constant.MINIMUM_VOTE_DURATION, _OWNER);
    }

    function testMakeReady() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        assertTrue(_storage.isFinal(_proposalId));
    }

    function testMakeReadyDirect() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
    }

    function testMakeReadyDoubleCall() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.makeFinal(_proposalId, _SUPERVISOR);
    }

    function testMakeReadyRequireSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Requires supervisor");
        _storage.makeFinal(_proposalId, _OWNER);
    }

    function testVeto() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        assertFalse(_storage.isVeto(_proposalId));
        _storage.veto(_proposalId, _SUPERVISOR);
        assertTrue(_storage.isVeto(_proposalId));
    }

    function testVetoDirect() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.veto(_proposalId, _SUPERVISOR);
    }

    function testOwnerMayNotVeto() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Requires supervisor");
        _storage.veto(_proposalId, _OWNER);
    }

    function testVoterMayNotVeto() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Requires supervisor");
        _storage.veto(_proposalId, _VOTER1);
    }

    function testAbstainFromVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.abstainForShare(_proposalId, _VOTER1, uint160(_VOTER1));
        assertEq(_storage.forVotes(_proposalId), 0);
        assertEq(_storage.againstVotes(_proposalId), 0);
        assertEq(_storage.abstentionCount(_proposalId), 1);
        assertEq(_storage.quorum(_proposalId), 1);
    }

    function testVoterDirectAbstainFromVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_VOTER1);
        _storage.abstainForShare(_proposalId, _VOTER1, uint160(_VOTER1));
    }

    function testCastAgainstVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteAgainstByShare(_proposalId, _VOTER1, uint160(_VOTER1));
        assertEq(_storage.forVotes(_proposalId), 0);
        assertEq(_storage.againstVotes(_proposalId), 1);
        assertEq(_storage.abstentionCount(_proposalId), 0);
        assertEq(_storage.quorum(_proposalId), 1);
    }

    function testVoterDirectCastAgainstVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_VOTER1);
        _storage.voteAgainstByShare(_proposalId, _VOTER1, uint160(_VOTER1));
    }

    function testCastOneVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1));
        assertEq(_storage.forVotes(_proposalId), 1);
        assertEq(_storage.quorum(_proposalId), 1);
    }

    function testCastChoiceVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Choice invalid");
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1), 1);
    }

    function testVoterReceipt() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1));

        (uint256 shareId, uint256 shareFor, uint256 voteCast, uint256 choiceId, bool abstention, bool isUndo) = _storage
            .getVoteReceipt(_proposalId, uint160(_VOTER1));

        assertEq(shareId, uint160(_VOTER1));
        assertEq(shareFor, 1);
        assertEq(voteCast, 1);
        assertEq(choiceId, 0);
        assertFalse(abstention);
        assertFalse(isUndo);
    }

    function testVoterReceiptWithUndo() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.enableUndoVote(_proposalId, _SUPERVISOR);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1));
        _storage.undoVoteById(_proposalId, _VOTER1, uint160(_VOTER1));

        (uint256 shareId, uint256 shareFor, uint256 voteCast, uint256 choiceId, bool abstention, bool isUndo) = _storage
            .getVoteReceipt(_proposalId, uint160(_VOTER1));

        assertEq(shareId, uint160(_VOTER1));
        assertEq(shareFor, 1);
        assertEq(voteCast, 1);
        assertEq(choiceId, 0);
        assertFalse(abstention);
        assertTrue(isUndo);
    }

    function testAgainstWithUndo() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.enableUndoVote(_proposalId, _SUPERVISOR);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteAgainstByShare(_proposalId, _VOTER1, uint160(_VOTER1));
        vm.expectRevert("Vote not affirmative");
        _storage.undoVoteById(_proposalId, _VOTER1, uint160(_VOTER1));
    }

    function testAbstainWithUndo() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.enableUndoVote(_proposalId, _SUPERVISOR);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.abstainForShare(_proposalId, _VOTER1, uint160(_VOTER1));
        vm.expectRevert("No affirmative vote");
        _storage.undoVoteById(_proposalId, _VOTER1, uint160(_VOTER1));
    }

    function testVoteAgainstReceipt() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteAgainstByShare(_proposalId, _VOTER1, uint160(_VOTER1));

        (uint256 shareId, uint256 shareFor, uint256 voteCast, uint256 choiceId, bool abstention, bool isUndo) = _storage
            .getVoteReceipt(_proposalId, uint160(_VOTER1));

        assertEq(shareId, uint160(_VOTER1));
        assertEq(shareFor, 0);
        assertEq(voteCast, 1);
        assertEq(choiceId, 0);
        assertFalse(abstention);
        assertFalse(isUndo);
    }

    function testAbstentionReceipt() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.abstainForShare(_proposalId, _VOTER1, uint160(_VOTER1));

        (uint256 shareId, uint256 shareFor, uint256 voteCast, uint256 choiceId, bool abstention, bool isUndo) = _storage
            .getVoteReceipt(_proposalId, uint160(_VOTER1));

        assertEq(shareId, uint160(_VOTER1));
        assertEq(shareFor, 0);
        assertEq(voteCast, 1);
        assertEq(choiceId, 0);
        assertTrue(abstention);
        assertFalse(isUndo);
    }

    function testVoterDirectlyCastOneVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_VOTER1);
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1));
    }

    function testQuorumAllThree() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1));
        assertEq(_storage.forVotes(_proposalId), 1);
        _storage.voteAgainstByShare(_proposalId, _VOTER2, uint160(_VOTER2));
        assertEq(_storage.againstVotes(_proposalId), 1);
        _storage.abstainForShare(_proposalId, _VOTER3, uint160(_VOTER3));
        assertEq(_storage.abstentionCount(_proposalId), 1);
        assertEq(_storage.quorum(_proposalId), 3);
    }

    function testCastOneVoteFromAll() public {
        _storage = new GovernanceStorage(
            new VoterClassOpenVote(1),
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            "",
            "",
            ""
        );
        _storage.initializeProposal(0, _OWNER);
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1));
        assertEq(_storage.quorum(_proposalId), 1);
    }

    function testCastVoteFromERC721() public {
        uint256 tokenId = 0x71;
        MockERC721 token = new MockERC721();
        token.mintTo(_VOTER2, tokenId);
        _storage = new GovernanceStorage(
            new VoterClassERC721(address(token), 1),
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            "",
            "",
            ""
        );
        _storage.initializeProposal(0, _OWNER);
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 1, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteForByShare(_proposalId, _VOTER2, tokenId);
        assertEq(_storage.forVotes(_proposalId), 1);
        assertEq(_storage.againstVotes(_proposalId), 0);
        assertEq(_storage.abstentionCount(_proposalId), 0);
        assertEq(_storage.quorum(_proposalId), 1);
    }

    function testPermittedAfterObservingVoteDelay() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 1, _SUPERVISOR);
        _storage.setVoteDelay(_proposalId, 3600, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        uint256 startTime = block.timestamp;
        vm.warp(startTime + 3600);
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1));
        assertEq(1, _storage.forVotes(_proposalId));
    }

    function testVoteWithUndo() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.enableUndoVote(_proposalId, _SUPERVISOR);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1));
        assertEq(_storage.quorum(_proposalId), 1);
        _storage.undoVoteById(_proposalId, _VOTER1, uint160(_VOTER1));
        assertEq(_storage.quorum(_proposalId), NONE);
    }

    function testVoteWithDoubleUndo() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.enableUndoVote(_proposalId, _SUPERVISOR);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1));
        _storage.undoVoteById(_proposalId, _VOTER1, uint160(_VOTER1));
        vm.expectRevert("No affirmative vote");
        _storage.undoVoteById(_proposalId, _VOTER1, uint160(_VOTER1));
    }

    function testName() public {
        assertEq(_storage.name(), "collective storage");
    }

    function testVersion() public {
        assertEq(_storage.version(), 1);
    }

    function testLatestProposalAfterEnd() public {
        uint256 latestProposalId = _storage.latestProposal(_OWNER);
        assertEq(_proposalId, latestProposalId);
        _storage.registerSupervisor(latestProposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(latestProposalId, _SUPERVISOR);
        uint256 endTime = _storage.endTime(latestProposalId);
        vm.warp(endTime);
        uint256 nextId = _storage.initializeProposal(0, _OWNER);
        latestProposalId = _storage.latestProposal(_OWNER);
        assertEq(latestProposalId, nextId);
    }

    function testCancelThenNewProposal() public {
        uint256 latestProposalId = _storage.latestProposal(_OWNER);
        assertEq(_proposalId, latestProposalId);
        _storage.registerSupervisor(latestProposalId, _SUPERVISOR, _OWNER);
        _storage.cancel(latestProposalId, _SUPERVISOR);
        uint256 endTime = _storage.endTime(latestProposalId);
        vm.warp(endTime);
        uint256 nextId = _storage.initializeProposal(0, _OWNER);
        latestProposalId = _storage.latestProposal(_OWNER);
        assertEq(latestProposalId, nextId);
    }

    function testLatestRevertIfNone() public {
        vm.expectRevert("No proposal");
        _storage.latestProposal(_SUPERVISOR);
    }

    function testAllowProposalIfFinal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.warp(block.timestamp + Constant.MINIMUM_VOTE_DURATION + 1);
        uint256 nextProposalId = _storage.initializeProposal(0, _OWNER);
        assertTrue(nextProposalId > _proposalId);
    }

    function testNotExemptFromDelayIfCancelled() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.cancel(_proposalId, _SUPERVISOR);
        vm.expectRevert("Too many proposals");
        _storage.initializeProposal(0, _OWNER);
    }

    function testRevertOnSecondProposal() public {
        vm.expectRevert("Too many proposals");
        _storage.initializeProposal(0, _OWNER);
    }

    function testCancelProposalNotReady() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.cancel(_proposalId, _SUPERVISOR);
        assertTrue(_storage.isCancel(_proposalId));
    }

    function testCancelProposal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        assertFalse(_storage.isCancel(_proposalId));
        _storage.cancel(_proposalId, _SUPERVISOR);
        assertTrue(_storage.isCancel(_proposalId));
    }

    function testCancelFailIfNotSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Requires supervisor");
        _storage.cancel(_proposalId, _NOTSUPERVISOR);
    }

    function testFailTransferNotOwner() public {
        GovernanceStorage _gStorage = new GovernanceStorage(
            _storage.voterClass(),
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MINIMUM_PROJECT_QUORUM,
            "",
            "",
            ""
        );
        vm.prank(_SUPERVISOR);
        _gStorage.transferOwnership(_SUPERVISOR);
    }

    function testAddTransaction() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        uint256 tid1 = _storage.addTransaction(_proposalId, address(0x1), 0x10, "", "", scheduleTime, "", _OWNER);
        assertEq(tid1, 0);
        uint256 tid2 = _storage.addTransaction(_proposalId, address(0x2), 0x20, "", "", scheduleTime, "", _OWNER);
        assertEq(tid2, 1);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
    }

    function testAddTransactionNotOwner() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Not creator");
        _storage.addTransaction(_proposalId, address(0x1), 0x10, "", "", scheduleTime, "", _SUPERVISOR);
    }

    function testAddTransactionIfFinal() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.addTransaction(_proposalId, address(0x1), 0x10, "", "", scheduleTime, "", _OWNER);
    }

    function testClearTransactionIfFinal() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        uint256 tid = _storage.addTransaction(_proposalId, address(0x1), 0x10, "", "", scheduleTime, "", _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.clearTransaction(_proposalId, tid, _OWNER);
    }

    function testGetTransaction() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        Storage.Transaction memory transaction = Storage.Transaction(address(0x1), 0x10, "ziggy", "a()", scheduleTime, "abc123");
        uint256 tid = _storage.addTransaction(
            _proposalId,
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
        ) = _storage.getTransaction(_proposalId, tid);
        assertEq(target, transaction.target);
        assertEq(value, transaction.value);
        assertEq(signature, transaction.signature);
        assertEq(_calldata, transaction._calldata);
        assertEq(scheduleTimeRet, transaction.scheduleTime);
        assertEq(txHash, transaction.txHash);
    }

    function testClearTransaction() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        uint256 tid1 = _storage.addTransaction(_proposalId, address(0x1), 0x10, "", "", scheduleTime, "tx1", _OWNER);
        assertEq(tid1, 0);
        uint256 tid2 = _storage.addTransaction(_proposalId, address(0x2), 0x20, "f()", "1", scheduleTime + 1, "tx2", _OWNER);
        assertEq(tid2, 1);
        _storage.clearTransaction(_proposalId, tid1, _OWNER);
        (
            address target,
            uint256 value,
            string memory signature,
            bytes memory _calldata,
            uint256 scheduleTimeRet,
            bytes32 txHash
        ) = _storage.getTransaction(_proposalId, tid1);
        assertEq(target, address(0x0));
        assertEq(value, 0);
        assertEq(signature, "");
        assertEq(_calldata, "");
        assertEq(scheduleTimeRet, 0);
        assertEq(txHash, "");

        (target, value, signature, _calldata, scheduleTimeRet, txHash) = _storage.getTransaction(_proposalId, tid2);
        assertEq(target, address(0x2));
        assertEq(value, 0x20);
        assertEq(signature, "f()");
        assertEq(_calldata, "1");
        assertEq(scheduleTimeRet, scheduleTime + 1);
        assertEq(txHash, "tx2");
    }

    function testSetExecuted() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        assertFalse(_storage.isExecuted(_proposalId));
        _storage.setExecuted(_proposalId, _OWNER);
        assertTrue(_storage.isExecuted(_proposalId));
    }

    function testSetExecutedNotOwner() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Not creator");
        _storage.setExecuted(_proposalId, _SUPERVISOR);
    }

    function testSetProposalUrl() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setProposalUrl(_proposalId, "https://collective.xyz", _SUPERVISOR);
        assertEq(_storage.url(_proposalId), "https://collective.xyz");
    }

    function testSetProposalUrlIfFinal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.setProposalUrl(_proposalId, "https://collective.xyz", _SUPERVISOR);
    }

    function testSetProposalUrlNotSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Requires supervisor");
        _storage.setProposalUrl(_proposalId, "https://collective.xyz", _VOTER1);
    }

    function testSetProposalUrlNotOwner() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_VOTER1);
        _storage.setProposalUrl(_proposalId, "https://collective.xyz", _SUPERVISOR);
    }

    function testFailSetProposalUrlTooLarge() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setProposalUrl(_proposalId, TestData.pi1kplus(), _SUPERVISOR);
    }

    function testSetProposalDescription() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setProposalDescription(_proposalId, "A project to build governance for all communities", _SUPERVISOR);
        assertEq(_storage.description(_proposalId), "A project to build governance for all communities");
    }

    function testSetProposalDescriptionIfFinal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.setProposalDescription(_proposalId, "A project to build governance for all communities", _SUPERVISOR);
    }

    function testSetProposalDescriptionNotSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Requires supervisor");
        _storage.setProposalDescription(_proposalId, "A project to build governance for all communities", _VOTER1);
    }

    function testSetProposalDescriptionNotOwner() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_VOTER1);
        _storage.setProposalDescription(_proposalId, "Url", _SUPERVISOR);
    }

    function testFailSetProposalDescriptionTooLarge() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setProposalDescription(_proposalId, TestData.pi1kplus(), _SUPERVISOR);
    }

    function testMetaCountInitialValue() public {
        assertEq(_storage.metaCount(_proposalId), 0);
    }

    function testMetaCount() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < 10; i++) {
            _storage.addMeta(_proposalId, "a", "1", _SUPERVISOR);
        }
        assertEq(_storage.metaCount(_proposalId), 10);
    }

    function testAddMeta() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        uint256 m1 = _storage.addMeta(_proposalId, "a", "1", _SUPERVISOR);
        uint256 m2 = _storage.addMeta(_proposalId, "b", "2", _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        (bytes32 m1name, string memory m1value) = _storage.getMeta(_proposalId, m1);
        assertEq(m1name, "a");
        assertEq(m1value, "1");
        (bytes32 m2name, string memory m2value) = _storage.getMeta(_proposalId, m2);
        assertEq(m2name, "b");
        assertEq(m2value, "2");
    }

    function testAddMetaIfFinal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.addMeta(_proposalId, "a", "1", _SUPERVISOR);
    }

    function testAddMetaNotOwner() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.addMeta(_proposalId, "a", "1", _SUPERVISOR);
    }

    function testAddMetaNotSupervisor() public {
        vm.expectRevert("Requires supervisor");
        _storage.addMeta(_proposalId, "a", "1", _VOTER1);
    }

    function testFailAddMetaValueTooLarge() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.addMeta(_proposalId, "a", TestData.pi1kplus(), _SUPERVISOR);
    }

    function testGetWinnerForNoChoice() public {
        vm.expectRevert("No choice");
        _storage.getWinningChoice(_proposalId);
    }
}

contract GovernanceStorageChoiceVoteTest is Test {
    address private constant _OWNER = address(0x155);
    address private constant _SUPERVISOR = address(0x123);
    address private constant _VOTER1 = address(0xfff1);
    address private constant _VOTER2 = address(0xfff2);
    address private constant _VOTER3 = address(0xfff3);

    uint256 public constant _NCHOICE = 5;

    StorageFactory private _storageFactory;
    Storage private _storage;
    VoteStrategy private _strategy;
    uint256 private _proposalId;

    function setUp() public {
        vm.clearMockedCalls();
        _storageFactory = new StorageFactory();
        VoterClassVoterPool _voterClass = new VoterClassVoterPool(1);
        _voterClass.addVoter(_VOTER1);
        _voterClass.addVoter(_VOTER2);
        _voterClass.addVoter(_VOTER3);
        _voterClass.makeFinal();
        _storage = _storageFactory.create(
            _voterClass,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            "",
            "",
            ""
        );
        _proposalId = _storage.initializeProposal(_NCHOICE, _OWNER);
    }

    function testSetChoiceProposal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        assertEq(_storage.choiceCount(_proposalId), 5);
    }

    function testSetChoiceProposalReqOwner() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.setChoice(_proposalId, 0, "name", "description", 0, _SUPERVISOR);
    }

    function testSetChoiceProposalReqValidProposal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Invalid proposal");
        _storage.setChoice(_proposalId + 1, 0, "name", "description", 0, _SUPERVISOR);
    }

    function testSetChoiceNotFinal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Vote not modifiable");
        _storage.setChoice(_proposalId, 0, "name", "description", 0, _SUPERVISOR);
    }

    function testSetChoiceRequiresSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Requires supervisor");
        _storage.setChoice(_proposalId, 0, "name", "description", 0, _OWNER);
    }

    function testSetChoiceRequiresName() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Name is required");
        _storage.setChoice(_proposalId, 0, 0x0, "description", 0, _SUPERVISOR);
    }

    function testSetChoiceDescriptionWrongChoiceId() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Invalid choice id");
        _storage.setChoice(_proposalId, _NCHOICE, "NAME", "description", 0, _SUPERVISOR);
    }

    function testSetChoiceDescriptionExceedsLimit() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        string memory limitedString = TestData.pi1kplus();
        vm.expectRevert("Description exceeds data limit");
        _storage.setChoice(_proposalId, 0, "NAME", limitedString, 0, _SUPERVISOR);
    }

    function testGetChoice() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            (bytes32 _name, string memory description, uint256 tid, uint256 voteCount) = _storage.getChoice(_proposalId, i);
            assertEq(_name, "name");
            assertEq(description, "description");
            assertEq(tid, 0);
            assertEq(voteCount, 0);
        }
    }

    function testChoiceWithValidTransaction() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);

        for (uint256 i = 0; i < _NCHOICE; i++) {
            uint256 tid = _storage.addTransaction(
                _proposalId,
                address(0x113e),
                i + 1,
                "",
                "",
                block.timestamp,
                "0x04812",
                _OWNER
            );
            assertEq(tid, i);
        }
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", i, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            (bytes32 _name, string memory description, uint256 tid, uint256 voteCount) = _storage.getChoice(_proposalId, i);
            assertEq(_name, "name");
            assertEq(description, "description");
            assertEq(tid, i);
            assertEq(voteCount, 0);
        }
    }

    function testChoiceProposalVoteRequiresChoiceId() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Choice not possible");
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1));
    }

    function testChoiceProposalAgainstNotAllowed() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Choice not possible");
        _storage.voteAgainstByShare(_proposalId, _VOTER1, uint160(_VOTER1));
    }

    function testCastOneVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1), 1);
        assertEq(_storage.voteCount(_proposalId, 1), 1);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            if (i != 1) {
                assertEq(_storage.voteCount(_proposalId, i), 0);
            }
        }
        assertEq(_storage.quorum(_proposalId), 1);
    }

    function testCastMultiVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        for (uint256 i = 0; i < 3; i++) {
            _storage.voteForByShare(_proposalId, address(uint160(_VOTER1) + uint160(i)), uint160(_VOTER1) + i, i);
        }
        assertEq(_storage.voteCount(_proposalId, 1), 1);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(_storage.voteCount(_proposalId, i), 1);
        }
        for (uint256 i = 3; i < _NCHOICE; i++) {
            assertEq(_storage.voteCount(_proposalId, i), 0);
        }
        assertEq(_storage.quorum(_proposalId), 3);
    }

    function testAbstainVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.abstainForShare(_proposalId, _VOTER1, uint160(_VOTER1));
        for (uint256 i = 0; i < _NCHOICE; i++) {
            assertEq(_storage.voteCount(_proposalId, i), 0);
        }
        assertEq(_storage.quorum(_proposalId), 1);
    }

    function testCastVoteWrongShare() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Not a valid share");
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER2), 1);
    }

    function testCastVoteBadProposal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Invalid proposal");
        _storage.voteForByShare(_proposalId + 1, _VOTER1, uint160(_VOTER1), 1);
    }

    function testCastVoteVoteEnded() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.warp(_storage.endTime(_proposalId));
        vm.expectRevert("Vote not active");
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1), 1);
    }

    function testReceiptForChoice() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1), 1);
        (uint256 shareId, uint256 shareFor, uint256 votesCast, uint256 choiceId, bool isAbstention, bool isUndo) = _storage
            .getVoteReceipt(_proposalId, uint160(_VOTER1));
        assertEq(shareId, uint160(_VOTER1));
        assertEq(shareFor, 1);
        assertEq(votesCast, 1);
        assertEq(choiceId, 1);
        assertFalse(isAbstention);
        assertFalse(isUndo);
    }

    function testIsChoiceVote() public {
        assertTrue(_storage.isChoiceVote(_proposalId));
    }
}

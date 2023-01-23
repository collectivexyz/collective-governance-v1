// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable not-rely-on-time
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC721.sol";

import "forge-std/Test.sol";

import "../contracts/Constant.sol";
import "../contracts/storage/StorageFactory.sol";
import "../contracts/CollectiveGovernance.sol";
import "../contracts/VoteStrategy.sol";
import "../contracts/community/VoterClass.sol";
import "../contracts/community/CommunityClassVoterPool.sol";
import "../contracts/community/CommunityClassERC721.sol";
import "../contracts/community/CommunityClassOpenVote.sol";
import "../contracts/access/Versioned.sol";

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
    CommunityClass private _voterClass;
    uint256 private _proposalId;

    function setUp() public {
        vm.clearMockedCalls();
        _storageFactory = new StorageFactory();
        CommunityClassVoterPool _class = new CommunityClassVoterPool(
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );
        _class.addVoter(_VOTER1);
        _class.addVoter(_VOTER2);
        _class.addVoter(_VOTER3);
        _class.makeFinal();
        _voterClass = _class;
        _storage = _storageFactory.create(_voterClass);
        _proposalId = _storage.initializeProposal(0, _OWNER);
        assertEq(_proposalId, PROPOSAL_ID);
    }

    function testVotesCastZero() public {
        assertEq(_storage.forVotes(_proposalId), NONE);
        assertEq(_storage.againstVotes(_proposalId), NONE);
        assertEq(_storage.abstentionCount(_proposalId), NONE);
        assertEq(_storage.quorum(_proposalId), NONE);
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
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidProposal.selector, 0));
        _storage.registerSupervisor(0, _SUPERVISOR, _OWNER);
    }

    function testRegisterSupervisorIfOpen() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.VoteIsFinal.selector, _proposalId));
        _storage.registerSupervisor(_proposalId, _NOTSUPERVISOR, _OWNER);
    }

    function testRegisterProjectSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, true, _OWNER);
        assertTrue(_storage.isSupervisor(_proposalId, _SUPERVISOR));
    }

    function testBurnProjectSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, true, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.ProjectSupervisor.selector, _proposalId, _SUPERVISOR));
        _storage.burnSupervisor(_proposalId, _SUPERVISOR, _OWNER);
    }

    function testBurnNonSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, true, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.NotSupervisor.selector, _proposalId, _VOTER1));
        _storage.burnSupervisor(_proposalId, _VOTER1, _OWNER);
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
        vm.expectRevert(abi.encodeWithSelector(Storage.NotSupervisor.selector, _proposalId, _SUPERVISOR));
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

    function testSetQuorumRequiredIfFinal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.VoteIsFinal.selector, _proposalId));
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

    function testSetVoteDelayNotSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_OWNER);
        _storage.setVoteDelay(_proposalId, 100, _OWNER);
    }

    function testSetVoteDelayIfFinal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.VoteIsFinal.selector, _proposalId));
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
        vm.expectRevert(
            abi.encodeWithSelector(Storage.DurationNotPermitted.selector, _proposalId, 0, Constant.MINIMUM_VOTE_DURATION)
        );
        _storage.setVoteDuration(_proposalId, 0, _SUPERVISOR);
    }

    function testSetMinimumVoteDurationShort() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                Storage.DurationNotPermitted.selector,
                _proposalId,
                Constant.MINIMUM_VOTE_DURATION - 1,
                Constant.MINIMUM_VOTE_DURATION
            )
        );
        _storage.setVoteDuration(_proposalId, Constant.MINIMUM_VOTE_DURATION - 1, _SUPERVISOR);
    }

    function testSetMinimumVoteDurationIfFinal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.VoteIsFinal.selector, _proposalId));
        _storage.setVoteDuration(_proposalId, 1, _SUPERVISOR);
    }

    function testSetMinimumVoteDurationNotSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.NotSupervisor.selector, _proposalId, _OWNER));
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
        vm.expectRevert(abi.encodeWithSelector(Storage.VoteIsFinal.selector, _proposalId));
        _storage.makeFinal(_proposalId, _SUPERVISOR);
    }

    function testMakeReadyRequireSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.NotSupervisor.selector, _proposalId, _OWNER));
        _storage.makeFinal(_proposalId, _OWNER);
    }

    function testVeto() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        assertFalse(_storage.isVeto(_proposalId));
        _storage.veto(_proposalId, _SUPERVISOR);
        assertTrue(_storage.isVeto(_proposalId));
    }

    function testIsVetoInvalidProposal() public {
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidProposal.selector, _proposalId + 1));
        _storage.isVeto(_proposalId + 1);
    }

    function testVetoDirect() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.veto(_proposalId, _SUPERVISOR);
    }

    function testOwnerMayNotVeto() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.NotSupervisor.selector, _proposalId, _OWNER));
        _storage.veto(_proposalId, _OWNER);
    }

    function testVoterMayNotVeto() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.NotSupervisor.selector, _proposalId, _VOTER1));
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

    function testCastVoteNotChoiceVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.NotChoiceVote.selector, _proposalId));
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1), 1);
    }

    function testVoterReceipt() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1));

        (uint256 shareId, uint256 shareFor, uint256 voteCast, uint256 choiceId, bool abstention) = _storage.getVoteReceipt(
            _proposalId,
            uint160(_VOTER1)
        );

        assertEq(shareId, uint160(_VOTER1));
        assertEq(shareFor, 1);
        assertEq(voteCast, 1);
        assertEq(choiceId, 0);
        assertFalse(abstention);
    }

    function testVoteAgainstReceipt() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteAgainstByShare(_proposalId, _VOTER1, uint160(_VOTER1));

        (uint256 shareId, uint256 shareFor, uint256 voteCast, uint256 choiceId, bool abstention) = _storage.getVoteReceipt(
            _proposalId,
            uint160(_VOTER1)
        );

        assertEq(shareId, uint160(_VOTER1));
        assertEq(shareFor, 0);
        assertEq(voteCast, 1);
        assertEq(choiceId, 0);
        assertFalse(abstention);
    }

    function testAbstentionReceipt() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.setQuorumRequired(_proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.abstainForShare(_proposalId, _VOTER1, uint160(_VOTER1));

        (uint256 shareId, uint256 shareFor, uint256 voteCast, uint256 choiceId, bool abstention) = _storage.getVoteReceipt(
            _proposalId,
            uint160(_VOTER1)
        );

        assertEq(shareId, uint160(_VOTER1));
        assertEq(shareFor, 0);
        assertEq(voteCast, 1);
        assertEq(choiceId, 0);
        assertTrue(abstention);
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
        CommunityClass _class = new CommunityClassOpenVote(
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );
        _storage = new GovernanceStorage(_class);
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
        CommunityClass _class = new CommunityClassERC721(
            address(token),
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );

        _storage = new GovernanceStorage(_class);
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

    function testName() public {
        assertEq(_storage.name(), "collective storage");
    }

    function testVersion() public {
        assertEq(_storage.version(), Constant.VERSION_2);
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
        vm.expectRevert(abi.encodeWithSelector(Storage.NoProposal.selector, _VOTER3));
        _storage.latestProposal(_VOTER3);
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
        vm.expectRevert(abi.encodeWithSelector(Storage.TooManyProposals.selector, _OWNER, _proposalId));
        _storage.initializeProposal(0, _OWNER);
    }

    function testRevertOnSecondProposal() public {
        vm.expectRevert(abi.encodeWithSelector(Storage.TooManyProposals.selector, _OWNER, _proposalId));
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
        vm.expectRevert(abi.encodeWithSelector(Storage.NotSupervisor.selector, _proposalId, _NOTSUPERVISOR));
        _storage.cancel(_proposalId, _NOTSUPERVISOR);
    }

    function testFailTransferNotOwner() public {
        GovernanceStorage _gStorage = new GovernanceStorage(_voterClass);
        vm.prank(_SUPERVISOR);
        _gStorage.transferOwnership(_SUPERVISOR);
    }

    function testAddTransaction() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        uint256 tid1 = _storage.addTransaction(_proposalId, address(0x1), 0x10, "", "", scheduleTime, "0x1", _OWNER);
        assertEq(tid1, 1);
        uint256 tid2 = _storage.addTransaction(_proposalId, address(0x2), 0x20, "", "", scheduleTime, "0x1", _OWNER);
        assertEq(tid2, 2);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
    }

    function testAddTransactionHashInvalid() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.TransactionHashInvalid.selector, _proposalId, bytes32(0x0)));
        _storage.addTransaction(_proposalId, address(0x1), 0x10, "", "", scheduleTime, "", _OWNER);
    }

    function testAddTransactionNotOwner() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.NotSender.selector, _proposalId, _SUPERVISOR));
        _storage.addTransaction(_proposalId, address(0x1), 0x10, "", "", scheduleTime, "0x1", _SUPERVISOR);
    }

    function testAddTransactionIfFinal() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.VoteIsFinal.selector, _proposalId));
        _storage.addTransaction(_proposalId, address(0x1), 0x10, "", "", scheduleTime, "0x1", _OWNER);
    }

    function testClearTransactionIfFinal() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        uint256 tid = _storage.addTransaction(_proposalId, address(0x1), 0x10, "", "", scheduleTime, "0x1", _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.VoteIsFinal.selector, _proposalId));
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

    function testGetZeroTransaction() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        Storage.Transaction memory transaction = Storage.Transaction(address(0x1), 0x10, "ziggy", "a()", scheduleTime, "abc123");
        _storage.addTransaction(
            _proposalId,
            transaction.target,
            transaction.value,
            transaction.signature,
            transaction._calldata,
            transaction.scheduleTime,
            transaction.txHash,
            _OWNER
        );
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidTransaction.selector, _proposalId, 0));
        _storage.getTransaction(_proposalId, 0);
    }

    function testGetInvalidTransaction() public {
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
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidTransaction.selector, _proposalId, tid + 1));
        _storage.getTransaction(_proposalId, tid + 1);
    }

    function testClearTransaction() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        uint256 tid1 = _storage.addTransaction(_proposalId, address(0x1), 0x10, "", "", scheduleTime, "tx1", _OWNER);
        assertEq(tid1, 1);
        uint256 tid2 = _storage.addTransaction(_proposalId, address(0x2), 0x20, "f()", "1", scheduleTime + 1, "tx2", _OWNER);
        assertEq(tid2, 2);
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
        _storage.setExecuted(_proposalId);
        assertTrue(_storage.isExecuted(_proposalId));
    }

    function testSetExecutedNotOwner() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR, _SUPERVISOR);
        _storage.setExecuted(_proposalId);
    }

    function testGetWinnerForNoChoice() public {
        vm.expectRevert(abi.encodeWithSelector(Storage.NotChoiceVote.selector, _proposalId));
        _storage.getWinningChoice(_proposalId);
    }

    function testSetChoiceNotProposal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.NotChoiceVote.selector, _proposalId));
        _storage.setChoice(_proposalId, 0, "name", "description", 0, _SUPERVISOR);
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
        CommunityClassVoterPool _voterClass = new CommunityClassVoterPool(
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );
        _voterClass.addVoter(_VOTER1);
        _voterClass.addVoter(_VOTER2);
        _voterClass.addVoter(_VOTER3);
        _voterClass.makeFinal();
        _storage = _storageFactory.create(_voterClass);
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
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidProposal.selector, _proposalId + 1));
        _storage.setChoice(_proposalId + 1, 0, "name", "description", 0, _SUPERVISOR);
    }

    function testSetChoiceNotFinal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.VoteIsFinal.selector, _proposalId));
        _storage.setChoice(_proposalId, 0, "name", "description", 0, _SUPERVISOR);
    }

    function testSetChoiceNotSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.NotSupervisor.selector, _proposalId, _OWNER));
        _storage.setChoice(_proposalId, 0, "name", "description", 0, _OWNER);
    }

    function testSetChoiceRequiresName() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.ChoiceNameRequired.selector, _proposalId, 0));
        _storage.setChoice(_proposalId, 0, 0x0, "description", 0, _SUPERVISOR);
    }

    function testSetChoiceDescriptionWrongChoiceId() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.ChoiceIdInvalid.selector, _proposalId, _NCHOICE));
        _storage.setChoice(_proposalId, _NCHOICE, "NAME", "description", 0, _SUPERVISOR);
    }

    function testSetChoiceDescriptionExceedsLimit() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        string memory limitedString = TestData.pi1kplus();
        uint256 descLen = Constant.len(limitedString);
        vm.expectRevert(
            abi.encodeWithSelector(
                Storage.ChoiceDescriptionExceedsDataLimit.selector,
                _proposalId,
                0,
                descLen,
                Constant.STRING_DATA_LIMIT
            )
        );
        _storage.setChoice(_proposalId, 0, "NAME", limitedString, 0, _SUPERVISOR);
    }

    function testGetChoice() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            (bytes32 _name, string memory description, uint256 tid, bytes32 txHash, uint256 voteCount) = _storage.getChoice(
                _proposalId,
                i
            );
            assertEq(_name, "name");
            assertEq(description, "description");
            assertEq(tid, 0);
            assertEq(txHash, 0);
            assertEq(voteCount, 0);
        }
    }

    function testChoiceWithValidTransaction() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);

        for (uint256 i = 0; i < _NCHOICE; i++) {
            (address target, uint256 value, string memory _signature, bytes memory _calldata, uint256 scheduleTime) = (
                address(0x113e),
                i + 1,
                "",
                "",
                block.timestamp
            );
            bytes32 calculatedHash = Constant.getTxHash(target, value, _signature, _calldata, scheduleTime);
            uint256 tid = _storage.addTransaction(
                _proposalId,
                target,
                value,
                _signature,
                _calldata,
                scheduleTime,
                calculatedHash,
                _OWNER
            );
            assertEq(tid, i + 1);
            _storage.setChoice(_proposalId, i, "name", "description", tid, _SUPERVISOR);
            vm.warp(block.timestamp + 1);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            (bytes32 _name, string memory description, uint256 tid, bytes32 txHash, uint256 voteCount) = _storage.getChoice(
                _proposalId,
                i
            );
            assertEq(_name, "name");
            assertEq(description, "description");
            assertEq(tid, i + 1);
            assertEq(voteCount, 0);
            (, , , , , bytes32 _txHash) = _storage.getTransaction(_proposalId, tid);
            assertEq(txHash, _txHash);
        }
    }

    function testChoiceWithInvalidTransaction() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);

        for (uint256 i = 0; i < _NCHOICE; i++) {
            (address target, uint256 value, string memory _signature, bytes memory _calldata, uint256 scheduleTime) = (
                address(0x113e),
                i + 1,
                "",
                "",
                block.timestamp
            );
            bytes32 calculatedHash = Constant.getTxHash(target, value, _signature, _calldata, scheduleTime);
            _storage.addTransaction(_proposalId, target, value, _signature, _calldata, scheduleTime, calculatedHash, _OWNER);
            vm.warp(block.timestamp + 1);
        }
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidTransaction.selector, _proposalId, _NCHOICE + 1));
        _storage.setChoice(_proposalId, 0, "name", "description", _NCHOICE + 1, _SUPERVISOR);
    }

    function testChoiceProposalVoteRequiresChoiceId() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.ChoiceRequired.selector, _proposalId));
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1));
    }

    function testChoiceProposalAgainstNotAllowed() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.ChoiceRequired.selector, _proposalId));
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

    function testCastVoteWithoutChoice() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.ChoiceRequired.selector, _proposalId));
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1));
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
        vm.expectRevert(abi.encodeWithSelector(VoterClass.UnknownToken.selector, uint160(_VOTER2)));
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER2), 1);
    }

    function testCastVoteBadProposal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidProposal.selector, _proposalId + 1));
        _storage.voteForByShare(_proposalId + 1, _VOTER1, uint160(_VOTER1), 1);
    }

    function testCastVoteEnded() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        uint256 startTime = _storage.startTime(_proposalId);
        uint256 endTime = _storage.endTime(_proposalId);
        vm.warp(endTime + 1);
        vm.expectRevert(abi.encodeWithSelector(Storage.VoteNotActive.selector, _proposalId, startTime, endTime, block.timestamp));
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1), 1);
    }

    function testReceiptForChoice() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.setChoice(_proposalId, i, "name", "description", 0, _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1), 1);
        (uint256 shareId, uint256 shareFor, uint256 votesCast, uint256 choiceId, bool isAbstention) = _storage.getVoteReceipt(
            _proposalId,
            uint160(_VOTER1)
        );
        assertEq(shareId, uint160(_VOTER1));
        assertEq(shareFor, 1);
        assertEq(votesCast, 1);
        assertEq(choiceId, 1);
        assertFalse(isAbstention);
    }

    function testIsChoiceVote() public {
        assertTrue(_storage.isChoiceVote(_proposalId));
    }

    function testSupportsInterfaceStorage() public {
        bytes4 ifId = type(Storage).interfaceId;
        assertTrue(_storage.supportsInterface(ifId));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_storage.supportsInterface(ifId));
    }

    function testSupportsInterfaceOwnable() public {
        bytes4 ifId = type(Ownable).interfaceId;
        assertTrue(_storage.supportsInterface(ifId));
    }
}

// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable not-rely-on-time
pragma solidity ^0.8.15;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";

import { Test } from "forge-std/Test.sol";

import { Constant } from "../../contracts/Constant.sol";
import { Transaction, TransactionCollection, getHash } from "../../contracts/collection/TransactionSet.sol";
import { Choice, ChoiceCollection,getHash } from "../../contracts/collection/ChoiceSet.sol";
import { CollectiveGovernance } from "../../contracts/governance/CollectiveGovernance.sol";
import { VoteStrategy } from "../../contracts/governance/VoteStrategy.sol";
import { createCommunityBuilder } from "../../contracts/community/CommunityBuilderProxy.sol";
import { CommunityBuilder } from "../../contracts/community/CommunityBuilder.sol";
import { CommunityClass } from "../../contracts/community/CommunityClass.sol";
import { VoterClass } from "../../contracts/community/VoterClass.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";
import { Storage } from "../../contracts/storage/Storage.sol";
import { GovernanceStorage } from "../../contracts/storage/GovernanceStorage.sol";
import { StorageFactory } from "../../contracts/storage/StorageFactory.sol";

import { TestData } from "../mock/TestData.sol";
import { MockERC721 } from "../mock/MockERC721.sol";

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

    CommunityBuilder private _builder;
    Storage private _storage;
    VoteStrategy private _strategy;
    CommunityClass private _voterClass;
    uint256 private _proposalId;

    function setUp() public {
        vm.clearMockedCalls();
        _builder = createCommunityBuilder();
        address _communityLocation = _builder
            .aCommunity()
            .asPoolCommunity()
            .withVoter(_VOTER1)
            .withVoter(_VOTER2)
            .withVoter(_VOTER3)
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        _voterClass = CommunityClass(_communityLocation);
        _storage = new StorageFactory().create(_voterClass);
        _proposalId = _storage.initializeProposal(_OWNER);
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
        address _classLocation = _builder
            .aCommunity()
            .asOpenCommunity()
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        CommunityClass _class = CommunityClass(_classLocation);
        _storage = new GovernanceStorage(_class);
        _storage.initializeProposal(_OWNER);
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
        address _classLocation = _builder
            .aCommunity()
            .asErc721Community(address(token))
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        CommunityClass _class = CommunityClass(_classLocation);
        _storage = new GovernanceStorage(_class);
        _storage.initializeProposal(_OWNER);
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

    function testLatestProposalAfterEnd() public {
        uint256 latestProposalId = _storage.latestProposal(_OWNER);
        assertEq(_proposalId, latestProposalId);
        _storage.registerSupervisor(latestProposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(latestProposalId, _SUPERVISOR);
        uint256 endTime = _storage.endTime(latestProposalId);
        vm.warp(endTime);
        uint256 nextId = _storage.initializeProposal(_OWNER);
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
        uint256 nextId = _storage.initializeProposal(_OWNER);
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
        uint256 nextProposalId = _storage.initializeProposal(_OWNER);
        assertTrue(nextProposalId > _proposalId);
    }

    function testNotExemptFromDelayIfCancelled() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.cancel(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.TooManyProposals.selector, _OWNER, _proposalId));
        _storage.initializeProposal(_OWNER);
    }

    function testRevertOnSecondProposal() public {
        vm.expectRevert(abi.encodeWithSelector(Storage.TooManyProposals.selector, _OWNER, _proposalId));
        _storage.initializeProposal(_OWNER);
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
        Transaction memory t1 = Transaction(address(0x1), 0x10, "", "", scheduleTime);
        uint256 tid1 = _storage.addTransaction(_proposalId, t1, _OWNER);
        assertEq(tid1, 1);
        Transaction memory t2 = Transaction(address(0x2), 0x20, "", "", scheduleTime);
        uint256 tid2 = _storage.addTransaction(_proposalId, t2, _OWNER);
        assertEq(tid2, 2);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
    }

    function testAddTransactionNotOwner() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        Transaction memory t1 = Transaction(address(0x1), 0x10, "", "", scheduleTime);
        vm.expectRevert(abi.encodeWithSelector(Storage.NotSender.selector, _proposalId, _SUPERVISOR));
        _storage.addTransaction(_proposalId, t1, _SUPERVISOR);
    }

    function testAddTransactionIfFinal() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        Transaction memory t1 = Transaction(address(0x1), 0x10, "", "", scheduleTime);
        vm.expectRevert(abi.encodeWithSelector(Storage.VoteIsFinal.selector, _proposalId));
        _storage.addTransaction(_proposalId, t1, _OWNER);
    }

    function testClearTransactionIfFinal() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        Transaction memory t1 = Transaction(address(0x1), 0x10, "", "", scheduleTime);
        uint256 tid = _storage.addTransaction(_proposalId, t1, _OWNER);
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.VoteIsFinal.selector, _proposalId));
        _storage.clearTransaction(_proposalId, tid, _OWNER);
    }

    function testGetTransaction() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        Transaction memory transaction = Transaction(address(0x1), 0x10, "ziggy", "a()", scheduleTime);
        uint256 tid = _storage.addTransaction(_proposalId, transaction, _OWNER);
        Transaction memory tt = _storage.getTransaction(_proposalId, tid);
        assertEq(tt.target, transaction.target);
        assertEq(tt.value, transaction.value);
        assertEq(tt.signature, transaction.signature);
        assertEq(tt._calldata, transaction._calldata);
        assertEq(tt.scheduleTime, transaction.scheduleTime);
        assertEq(abi.encode(tt), abi.encode(transaction));
    }

    function testGetZeroTransaction() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        Transaction memory transaction = Transaction(address(0x1), 0x10, "ziggy", "a()", scheduleTime);
        _storage.addTransaction(_proposalId, transaction, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(TransactionCollection.InvalidTransaction.selector, 0));
        _storage.getTransaction(_proposalId, 0);
    }

    function testGetInvalidTransaction() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        Transaction memory transaction = Transaction(address(0x1), 0x10, "ziggy", "a()", scheduleTime);
        uint256 tid = _storage.addTransaction(_proposalId, transaction, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(TransactionCollection.InvalidTransaction.selector, tid + 1));
        _storage.getTransaction(_proposalId, tid + 1);
    }

    function testClearTransaction() public {
        uint256 scheduleTime = block.timestamp + 7 days;
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);

        Transaction memory t1 = Transaction(address(0x1), 0x10, "", "", scheduleTime);
        uint256 tid1 = _storage.addTransaction(_proposalId, t1, _OWNER);
        assertEq(tid1, 1);
        Transaction memory t2 = Transaction(address(0x2), 0x20, "f()", "1", scheduleTime + 1);
        uint256 tid2 = _storage.addTransaction(_proposalId, t2, _OWNER);
        assertEq(tid2, 2);
        _storage.clearTransaction(_proposalId, tid1, _OWNER);
        Transaction memory trem = _storage.getTransaction(_proposalId, 1);
        assertEq(abi.encode(trem), abi.encode(t2));
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

    function testProposalAccessMapping() public {
        GovernanceStorage gs = GovernanceStorage(address(_storage));
        (uint id,,,,,,,,,,,,,,) = gs._proposalMap(PROPOSAL_ID);
        assertEq(id, PROPOSAL_ID);
    }

    function testProposalHackTransactionNotPossible() public {
        GovernanceStorage gs = GovernanceStorage(address(_storage));
        (,,,,,,,,,,,,,TransactionCollection collection,) = gs._proposalMap(PROPOSAL_ID);
        Transaction memory transaction = Transaction(address(0x123), 45, "six", "seven", 890);
        vm.expectRevert("Ownable: caller is not the owner");
        collection.add(transaction);
    }

    function testProposalHackChoiceNotPossible() public {
        GovernanceStorage gs = GovernanceStorage(address(_storage));
        (,,,,,,,,,,,,,,ChoiceCollection collection) = gs._proposalMap(PROPOSAL_ID);
        Choice memory choice = Choice("a1", "a choice", 53, "2123", 22);
        vm.expectRevert("Ownable: caller is not the owner");
        collection.add(choice);
    }
}


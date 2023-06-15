// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable not-rely-on-time
pragma solidity ^0.8.15;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import { ERC20PresetMinterPauser } from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

import { Test } from "forge-std/Test.sol";

import { Constant } from "../../contracts/Constant.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";
import { Transaction, getHash } from "../../contracts/collection/TransactionSet.sol";
import { VoterClass } from "../../contracts/community/VoterClass.sol";
import { CommunityClass } from "../../contracts/community/CommunityClass.sol";
import { CommunityBuilder } from "../../contracts/community/CommunityBuilder.sol";
import { createCommunityBuilder } from "../../contracts/community/CommunityBuilderProxy.sol";
import { Storage } from "../../contracts/storage/Storage.sol";
import { VoteStrategy } from "../../contracts/governance/VoteStrategy.sol";
import { Governance } from "../../contracts/governance/Governance.sol";
import { CollectiveGovernance, calculateGasRebate } from "../../contracts/governance/CollectiveGovernance.sol";
import { TimeLocker } from "../../contracts/treasury/TimeLocker.sol";
import { VersionedContract } from "../../contracts/access/VersionedContract.sol";
import { StorageFactory } from "../../contracts/storage/StorageFactory.sol";
import { MetaStorageFactory } from "../../contracts/storage/MetaStorageFactory.sol";
import { GovernanceFactory } from "../../contracts/governance/GovernanceFactory.sol";
import { GovernanceBuilder } from "../../contracts/governance/GovernanceBuilder.sol";
import { createGovernanceBuilder } from "../../contracts/governance/GovernanceBuilderProxy.sol";

import { MockERC721 } from "../mock/MockERC721.sol";
import { FlagSet } from "../mock/FlagSet.sol";
import { TestData } from "../mock/TestData.sol";

contract GasRebateTest is Test {
    function testGasRebate() public {
        uint256 startGas = gasleft();
        (uint256 gasRebate, uint256 gasUsed) = calculateGasRebate(startGas, 1 ether, 200 gwei, 200000);
        assertApproxEqAbs(gasRebate, 72234 gwei, 5000 gwei);
        assertTrue(gasUsed > 0);
    }

    function testMaximumRebate() public {
        uint256 startGas = gasleft();
        (uint256 gasRebate, uint256 gasUsed) = calculateGasRebate(startGas, 30 gwei, 200 gwei, 200000);
        assertEq(gasRebate, 30 gwei);
        assertTrue(gasUsed > 0);
    }
}

contract CollectiveGovernanceTest is Test {
    address private constant _OWNER = address(0x1);
    address private constant _SUPERVISOR = address(0x123);
    address private constant _NOT_SUPERVISOR = address(0x123eee);
    address private constant _VOTER1 = address(0xfff1);
    address private constant _VOTER2 = address(0xfff2);
    address private constant _VOTER3 = address(0xfff3);
    address private constant _NOT_VOTER = address(0xffff);

    uint256 private constant NONE = 0;
    uint256 private constant PROPOSAL_ID = 1;
    uint256 private constant TOKEN_ID1 = 77;
    uint256 private constant TOKEN_ID2 = TOKEN_ID1 + 1;
    uint256 private constant TOKEN_ID3 = TOKEN_ID1 + 2;
    uint256 private constant TOKEN_ID4 = TOKEN_ID1 + 3;
    uint256 private constant TOKEN_ID5 = TOKEN_ID1 + 4;
    uint256 private constant _NTOKEN = TOKEN_ID5 - TOKEN_ID1 + 1;

    uint256 private constant TOKEN_ID6 = TOKEN_ID1 + 5;
    uint256 private constant INVALID_TOKEN = TOKEN_ID1 - 1;

    GovernanceBuilder private _builder;
    CollectiveGovernance private governance;
    Storage private _storage;
    IERC721 private _erc721;
    address payable private _governanceAddress;
    address private _storageAddress;

    uint32 private version;
    uint256 private proposalId;
    uint256[] private _tokenIdList;

    function setUp() public {
        vm.clearMockedCalls();
        StorageFactory _storageFactory = new StorageFactory();
        MetaStorageFactory _metaStorageFactory = new MetaStorageFactory();
        GovernanceFactory _governanceFactory = new GovernanceFactory();
        _builder = createGovernanceBuilder(_governanceFactory, _storageFactory, _metaStorageFactory);
        _erc721 = mintTokens();
        address projectAddress = address(_erc721);
        (_governanceAddress, _storageAddress, ) = buildERC721(projectAddress);
        governance = CollectiveGovernance(_governanceAddress);
        _storage = Storage(_storageAddress);
        version = governance.version();
        vm.prank(_OWNER, _OWNER);
        proposalId = governance.propose();
        assertEq(proposalId, PROPOSAL_ID);
    }

    function testStorageAddressIsValid() public {
        assertTrue(_storageAddress != address(0x0));
    }

    function testName() public {
        assertEq(governance.name(), "collective governance");
    }

    function testVersion() public {
        assertEq(governance.version(), Constant.CURRENT_VERSION);
    }

    function testPropose() public {
        assertEq(proposalId, proposalId);
    }

    function testOwnerPropose() public {
        vm.prank(_OWNER, _OWNER);
        governance.cancel(proposalId);
        vm.warp(block.timestamp + Constant.MINIMUM_VOTE_DURATION);
        vm.prank(_OWNER, _OWNER);
        uint256 pid2 = governance.propose();
        assertEq(pid2, proposalId + 1);
        _storage.isSupervisor(pid2, _SUPERVISOR);
    }

    function testProposeNotVoter() public {
        vm.expectRevert(abi.encodeWithSelector(Governance.NotPermitted.selector, _NOT_VOTER));
        vm.prank(_NOT_VOTER, _NOT_VOTER);
        governance.propose();
    }

    function testConfigureWrongProposalId() public {
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidProposal.selector, proposalId + 1));
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId + 1, 2);
    }

    function testConfigureDurationWrongProposalId() public {
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidProposal.selector, proposalId + 1));
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId + 1, 2, Constant.MINIMUM_VOTE_DELAY, Constant.MINIMUM_VOTE_DURATION);
    }

    function testConfigureInvalidDuration() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Storage.DurationNotPermitted.selector,
                proposalId,
                Constant.MINIMUM_VOTE_DURATION - 1,
                Constant.MINIMUM_VOTE_DURATION
            )
        );
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2, Constant.MINIMUM_VOTE_DELAY, Constant.MINIMUM_VOTE_DURATION - 1);
    }

    function testConfigureInvalidQuorum() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        vm.expectRevert(
            abi.encodeWithSelector(
                Storage.QuorumNotPermitted.selector,
                proposalId,
                Constant.MINIMUM_PROJECT_QUORUM - 1,
                Constant.MINIMUM_PROJECT_QUORUM
            )
        );
        governance.configure(
            proposalId,
            Constant.MINIMUM_PROJECT_QUORUM - 1,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION
        );
    }

    function testConfigureProjectMinimumWithInvalidQuorum() public {
        address projectAddress = address(_erc721);
        (_governanceAddress, _storageAddress, ) = buildERC721(
            projectAddress,
            10000,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION
        );
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        proposalId = governance.propose();
        assertEq(proposalId, proposalId);
        vm.expectRevert(abi.encodeWithSelector(Storage.QuorumNotPermitted.selector, proposalId, 9999, 10000));
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 9999, Constant.MINIMUM_VOTE_DELAY, Constant.MINIMUM_VOTE_DURATION);
    }

    function testConfigureMinimumWithInvalidDuration() public {
        address projectAddress = address(_erc721);
        (_governanceAddress, _storageAddress, ) = buildERC721(
            projectAddress,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            6 days
        );
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        proposalId = governance.propose();
        assertEq(proposalId, proposalId);
        vm.expectRevert(abi.encodeWithSelector(Storage.DurationNotPermitted.selector, proposalId, 5 days, 6 days));
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, Constant.MINIMUM_PROJECT_QUORUM, Constant.MINIMUM_VOTE_DELAY, 5 days);
    }

    function testConfigureProjectMinimumDuration() public {
        address projectAddress = address(_erc721);
        (_governanceAddress, _storageAddress, ) = buildERC721(
            projectAddress,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            6 days
        );
        governance = CollectiveGovernance(_governanceAddress);
        _storage = Storage(_storageAddress);
        vm.prank(_OWNER, _OWNER);
        proposalId = governance.propose();
        assertEq(proposalId, proposalId);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, Constant.MINIMUM_PROJECT_QUORUM, Constant.MINIMUM_VOTE_DELAY, 8 days);
        assertEq(_storage.voteDuration(proposalId), 8 days);
    }

    function testConfigureProjectMinimumDelay() public {
        address projectAddress = address(_erc721);
        (_governanceAddress, _storageAddress, ) = buildERC721(
            projectAddress,
            Constant.MINIMUM_PROJECT_QUORUM,
            1 days,
            Constant.MINIMUM_VOTE_DURATION
        );
        governance = CollectiveGovernance(_governanceAddress);
        _storage = Storage(_storageAddress);
        vm.prank(_OWNER, _OWNER);
        proposalId = governance.propose();
        assertEq(proposalId, proposalId);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, Constant.MINIMUM_PROJECT_QUORUM, 10 days, Constant.MINIMUM_VOTE_DURATION);
        assertEq(_storage.voteDelay(proposalId), 10 days);
    }

    function testConfigureProjectMinimumDelayNotAllowed() public {
        address projectAddress = address(_erc721);
        (_governanceAddress, _storageAddress, ) = buildERC721(
            projectAddress,
            Constant.MINIMUM_PROJECT_QUORUM,
            10 days,
            Constant.MINIMUM_VOTE_DURATION
        );
        governance = CollectiveGovernance(_governanceAddress);
        _storage = Storage(_storageAddress);
        vm.prank(_OWNER, _OWNER);
        proposalId = governance.propose();
        assertEq(proposalId, proposalId);
        vm.expectRevert(abi.encodeWithSelector(Storage.DelayNotPermitted.selector, proposalId, 10 days - 1, 10 days));
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, Constant.MINIMUM_PROJECT_QUORUM, 10 days - 1, Constant.MINIMUM_VOTE_DURATION);
    }

    function testConfigure721() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        assertTrue(governance.isOpen(proposalId));
        assertEq(_storage.quorumRequired(proposalId), 2);
        assertTrue(governance.isOpen(proposalId));
    }

    function testIsOpenBadProposal() public {
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidProposal.selector, proposalId + 1));
        governance.isOpen(proposalId + 1);
    }

    function testOpenVoteWrongProposal() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidProposal.selector, proposalId + 1));
        governance.startVote(proposalId + 1);
        vm.stopPrank();
    }

    function testCastSimpleVote721() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        assertEq(_storage.forVotes(proposalId), 1);
    }

    function testCastSimpleVote721BadShare() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        vm.expectRevert(abi.encodeWithSelector(Storage.TokenIdIsNotValid.selector, proposalId, NONE));
        governance.voteFor(proposalId, NONE);
    }

    function testCastSimpleVote721NoShare() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.expectRevert("No such token");
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, INVALID_TOKEN);
    }

    function testCastSimpleVoteOpen() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        assertEq(_storage.forVotes(proposalId), 1);
    }

    function testCastMultipleVote() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, _NTOKEN);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, _tokenIdList);
        assertEq(_storage.forVotes(proposalId), _NTOKEN);
    }

    function testCastMultipleVoteAgainst() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, _NTOKEN);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteAgainst(proposalId, _tokenIdList);
        assertEq(_storage.againstVotes(proposalId), _NTOKEN);
    }

    function testCastMultipleVoteAbstain() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, _NTOKEN);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.abstainFrom(proposalId, _tokenIdList);
        assertEq(_storage.abstentionCount(proposalId), _NTOKEN);
    }

    function testCastSimpleVoteWhileActive() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.warp(block.timestamp + 3);
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        assertEq(_storage.forVotes(proposalId), 1);
    }

    function testVoteWrongProposal() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidProposal.selector, proposalId + 1));
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId + 1, TOKEN_ID1);
    }

    function testVoteAgainstWrongProposal() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidProposal.selector, proposalId + 1));
        vm.prank(_VOTER1, _VOTER1);
        governance.voteAgainst(proposalId + 1, TOKEN_ID1);
    }

    function testAbstainWrongProposal() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidProposal.selector, proposalId + 1));
        vm.prank(_VOTER1, _VOTER1);
        governance.abstainFrom(proposalId + 1, TOKEN_ID1);
    }

    function testNonVoter() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(VoterClass.NotVoter.selector, _NOT_VOTER));
        vm.prank(_NOT_VOTER, _NOT_VOTER);
        governance.voteFor(proposalId, TOKEN_ID1);
    }

    function testVoteAgainst() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteAgainst(proposalId, TOKEN_ID1);
        assertEq(_storage.againstVotes(proposalId), 1);
    }

    function testVoteAgainstNonVoter() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(VoterClass.NotVoter.selector, _NOT_VOTER));
        vm.prank(_NOT_VOTER, _NOT_VOTER);
        governance.voteAgainst(proposalId, TOKEN_ID1);
    }

    function testAbstain() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.abstainFrom(proposalId, TOKEN_ID1);
        assertEq(_storage.abstentionCount(proposalId), 1);
    }

    function testAbstentionNonVoter() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(VoterClass.NotVoter.selector, _NOT_VOTER));
        vm.prank(_NOT_VOTER, _NOT_VOTER);
        governance.abstainFrom(proposalId, TOKEN_ID1);
    }

    function testOpenVote() public {
        vm.startPrank(_governanceAddress);
        _storage.setQuorumRequired(proposalId, 75, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        governance.isOpen(proposalId);
    }

    function testOpenVoteRequiresReady() public {
        vm.prank(_governanceAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Governance.VoteNotFinal.selector, proposalId));
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
    }

    function testOwnerOpenVote() public {
        vm.startPrank(_governanceAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_OWNER);
        governance.startVote(proposalId);
    }

    function testOwnerEndVote() public {
        uint256 blockTimestamp = block.timestamp;
        vm.startPrank(_governanceAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.setVoteDuration(proposalId, Constant.MINIMUM_VOTE_DURATION, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        assertTrue(governance.isOpen(proposalId));
        vm.warp(blockTimestamp + Constant.MINIMUM_VOTE_DURATION);
        vm.prank(_OWNER);
        governance.endVote(proposalId);
        assertFalse(governance.isOpen(proposalId));
    }

    function testEarlyEndVote() public {
        vm.startPrank(_governanceAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        assertTrue(governance.isOpen(proposalId));
        vm.expectRevert(abi.encodeWithSelector(Governance.VoteInProgress.selector, proposalId));
        vm.prank(_OWNER);
        governance.endVote(proposalId);
    }

    function testDoubleOpenVote() public {
        vm.startPrank(_governanceAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.expectRevert(abi.encodeWithSelector(Governance.VoteIsOpen.selector, proposalId));
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
    }

    function testEndVoteWhenNotOpen() public {
        vm.startPrank(_governanceAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(Governance.VoteIsClosed.selector, proposalId));
        vm.prank(_SUPERVISOR);
        governance.endVote(proposalId);
    }

    function testOwnerCastVote() public {
        CommunityBuilder _communityBuilder = createCommunityBuilder();
        address _communityLocation = _communityBuilder
            .aCommunity()
            .asPoolCommunity()
            .withVoter(_VOTER1)
            .withVoter(_SUPERVISOR)
            .withCommunitySupervisor(_SUPERVISOR)
            .withQuorum(1)
            .build();
        CommunityClass _class = CommunityClass(_communityLocation);
        (_governanceAddress, _storageAddress, ) = _builder.aGovernance().withCommunityClass(_class).build();
        governance = CollectiveGovernance(_governanceAddress);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.propose();
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_OWNER, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(VoterClass.NotVoter.selector, proposalId));
        governance.voteFor(proposalId);
    }

    function testSupervisorCastVote() public {
        address[] memory voter = new address[](1);
        voter[0] = _VOTER1;
        (_governanceAddress, _storageAddress, ) = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        governance.propose();
        _storage = Storage(_storageAddress);
        vm.startPrank(_governanceAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.expectRevert(abi.encodeWithSelector(VoterClass.NotVoter.selector, _SUPERVISOR));
        vm.prank(_SUPERVISOR, _SUPERVISOR);
        governance.voteFor(proposalId);
    }

    function testCastOneVoteNotOpen() public {
        (_governanceAddress, _storageAddress, ) = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(_storageAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(Governance.VoteIsClosed.selector, proposalId));
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
    }

    function testCastOneVoteFromAll() public {
        (_governanceAddress, _storageAddress, ) = buildOpenVote();
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(_storageAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
        assertEq(_storage.quorum(proposalId), 1);
    }

    function testCastVoteNotOpened() public {
        (_governanceAddress, _storageAddress, ) = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        governance.propose();
        _storage = Storage(_storageAddress);
        vm.expectRevert(abi.encodeWithSelector(Governance.VoteNotFinal.selector, proposalId));
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
    }

    function testCastTwoVote() public {
        (_governanceAddress, _storageAddress, ) = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(_storageAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
        vm.expectRevert(abi.encodeWithSelector(Storage.TokenVoted.selector, proposalId, _VOTER1, uint160(_VOTER1)));
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
    }

    function testCastDoubleVoteOnTransferToken() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        vm.prank(_VOTER1, _VOTER1);
        _erc721.transferFrom(_VOTER1, _VOTER2, TOKEN_ID1);
        vm.expectRevert(abi.encodeWithSelector(Storage.TokenVoted.selector, proposalId, _VOTER2, TOKEN_ID1));
        vm.prank(_VOTER2, _VOTER2);
        governance.voteFor(proposalId, TOKEN_ID1);
    }

    function testVotePassed() public {
        vm.warp(10);
        bytes memory code = address(_storage).code;

        address storageMock = _storageAddress;
        vm.etch(storageMock, code);

        uint256 forVotes = 200;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.forVotes.selector), abi.encode(forVotes));
        uint256 agVotes = 199;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.againstVotes.selector), abi.encode(agVotes));
        uint256 quorum = forVotes + agVotes;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.quorum.selector), abi.encode(quorum));
        uint256 quorumRequired = 399;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.quorumRequired.selector), abi.encode(quorumRequired));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.startTime.selector), abi.encode(block.timestamp));
        vm.mockCall(
            storageMock,
            abi.encodeWithSelector(Storage.endTime.selector),
            abi.encode(block.timestamp + Constant.MINIMUM_VOTE_DURATION + 1)
        );
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isFinal.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isVeto.selector), abi.encode(false));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isSupervisor.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.transactionCount.selector), abi.encode(0));

        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 3);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.warp(block.timestamp + Constant.MINIMUM_VOTE_DURATION + 1);
        vm.prank(_OWNER, _OWNER);
        governance.endVote(proposalId);
        assertTrue(governance.getVoteSucceeded(proposalId));
    }

    function testVoteDidNotPass() public {
        vm.warp(10);
        bytes memory code = address(_storage).code;

        address storageMock = _storageAddress;
        vm.etch(storageMock, code);

        uint256 forVotes = 199;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.forVotes.selector), abi.encode(forVotes));
        uint256 agVotes = 200;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.againstVotes.selector), abi.encode(agVotes));
        uint256 quorum = forVotes + agVotes;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.quorum.selector), abi.encode(quorum));
        uint256 quorumRequired = 399;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.quorumRequired.selector), abi.encode(quorumRequired));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.startTime.selector), abi.encode(block.timestamp - 2));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.endTime.selector), abi.encode(block.timestamp - 1));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isFinal.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isVeto.selector), abi.encode(false));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isSupervisor.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.transactionCount.selector), abi.encode(0));

        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.prank(_SUPERVISOR);
        governance.endVote(proposalId);

        assertFalse(governance.getVoteSucceeded(proposalId));
    }

    function testTieVoteDidNotPass() public {
        vm.warp(10);
        bytes memory code = address(_storage).code;

        address storageMock = _storageAddress;
        vm.etch(storageMock, code);

        uint256 forVotes = 200;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.forVotes.selector), abi.encode(forVotes));
        uint256 agVotes = 200;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.againstVotes.selector), abi.encode(agVotes));
        uint256 quorum = forVotes + agVotes;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.quorum.selector), abi.encode(quorum));
        uint256 quorumRequired = 399;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.quorumRequired.selector), abi.encode(quorumRequired));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.startTime.selector), abi.encode(block.timestamp - 2));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.endTime.selector), abi.encode(block.timestamp - 1));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isFinal.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isVeto.selector), abi.encode(false));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isSupervisor.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.transactionCount.selector), abi.encode(0));

        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.prank(_SUPERVISOR);
        governance.endVote(proposalId);

        assertFalse(governance.getVoteSucceeded(proposalId));
    }

    function testMeasureNoQuorum() public {
        vm.warp(10);
        bytes memory code = address(_storage).code;

        address storageMock = _storageAddress;
        vm.etch(storageMock, code);
        uint256 forVotes = 199;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.forVotes.selector), abi.encode(forVotes));
        uint256 agVotes = 2;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.againstVotes.selector), abi.encode(agVotes));
        uint256 quorum = forVotes + agVotes;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.quorum.selector), abi.encode(quorum));
        uint256 quorumRequired = 203;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.quorumRequired.selector), abi.encode(quorumRequired));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.startTime.selector), abi.encode(block.timestamp - 2));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.endTime.selector), abi.encode(block.timestamp - 1));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isFinal.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isVeto.selector), abi.encode(false));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isSupervisor.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.transactionCount.selector), abi.encode(0));

        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.prank(_SUPERVISOR);
        governance.endVote(proposalId);

        assertFalse(governance.getVoteSucceeded(proposalId));
    }

    function testGetVoteSucceededOnOpenMeasure() public {
        (_governanceAddress, _storageAddress, ) = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(_storageAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.expectRevert(abi.encodeWithSelector(Governance.VoteIsOpen.selector, proposalId));
        governance.getVoteSucceeded(proposalId);
    }

    function testMeasureIsVeto() public {
        CommunityBuilder _communityBuilder = createCommunityBuilder();
        address _communityLocation = _communityBuilder
            .aCommunity()
            .asPoolCommunity()
            .withVoter(_VOTER1)
            .withVoter(_VOTER2)
            .withVoter(_OWNER)
            .withCommunitySupervisor(_SUPERVISOR)
            .withQuorum(1)
            .build();
        CommunityClass _class = CommunityClass(_communityLocation);
        _builder.aGovernance().withCommunityClass(_class);
        (_governanceAddress, _storageAddress, ) = _builder.build();
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(_storageAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        uint256 blockTimestamp = block.timestamp;
        governance.startVote(proposalId);
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
        vm.prank(_VOTER2, _VOTER2);
        governance.voteFor(proposalId);
        vm.prank(_SUPERVISOR);
        governance.veto(proposalId);
        assertTrue(_storage.isVeto(proposalId));
        vm.warp(blockTimestamp + 2);
        vm.prank(_OWNER, _OWNER);
        governance.endVote(proposalId);
        vm.expectRevert(abi.encodeWithSelector(Governance.VoteVetoed.selector, proposalId));
        governance.getVoteSucceeded(proposalId);
    }

    function testMeasureLateVeto() public {
        uint256 blockTimestamp = block.timestamp;
        CommunityBuilder _communityBuilder = createCommunityBuilder();
        address _communityLocation = _communityBuilder
            .aCommunity()
            .asPoolCommunity()
            .withVoter(_VOTER1)
            .withVoter(_VOTER2)
            .withVoter(_OWNER)
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        CommunityClass _class = CommunityClass(_communityLocation);
        _builder.aGovernance().withCommunityClass(_class);
        (_governanceAddress, _storageAddress, ) = _builder.build();
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(_storageAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.setVoteDuration(proposalId, Constant.MINIMUM_VOTE_DURATION, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
        vm.prank(_VOTER2, _VOTER2);
        governance.voteFor(proposalId);
        vm.warp(blockTimestamp + Constant.MINIMUM_VOTE_DURATION);
        vm.prank(_OWNER, _OWNER);
        governance.endVote(proposalId);
        vm.expectRevert(abi.encodeWithSelector(Governance.VoteIsClosed.selector, proposalId));
        vm.prank(_SUPERVISOR);
        governance.veto(proposalId);
    }

    function testCastAgainstVoteNotOpen() public {
        (_governanceAddress, _storageAddress, ) = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(_storageAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(Governance.VoteIsClosed.selector, proposalId));
        vm.prank(_VOTER1, _VOTER1);
        governance.voteAgainst(proposalId);
    }

    function testAbstainFromVoteNotOpen() public {
        (_governanceAddress, _storageAddress, ) = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(_storageAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(Governance.VoteIsClosed.selector, proposalId));
        vm.prank(_VOTER1, _VOTER1);
        governance.abstainFrom(proposalId);
    }

    function testVoteDelayPreventsVote(uint256 blockStep) public {
        vm.assume(blockStep >= 1 && blockStep < 1 days);
        (_governanceAddress, _storageAddress, ) = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(_storageAddress);
        _storage.setQuorumRequired(proposalId, 1, _SUPERVISOR);
        _storage.setVoteDelay(proposalId, 1 days, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        uint256 startTime = block.timestamp;
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.warp(startTime + blockStep);
        vm.expectRevert(
            abi.encodeWithSelector(
                Storage.VoteNotActive.selector,
                proposalId,
                _storage.startTime(proposalId),
                _storage.endTime(proposalId)
            )
        );
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
    }

    function testVoteAfterDuration(uint256 blockStep) public {
        uint256 currentTime = block.timestamp;
        vm.assume(blockStep > Constant.MINIMUM_VOTE_DURATION && blockStep < Constant.UINT_MAX - currentTime);
        (_governanceAddress, _storageAddress, ) = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(_storageAddress);
        _storage.setQuorumRequired(proposalId, 1, _SUPERVISOR);
        _storage.setVoteDuration(proposalId, Constant.MINIMUM_VOTE_DURATION, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.warp(currentTime + blockStep);
        vm.expectRevert(
            abi.encodeWithSelector(
                Storage.VoteNotActive.selector,
                proposalId,
                _storage.startTime(proposalId),
                _storage.endTime(proposalId)
            )
        );
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
    }

    function testEndVoteWhileActive(uint256 blockStep) public {
        uint256 voteDelay = Constant.MINIMUM_VOTE_DURATION;
        // note one voteDelay one vote duration
        vm.assume(blockStep < Constant.MINIMUM_VOTE_DURATION);
        (_governanceAddress, _storageAddress, ) = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(_storageAddress);
        _storage.setQuorumRequired(proposalId, 1, _SUPERVISOR);
        _storage.setVoteDelay(proposalId, voteDelay, _SUPERVISOR);
        _storage.setVoteDuration(proposalId, Constant.MINIMUM_VOTE_DURATION, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        uint256 startTime = block.timestamp;
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.warp(startTime + voteDelay + blockStep);
        vm.expectRevert(abi.encodeWithSelector(Governance.VoteInProgress.selector, proposalId));
        vm.prank(_SUPERVISOR);
        governance.endVote(proposalId);
    }

    function testEndVoteWhenFinished(uint256 blockStep) public {
        uint256 voteDelay = Constant.MINIMUM_VOTE_DURATION;
        vm.assume(
            blockStep >= voteDelay + Constant.MINIMUM_VOTE_DURATION &&
                blockStep < Constant.UINT_MAX - voteDelay - block.timestamp - Constant.MINIMUM_VOTE_DURATION
        );
        (_governanceAddress, _storageAddress, ) = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        vm.prank(_OWNER, _OWNER);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(_storageAddress);
        _storage.setQuorumRequired(proposalId, 1, _SUPERVISOR);
        _storage.setVoteDelay(proposalId, voteDelay, _SUPERVISOR);
        _storage.setVoteDuration(proposalId, Constant.MINIMUM_VOTE_DURATION, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        uint256 startTime = block.timestamp;
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.warp(startTime + blockStep);
        vm.prank(_SUPERVISOR);
        governance.endVote(proposalId);
        assertFalse(governance.isOpen(proposalId));
    }

    function testDirectStorageAccessToSupervisor() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_OWNER);
        _storage.registerSupervisor(proposalId, _VOTER1, _OWNER);
    }

    function testDirectStorageAccessToQuorum() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.setQuorumRequired(proposalId, 0xffffffff, _SUPERVISOR);
    }

    function testDirectStorageAccessToDuration() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.setVoteDuration(proposalId, 0xffffffff, _SUPERVISOR);
    }

    function testDirectStorageAccessToDelay() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.setVoteDelay(proposalId, 0xffffffff, _SUPERVISOR);
    }

    function testDirectStorageAccessToReady() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
    }

    function testDirectStorageAccessToCastVote() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_VOTER1, _VOTER1);
        _storage.voteForByShare(proposalId, _VOTER1, TOKEN_ID1);
    }

    function testDirectStorageAccessToCastVoteAgainst() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_VOTER1, _VOTER1);
        _storage.voteAgainstByShare(proposalId, _VOTER1, TOKEN_ID1);
    }

    function testDirectStorageAccessToAbstain() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_VOTER1, _VOTER1);
        _storage.abstainForShare(proposalId, _VOTER1, TOKEN_ID1);
    }

    function testDirectStorageAccessToVeto() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.veto(proposalId, msg.sender);
    }

    function testSupportsInterfaceCollectiveGovernance() public {
        bytes4 govId = type(Governance).interfaceId;
        assertTrue(governance.supportsInterface(govId));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(governance.supportsInterface(ifId));
    }

    function testSupportsInterfaceVoteStrategy() public {
        bytes4 vsId = type(VoteStrategy).interfaceId;
        assertTrue(governance.supportsInterface(vsId));
    }

    function testSupportsInterfaceERC165() public {
        bytes4 esId = type(IERC165).interfaceId;
        assertTrue(governance.supportsInterface(esId));
    }

    function testCancelConfigured() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.cancel(proposalId);
        vm.stopPrank();
        assertFalse(governance.isOpen(proposalId));
        assertTrue(_storage.isCancel(proposalId));
    }

    function testCancelQuorum() public {
        bytes memory code = address(_storage).code;

        address storageMock = _storageAddress;
        vm.etch(storageMock, code);
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.quorum.selector, proposalId), abi.encode(1));
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);

        vm.expectRevert(abi.encodeWithSelector(Governance.CancelNotPossible.selector, proposalId, _SUPERVISOR));
        governance.cancel(proposalId);
        vm.stopPrank();
    }

    function testCancelPropose() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.cancel(proposalId);
        vm.stopPrank();
        vm.warp(block.timestamp + Constant.MINIMUM_VOTE_DURATION);
        vm.prank(_OWNER, _OWNER);
        uint256 nextProposalId = governance.propose();
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(nextProposalId, 2);
        governance.startVote(nextProposalId);
        vm.stopPrank();
        assertFalse(governance.isOpen(proposalId));
        assertTrue(_storage.isCancel(proposalId));
        assertTrue(governance.isOpen(nextProposalId));
        assertFalse(_storage.isCancel(nextProposalId));
    }

    function testCancelNotConfigured() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.cancel(proposalId);
        vm.stopPrank();
        assertFalse(governance.isOpen(proposalId));
        assertTrue(_storage.isCancel(proposalId));
    }

    function testConfigureAfterCancel() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.cancel(proposalId);
        vm.expectRevert(abi.encodeWithSelector(Storage.VoteIsFinal.selector, proposalId));
        governance.configure(proposalId, 2);
        vm.stopPrank();
    }

    function testOpenAfterCancel() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.cancel(proposalId);
        vm.expectRevert(abi.encodeWithSelector(Governance.VoteCancelled.selector, proposalId));
        governance.startVote(proposalId);
        vm.stopPrank();
    }

    function testCancelAfterOpen() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        uint256 blockTimestamp = block.timestamp;
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.warp(blockTimestamp + 2);
        vm.expectRevert(abi.encodeWithSelector(Governance.CancelNotPossible.selector, proposalId, _SUPERVISOR));
        governance.cancel(proposalId);
        vm.stopPrank();
    }

    function testCancelAfterStartTime() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        uint256 startTime = _storage.startTime(proposalId);
        vm.warp(startTime + 1);
        vm.expectRevert(abi.encodeWithSelector(Governance.CancelNotPossible.selector, proposalId, _SUPERVISOR));
        governance.cancel(proposalId);
        vm.stopPrank();
    }

    function testCancelAfterEndIfStarted() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        uint256 blockTimestamp = block.timestamp;
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.warp(blockTimestamp + Constant.MINIMUM_VOTE_DURATION);
        governance.endVote(proposalId);
        vm.expectRevert(abi.encodeWithSelector(Governance.CancelNotPossible.selector, proposalId, _SUPERVISOR));
        governance.cancel(proposalId);
        vm.stopPrank();
    }

    function testCancelAfterEndNotStarted() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        uint256 blockTimestamp = block.timestamp;
        governance.configure(proposalId, 2);
        vm.warp(blockTimestamp + Constant.MINIMUM_VOTE_DURATION);
        vm.expectRevert(abi.encodeWithSelector(Governance.CancelNotPossible.selector, proposalId, _SUPERVISOR));
        governance.cancel(proposalId);
        vm.stopPrank();
    }

    function testCancelAfterEndNotStartedOrFinal() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        uint256 blockTimestamp = block.timestamp;
        vm.warp(blockTimestamp + Constant.MINIMUM_VOTE_DURATION);
        governance.cancel(proposalId);
        vm.stopPrank();
        assertTrue(_storage.isCancel(proposalId));
    }

    function testEndNowIfVeto() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        governance.veto(proposalId);
        governance.endVote(proposalId);
        vm.stopPrank();
    }

    function testVetoWrongProposal() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidProposal.selector, proposalId + 1));
        governance.veto(proposalId + 1);
        vm.stopPrank();
    }

    function testAttachTransaction(uint256 systemClock) public {
        uint256 currentTime = block.timestamp;
        vm.assume(
            systemClock > Constant.TIMELOCK_MINIMUM_DELAY &&
                systemClock < Constant.TIMELOCK_MINIMUM_DELAY + Constant.TIMELOCK_GRACE_PERIOD - 1 minutes
        );
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory _calldata = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = currentTime + systemClock;
        vm.prank(_OWNER);
        governance.attachTransaction(proposalId, flagMock, 0, "", _calldata, scheduleTime);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 1);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        vm.warp(scheduleTime + Constant.TIMELOCK_GRACE_PERIOD / 2);
        assertFalse(flag.isSet());
        vm.prank(_NOT_VOTER, _NOT_VOTER);
        governance.endVote(proposalId);
        assertTrue(flag.isSet());
        assertTrue(_storage.isExecuted(proposalId));
    }

    function testAttachTransactionThenDoubleExecute(uint256 systemClock) public {
        uint256 currentTime = block.timestamp;
        vm.assume(
            systemClock > Constant.TIMELOCK_MINIMUM_DELAY &&
                systemClock < Constant.TIMELOCK_MINIMUM_DELAY + Constant.TIMELOCK_GRACE_PERIOD - 1 minutes
        );
        vm.warp(currentTime + systemClock);
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory clldata = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = currentTime + systemClock;
        vm.prank(_OWNER);
        governance.attachTransaction(proposalId, flagMock, 0, "", clldata, scheduleTime);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 1);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        vm.warp(scheduleTime);
        assertFalse(flag.isSet());
        vm.prank(_OWNER);
        governance.endVote(proposalId);
        vm.expectRevert(abi.encodeWithSelector(Governance.VoteIsClosed.selector, proposalId));
        vm.prank(_OWNER);
        governance.endVote(proposalId);
    }

    function testAttachAndClearMultipleTransaction() public {
        uint256 currentTime = block.timestamp;
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory data = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = currentTime + 40 hours;
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(_OWNER);
            uint256 tid = governance.attachTransaction(proposalId, address(0x10), i, "", "", scheduleTime + i);
            vm.prank(address(governance));
            _storage.clearTransaction(proposalId, tid, _OWNER);
        }
        vm.prank(_OWNER);
        governance.attachTransaction(proposalId, flagMock, 0, "", data, scheduleTime);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 1);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        vm.warp(scheduleTime + 7 days);
        assertFalse(flag.isSet());
        vm.prank(_NOT_VOTER, _NOT_VOTER);
        governance.endVote(proposalId);
        assertTrue(flag.isSet());
        assertTrue(_storage.isExecuted(proposalId));
    }

    function testAttachTransactionButVeto() public {
        uint256 currentTime = block.timestamp;
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory data = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = currentTime + 2 days;
        vm.prank(_OWNER);
        governance.attachTransaction(proposalId, flagMock, 0, "", data, scheduleTime);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 1);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        vm.warp(currentTime + 1 days);
        vm.prank(_OWNER);
        governance.veto(proposalId);
        vm.warp(scheduleTime);
        vm.prank(_OWNER);
        governance.endVote(proposalId);
        assertFalse(flag.isSet());
        assertFalse(_storage.isExecuted(proposalId));
        assertTrue(_storage.isVeto(proposalId));
    }

    function testAttachTransactionFailsVote() public {
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory data = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = block.timestamp + 2 days;
        vm.prank(_OWNER);
        governance.attachTransaction(proposalId, flagMock, 0, "", data, scheduleTime);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 1);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteAgainst(proposalId, TOKEN_ID1);
        vm.warp(scheduleTime);
        vm.prank(_OWNER);
        governance.endVote(proposalId);
        assertFalse(flag.isSet());
        assertFalse(_storage.isExecuted(proposalId));
    }

    function testAttachTransactionQuorumNotAchieved() public {
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory data = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = block.timestamp + 2 days;
        vm.prank(_OWNER);
        governance.attachTransaction(proposalId, flagMock, 0, "", data, scheduleTime);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 10);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        vm.warp(scheduleTime);
        vm.prank(_OWNER);
        governance.endVote(proposalId);
        assertFalse(flag.isSet());
        assertFalse(_storage.isExecuted(proposalId));
    }

    function testAttachTransactionEndsVoteDuringTimelock() public {
        vm.prank(_OWNER);
        uint256 currentTime = block.timestamp;
        uint256 etaOfLock = currentTime + 7 days;
        Transaction memory transaction = Transaction(address(0x7fff), 0, "", "save()", etaOfLock);
        governance.attachTransaction(
            proposalId,
            transaction.target,
            transaction.value,
            transaction.signature,
            transaction._calldata,
            transaction.scheduleTime
        );
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 1);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);

        bytes32 txHash = getHash(transaction);
        vm.expectRevert(abi.encodeWithSelector(TimeLocker.TransactionLocked.selector, txHash, etaOfLock));
        vm.warp(currentTime + Constant.MINIMUM_VOTE_DURATION);
        vm.prank(_OWNER);
        governance.endVote(proposalId);
    }

    function testCastVoteButContractNotFullyCapitalized() public {
        vm.fee(50 gwei);

        vm.deal(_OWNER, 10 gwei);
        vm.prank(_OWNER);
        _governanceAddress.transfer(10 gwei);

        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        governance.withdrawRebate(_VOTER1);
        assertTrue(_VOTER1.balance > 0);
        assertEq(_VOTER1.balance, 10 gwei);
        assertEq(_governanceAddress.balance, 0);
    }

    function testCastVoteWithRefund() public {
        vm.fee(50 gwei);

        vm.deal(_OWNER, 1 ether);
        vm.prank(_OWNER);
        _governanceAddress.transfer(1 ether);

        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        governance.withdrawRebate(_VOTER1);
        assertTrue(_VOTER1.balance > 0);
        assertApproxEqAbs(_VOTER1.balance, 9795188 gwei, 10000 gwei);
    }

    function testCastAgainstWithRefund() public {
        vm.fee(50 gwei);

        vm.deal(_OWNER, 1 ether);
        vm.prank(_OWNER);
        _governanceAddress.transfer(1 ether);

        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteAgainst(proposalId, TOKEN_ID1);
        governance.withdrawRebate(_VOTER1);
        assertTrue(_VOTER1.balance > 0);
        assertApproxEqAbs(_VOTER1.balance, 8756332 gwei, 10000 gwei);
    }

    function testAbstainWithRefund() public {
        vm.fee(50 gwei);

        vm.deal(_OWNER, 10 ether);
        vm.prank(_OWNER);
        _governanceAddress.transfer(1 ether);

        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.abstainFrom(proposalId, TOKEN_ID1);
        governance.withdrawRebate(_VOTER1);
        assertTrue(_VOTER1.balance > 0);
        assertApproxEqAbs(_VOTER1.balance, 9408620 gwei, 10000 gwei);
    }

    function testChoiceVoteSimple() public {
        vm.startPrank(_OWNER, _OWNER);
        governance.cancel(proposalId);
        vm.warp(block.timestamp + Constant.MINIMUM_VOTE_DURATION);
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory data = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = block.timestamp + 2 days;
        proposalId = governance.propose();
        uint256 tid = governance.attachTransaction(proposalId, flagMock, 0, "", data, scheduleTime);
        for (uint256 i = 0; i < 2; i++) {
            governance.addChoice(proposalId, keccak256(abi.encode(i)), "a choice for this vote", 0);
        }
        uint256 choiceId = governance.addChoice(proposalId, "choice", "a choice for this vote", tid);
        governance.configure(proposalId, 1);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1, choiceId);
        vm.warp(scheduleTime);
        vm.prank(_OWNER, _OWNER);
        governance.endVote(proposalId);
        // vote is passed, choice is executed
        assertTrue(flag.isSet());
        assertTrue(_storage.isExecuted(proposalId));
    }

    function testChoiceVoteTransactionNotAttached() public {
        vm.startPrank(_OWNER, _OWNER);
        governance.cancel(proposalId);
        vm.warp(block.timestamp + Constant.MINIMUM_VOTE_DURATION);
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory data = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = block.timestamp + 2 days;
        proposalId = governance.propose();
        governance.attachTransaction(proposalId, flagMock, 0, "", data, scheduleTime);
        for (uint256 i = 0; i < 2; i++) {
            governance.addChoice(proposalId, keccak256(abi.encode(i)), "a choice for this vote", 0);
        }
        uint256 choiceId = governance.addChoice(proposalId, "choice", "a choice for this vote", 0);
        governance.configure(proposalId, 1);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1, choiceId);
        vm.warp(scheduleTime);
        vm.prank(_OWNER, _OWNER);
        governance.endVote(proposalId);
        assertFalse(flag.isSet());
        assertTrue(_storage.isExecuted(proposalId));
    }

    function testChoiceVoteFlipTheTransaction() public {
        vm.startPrank(_OWNER, _OWNER);
        governance.cancel(proposalId);
        vm.warp(block.timestamp + Constant.MINIMUM_VOTE_DURATION);
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory data = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = block.timestamp + 2 days;
        proposalId = governance.propose();
        uint256 tid = governance.attachTransaction(proposalId, flagMock, 0, "", data, scheduleTime);
        for (uint256 i = 0; i < 2; i++) {
            governance.addChoice(proposalId, keccak256(abi.encode(i)), "a choice for this vote", 0);
        }
        uint256 choiceId = governance.addChoice(proposalId, "choice", "a choice for this vote", tid);
        vm.stopPrank();
        vm.startPrank(_governanceAddress, _governanceAddress);
        // hack the transaction
        _storage.clearTransaction(proposalId, tid, _OWNER);
        Transaction memory wrongTransaction = Transaction(flagMock, 0, "", data, scheduleTime + 1);
        _storage.addTransaction(proposalId, wrongTransaction, _OWNER);
        vm.stopPrank();
        vm.startPrank(_OWNER, _OWNER);
        governance.configure(proposalId, 1);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1, choiceId);
        vm.warp(scheduleTime);
        vm.prank(_OWNER, _OWNER);
        governance.endVote(proposalId);
        // nothing executed - cleared
        assertTrue(_storage.isExecuted(proposalId));
        assertFalse(flag.isSet());
    }

    function testChoiceVoteClearTheTransaction() public {
        vm.startPrank(_OWNER, _OWNER);
        governance.cancel(proposalId);
        vm.warp(block.timestamp + Constant.MINIMUM_VOTE_DURATION);
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory data = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = block.timestamp + 2 days;
        proposalId = governance.propose();
        uint256 tid = governance.attachTransaction(proposalId, flagMock, 0, "", data, scheduleTime);
        uint256 choiceId = governance.addChoice(proposalId, "choice", "a choice for this vote", tid);
        for (uint256 i = 0; i < 2; i++) {
            governance.addChoice(proposalId, keccak256(abi.encode(i)), "a choice for this vote", 0);
        }
        vm.stopPrank();
        vm.prank(_governanceAddress, _governanceAddress);
        // hack the transaction
        _storage.clearTransaction(proposalId, tid, _OWNER);
        vm.startPrank(_OWNER, _OWNER);
        governance.configure(proposalId, 1);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1, choiceId);
        vm.warp(scheduleTime);
        vm.prank(_OWNER, _OWNER);
        governance.endVote(proposalId);
        // nothing executed - cleared
        assertTrue(_storage.isExecuted(proposalId));
        assertFalse(flag.isSet());
    }

    function testChoiceVoteQuorumNotReached() public {
        vm.startPrank(_OWNER, _OWNER);
        governance.cancel(proposalId);
        vm.warp(block.timestamp + Constant.MINIMUM_VOTE_DURATION);
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory data = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = block.timestamp + 2 days;
        proposalId = governance.propose();
        uint256 tid = governance.attachTransaction(proposalId, flagMock, 0, "", data, scheduleTime);
        for (uint256 i = 0; i < 2; i++) {
            governance.addChoice(proposalId, keccak256(abi.encode(i)), "a choice for this vote", 0);
        }
        uint256 choiceId = governance.addChoice(proposalId, "choice", "a choice for this vote", tid);
        governance.configure(proposalId, _NTOKEN);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.startPrank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1, choiceId);
        governance.voteFor(proposalId, TOKEN_ID2, choiceId);
        governance.voteFor(proposalId, TOKEN_ID3, choiceId);
        governance.voteFor(proposalId, TOKEN_ID4, choiceId - 1);
        vm.stopPrank();
        vm.warp(scheduleTime);
        vm.prank(_OWNER, _OWNER);
        governance.endVote(proposalId);
        assertFalse(flag.isSet());
        assertFalse(_storage.isExecuted(proposalId));
    }

    function testChoiceVoteTopRanking() public {
        vm.startPrank(_OWNER, _OWNER);
        governance.cancel(proposalId);
        vm.warp(block.timestamp + Constant.MINIMUM_VOTE_DURATION);
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory data = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = block.timestamp + 2 days;
        proposalId = governance.propose();
        uint256 tid = governance.attachTransaction(proposalId, flagMock, 0, "", data, scheduleTime);
        uint256 c1 = governance.addChoice(proposalId, "choice1", "a choice for this vote", 0);
        uint256 c2 = governance.addChoice(proposalId, "choice2", "a choice for this vote", tid);
        governance.addChoice(proposalId, "choice3", "a choice for this vote", 0);
        governance.configure(proposalId, _NTOKEN);
        governance.startVote(proposalId);
        vm.stopPrank();
        // cid 1 must execute
        vm.startPrank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1, c2);
        governance.voteFor(proposalId, TOKEN_ID2, c1);
        governance.voteFor(proposalId, TOKEN_ID3, c2);
        governance.voteFor(proposalId, TOKEN_ID4, c2);
        governance.voteFor(proposalId, TOKEN_ID5, c1);
        vm.stopPrank();
        vm.warp(scheduleTime);
        vm.prank(_OWNER, _OWNER);
        governance.endVote(proposalId);
        // vote is passed, choice is executed
        assertTrue(flag.isSet());
        assertTrue(_storage.isExecuted(proposalId));
    }
    
    function testErc20Vote() public {
        ERC20PresetMinterPauser _token = new ERC20PresetMinterPauser("Test20", "ERT20");
        (_governanceAddress, _storageAddress, ) = buildERC20(address(_token));
        governance = CollectiveGovernance(_governanceAddress);
        _storage = Storage(_storageAddress);
        version = governance.version();
        _token.mint(_OWNER, 100);
        vm.prank(_OWNER, _OWNER);
        proposalId = governance.propose();
        assertEq(proposalId, PROPOSAL_ID);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 100);
        governance.startVote(proposalId);
        vm.stopPrank();
        _token.mint(_VOTER1, 100);
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
        assertEq(_storage.forVotes(proposalId), 100);
    }

    function testErc20TokenDistributionDoesNotEnableRevote() public {
        ERC20PresetMinterPauser _token = new ERC20PresetMinterPauser("Test20", "ERT20");
        (_governanceAddress, _storageAddress, ) = buildERC20(address(_token));
        governance = CollectiveGovernance(_governanceAddress);
        _storage = Storage(_storageAddress);
        version = governance.version();
        _token.mint(_OWNER, 100);
        vm.prank(_OWNER, _OWNER);
        proposalId = governance.propose();
        assertEq(proposalId, PROPOSAL_ID);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 100);
        governance.startVote(proposalId);
        vm.stopPrank();
        _token.mint(_VOTER1, 100);
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
        _token.mint(_VOTER1, 100);
        vm.expectRevert(abi.encodeWithSelector(Storage.TokenVoted.selector, proposalId, _VOTER1, uint160(_VOTER1)));        
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
    }

    function testWithdrawRequiresRebateAvailable() public {
        vm.expectRevert(abi.encodeWithSelector(Governance.NoRebate.selector, _VOTER1));
        governance.withdrawRebate(_VOTER1);
    }
    
    function mintTokens() private returns (IERC721) {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_VOTER1, TOKEN_ID1);
        merc721.mintTo(_VOTER1, TOKEN_ID2);
        merc721.mintTo(_VOTER1, TOKEN_ID3);
        merc721.mintTo(_VOTER1, TOKEN_ID4);
        merc721.mintTo(_VOTER1, TOKEN_ID5);
        merc721.mintTo(_OWNER, TOKEN_ID6);
        _tokenIdList.push(TOKEN_ID1);
        _tokenIdList.push(TOKEN_ID2);
        _tokenIdList.push(TOKEN_ID3);
        _tokenIdList.push(TOKEN_ID4);
        _tokenIdList.push(TOKEN_ID5);
        return merc721;
    }

    function buildERC721(address projectAddress) private returns (address payable, address, address) {
        CommunityBuilder _communityBuilder = createCommunityBuilder();
        address _communityLocation = _communityBuilder
            .aCommunity()
            .asClosedErc721Community(projectAddress, 1)
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        CommunityClass _class = CommunityClass(_communityLocation);
        return _builder.aGovernance().withCommunityClass(_class).build();
    }

    function buildERC20(address projectAddress) private returns (address payable, address, address) {
        CommunityBuilder _communityBuilder = createCommunityBuilder();
        address _communityLocation = _communityBuilder
            .aCommunity()
            .asClosedErc20Community(projectAddress, 100)
            .withQuorum(99)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        CommunityClass _class = CommunityClass(_communityLocation);
        return _builder.aGovernance().withCommunityClass(_class).build();
    }


    function buildERC721(
        address projectAddress,
        uint256 minimumProjectQuorum,
        uint256 minimumVoteDelay,
        uint256 minimumDuration
    ) private returns (address payable, address, address) {
        CommunityBuilder _communityBuilder = createCommunityBuilder();
        address _communityLocation = _communityBuilder
            .aCommunity()
            .asClosedErc721Community(projectAddress, 1)
            .withQuorum(minimumProjectQuorum)
            .withMinimumVoteDelay(minimumVoteDelay)
            .withMinimumVoteDuration(minimumDuration)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        CommunityClass _class = CommunityClass(_communityLocation);
        return _builder.aGovernance().withCommunityClass(_class).build();
    }

    function buildVoterPool() private returns (address payable, address, address) {
        CommunityBuilder _communityBuilder = createCommunityBuilder();
        address _communityLocation = _communityBuilder
            .aCommunity()
            .asPoolCommunity()
            .withQuorum(1)
            .withVoter(_VOTER1)
            .withVoter(_OWNER)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        CommunityClass _class = CommunityClass(_communityLocation);
        return _builder.aGovernance().withCommunityClass(_class).build();
    }

    function buildOpenVote() private returns (address payable, address, address) {
        CommunityBuilder _communityBuilder = createCommunityBuilder();
        address _communityLocation = _communityBuilder
            .aCommunity()
            .asOpenCommunity()
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        CommunityClass _class = CommunityClass(_communityLocation);
        return _builder.aGovernance().withCommunityClass(_class).build();
    }
}

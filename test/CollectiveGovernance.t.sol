// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable not-rely-on-time
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "forge-std/Test.sol";

import "../contracts/Constant.sol";
import "../contracts/VoterClass.sol";
import "../contracts/VoterClassVoterPool.sol";
import "../contracts/VoterClassERC721.sol";
import "../contracts/Storage.sol";
import "../contracts/GovernanceStorage.sol";
import "../contracts/VoteStrategy.sol";
import "../contracts/Governance.sol";
import "../contracts/CollectiveGovernance.sol";
import "../contracts/GovernanceBuilder.sol";
import "./MockERC721.sol";
import "./FlagSet.sol";
import "./TestData.sol";

contract CollectiveGovernanceTest is Test {
    uint256 private constant UINT256MAX = Constant.UINT_MAX;

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
    uint256 private constant INVALID_TOKEN = TOKEN_ID1 - 1;

    GovernanceBuilder private _builder;
    CollectiveGovernance private governance;
    Storage private _storage;
    IERC721 private _erc721;
    address payable private _governanceAddress;

    uint32 private version;
    uint256 private proposalId;
    uint256[] private _tokenIdList;

    function setUp() public {
        vm.clearMockedCalls();
        _builder = new GovernanceBuilder();
        _erc721 = mintTokens();
        address projectAddress = address(_erc721);
        _governanceAddress = buildERC721(projectAddress);
        governance = CollectiveGovernance(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        version = governance.version();
        vm.prank(_OWNER);
        proposalId = governance.propose();
        assertEq(proposalId, PROPOSAL_ID);
    }

    function testGetStorageAddress() public {
        address storageAddress = governance.getStorageAddress();
        assertTrue(storageAddress != address(0x0));
    }

    function testName() public {
        assertEq(governance.name(), "collective governance");
    }

    function testVersion() public {
        assertEq(governance.version(), 1);
    }

    function testPropose() public {
        assertEq(proposalId, proposalId);
    }

    function testSupervisorPropose() public {
        vm.prank(_SUPERVISOR);
        uint256 pid2 = governance.propose();
        assertEq(pid2, proposalId + 1);
        _storage.isSupervisor(pid2, _SUPERVISOR);
    }

    function testConfigureWrongProposalId() public {
        vm.expectRevert("Invalid proposal");
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId + 1, 2);
    }

    function testConfigureDurationWrongProposalId() public {
        vm.expectRevert("Invalid proposal");
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId + 1, 2, Constant.MINIMUM_VOTE_DELAY, Constant.MINIMUM_VOTE_DURATION);
    }

    function testConfigureInvalidDuration() public {
        vm.expectRevert("Duration not allowed");
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2, Constant.MINIMUM_VOTE_DELAY, Constant.MINIMUM_VOTE_DURATION - 1);
    }

    function testConfigureInvalidQuorum() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        vm.expectRevert("Quorum not allowed");
        governance.configure(
            proposalId,
            Constant.MINIMUM_PROJECT_QUORUM - 1,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION
        );
    }

    function testConfigureProjectMinimumWithInvalidQuorum() public {
        address projectAddress = address(_erc721);
        _governanceAddress = buildERC721(projectAddress, 10000, Constant.MINIMUM_VOTE_DELAY, Constant.MINIMUM_VOTE_DURATION);
        governance = CollectiveGovernance(_governanceAddress);
        proposalId = governance.propose();
        assertEq(proposalId, proposalId);
        vm.expectRevert("Quorum not allowed");
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 9999, Constant.MINIMUM_VOTE_DELAY, Constant.MINIMUM_VOTE_DURATION);
    }

    function testConfigureProjectMinimumQuorum() public {
        address projectAddress = address(_erc721);
        _governanceAddress = buildERC721(projectAddress, 10000, Constant.MINIMUM_VOTE_DELAY, Constant.MINIMUM_VOTE_DURATION);
        governance = CollectiveGovernance(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        proposalId = governance.propose();
        assertEq(proposalId, proposalId);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 10000, Constant.MINIMUM_VOTE_DELAY, Constant.MINIMUM_VOTE_DURATION);
        assertEq(_storage.minimumProjectQuorum(), 10000);
    }

    function testConfigureMinimumWithInvalidDuration() public {
        address projectAddress = address(_erc721);
        _governanceAddress = buildERC721(projectAddress, Constant.MINIMUM_PROJECT_QUORUM, Constant.MINIMUM_VOTE_DELAY, 6 days);
        governance = CollectiveGovernance(_governanceAddress);
        proposalId = governance.propose();
        assertEq(proposalId, proposalId);
        vm.expectRevert("Duration not allowed");
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, Constant.MINIMUM_PROJECT_QUORUM, Constant.MINIMUM_VOTE_DELAY, 5 days);
    }

    function testConfigureProjectMinimumDuration() public {
        address projectAddress = address(_erc721);
        _governanceAddress = buildERC721(projectAddress, Constant.MINIMUM_PROJECT_QUORUM, Constant.MINIMUM_VOTE_DELAY, 6 days);
        governance = CollectiveGovernance(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        proposalId = governance.propose();
        assertEq(proposalId, proposalId);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, Constant.MINIMUM_PROJECT_QUORUM, Constant.MINIMUM_VOTE_DELAY, 8 days);
        assertEq(_storage.voteDuration(proposalId), 8 days);
    }

    function testConfigureProjectMinimumDelay() public {
        address projectAddress = address(_erc721);
        _governanceAddress = buildERC721(projectAddress, Constant.MINIMUM_PROJECT_QUORUM, 1 days, Constant.MINIMUM_VOTE_DURATION);
        governance = CollectiveGovernance(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        proposalId = governance.propose();
        assertEq(proposalId, proposalId);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, Constant.MINIMUM_PROJECT_QUORUM, 10 days, Constant.MINIMUM_VOTE_DURATION);
        assertEq(_storage.voteDelay(proposalId), 10 days);
    }

    function testConfigureProjectMinimumDelayNotAllowed() public {
        address projectAddress = address(_erc721);
        _governanceAddress = buildERC721(
            projectAddress,
            Constant.MINIMUM_PROJECT_QUORUM,
            10 days,
            Constant.MINIMUM_VOTE_DURATION
        );
        governance = CollectiveGovernance(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        proposalId = governance.propose();
        assertEq(proposalId, proposalId);
        vm.expectRevert("Delay not allowed");
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

    function testOpenVoteWrongProposal() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        vm.expectRevert("Invalid proposal");
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
        vm.expectRevert("Share id is not valid");
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
        vm.expectRevert("Invalid proposal");
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId + 1, TOKEN_ID1);
    }

    function testVoteAgainstWrongProposal() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.expectRevert("Invalid proposal");
        vm.prank(_VOTER1, _VOTER1);
        governance.voteAgainst(proposalId + 1, TOKEN_ID1);
    }

    function testAbstainWrongProposal() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.expectRevert("Invalid proposal");
        vm.prank(_VOTER1, _VOTER1);
        governance.abstainFrom(proposalId + 1, TOKEN_ID1);
    }

    function testNonVoter() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.expectRevert("Not owner");
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
        vm.expectRevert("Not owner");
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
        vm.prank(_NOT_VOTER, _NOT_VOTER);
        vm.expectRevert("Not owner");
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
        vm.expectRevert("Vote is not final");
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
        vm.prank(_OWNER);
        vm.expectRevert("Vote in progress");
        governance.endVote(proposalId);
    }

    function testDoubleOpenVote() public {
        vm.startPrank(_governanceAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.expectRevert("Already open");
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
    }

    function testEndVoteWhenNotOpen() public {
        vm.startPrank(_governanceAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.expectRevert("Voting is closed");
        vm.prank(_SUPERVISOR);
        governance.endVote(proposalId);
    }

    function testOwnerCastVote() public {
        address[] memory voter = new address[](1);
        voter[0] = _VOTER1;
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        governance.configure(proposalId, 2);
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.expectRevert("Not voter");
        vm.prank(_OWNER, _OWNER);
        governance.voteFor(proposalId);
    }

    function testSupervisorCastVote() public {
        address[] memory voter = new address[](1);
        voter[0] = _VOTER1;
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        _storage = Storage(governance.getStorageAddress());
        vm.startPrank(_governanceAddress);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.expectRevert("Not voter");
        vm.prank(_SUPERVISOR, _SUPERVISOR);
        governance.voteFor(proposalId);
    }

    function testCastOneVoteNotOpen() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.expectRevert("Voting is closed");
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
    }

    function testCastOneVoteFromAll() public {
        _governanceAddress = buildOpenVote();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
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
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        _storage = Storage(governance.getStorageAddress());
        vm.expectRevert("Voting is closed");
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
    }

    function testCastTwoVote() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
        vm.expectRevert("Already voted");
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
        vm.expectRevert("Already voted");
        vm.prank(_VOTER2, _VOTER2);
        governance.voteFor(proposalId, TOKEN_ID1);
    }

    function testUndoRequiresOpen() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.enableUndoVote(proposalId, _SUPERVISOR);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.expectRevert("Voting is closed");
        vm.prank(_VOTER1, _VOTER1);
        governance.undoVote(proposalId);
    }

    function testVoterMayOnlyUndoPreviousVote() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.enableUndoVote(proposalId, _SUPERVISOR);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.expectRevert("No vote cast");
        vm.prank(_VOTER1, _VOTER1);
        governance.undoVote(proposalId);
    }

    function testUndoVoteOfPreviousOwner() public {
        vm.startPrank(_governanceAddress);
        _storage.enableUndoVote(proposalId, _SUPERVISOR);
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_OWNER);
        governance.startVote(proposalId);
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        vm.prank(_VOTER1, _VOTER1);
        _erc721.transferFrom(_VOTER1, _VOTER2, TOKEN_ID1);
        vm.expectRevert("Not voter");
        vm.prank(_VOTER2, _VOTER2);
        governance.undoVote(proposalId, TOKEN_ID1);
    }

    function testUndoVoteNotDefaultEnabled() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
        vm.expectRevert("Undo not enabled");
        vm.prank(_VOTER1, _VOTER1);
        governance.undoVote(proposalId);
    }

    function testSupervisorMayNotUndoVote() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
        vm.expectRevert("Not voter");
        vm.prank(_SUPERVISOR, _SUPERVISOR);
        governance.undoVote(proposalId);
    }

    function testOwnerMayNotUndoVote() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
        vm.expectRevert("Not voter");
        vm.prank(_OWNER, _OWNER);
        governance.undoVote(proposalId);
    }

    function testVotePassed() public {
        vm.warp(10);
        bytes memory code = address(_storage).code;

        address storageMock = governance.getStorageAddress();
        vm.etch(storageMock, code);

        uint256 forVotes = 200;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.forVotes.selector), abi.encode(forVotes));
        uint256 agVotes = 199;
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

        assertTrue(governance.getVoteSucceeded(proposalId));
    }

    function testVoteDidNotPass() public {
        vm.warp(10);
        bytes memory code = address(_storage).code;

        address storageMock = governance.getStorageAddress();
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

        address storageMock = governance.getStorageAddress();
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

        address storageMock = governance.getStorageAddress();
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
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.expectRevert("Vote is not closed");
        governance.getVoteSucceeded(proposalId);
    }

    function testMeasureIsVeto() public {
        _builder.aGovernance();
        VoterClassVoterPool voterPool = new VoterClassVoterPool(1);
        voterPool.addVoter(_VOTER1);
        voterPool.addVoter(_VOTER2);
        voterPool.makeFinal();
        _builder.withVoterClass(voterPool);
        _builder.withSupervisor(_SUPERVISOR);
        _governanceAddress = _builder.build();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
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
        vm.prank(_SUPERVISOR);
        governance.endVote(proposalId);
        vm.expectRevert("Vote cancelled");
        governance.getVoteSucceeded(proposalId);
    }

    function testMeasureLateVeto() public {
        uint256 blockTimestamp = block.timestamp;
        _builder.aGovernance();
        VoterClassVoterPool voterPool = new VoterClassVoterPool(1);
        voterPool.addVoter(_VOTER1);
        voterPool.addVoter(_VOTER2);
        voterPool.makeFinal();
        _builder.withVoterClass(voterPool);
        _builder.withSupervisor(_SUPERVISOR);
        _governanceAddress = _builder.build();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
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
        vm.prank(_SUPERVISOR);
        governance.endVote(proposalId);
        vm.expectRevert("Voting is closed");
        vm.prank(_SUPERVISOR);
        governance.veto(proposalId);
    }

    function testCastAgainstVoteNotOpen() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.expectRevert("Voting is closed");
        vm.prank(_VOTER1, _VOTER1);
        governance.voteAgainst(proposalId);
    }

    function testAbstainFromVoteNotOpen() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumRequired(proposalId, 2, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        vm.expectRevert("Voting is closed");
        vm.prank(_VOTER1, _VOTER1);
        governance.abstainFrom(proposalId);
    }

    function testVoteDelayPreventsVote(uint256 blockStep) public {
        vm.assume(blockStep >= 1 && blockStep < 100);
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumRequired(proposalId, 1, _SUPERVISOR);
        _storage.setVoteDelay(proposalId, 100, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        uint256 startTime = block.timestamp;
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.warp(startTime + blockStep);
        vm.expectRevert("Vote not active");
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
    }

    function testVoteAfterDuration(uint256 blockStep) public {
        vm.assume(blockStep > Constant.MINIMUM_VOTE_DURATION && blockStep < UINT256MAX - block.timestamp);
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        _storage = Storage(governance.getStorageAddress());
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumRequired(proposalId, 1, _SUPERVISOR);
        _storage.setVoteDuration(proposalId, Constant.MINIMUM_VOTE_DURATION, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        uint256 startTime = block.timestamp;
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.warp(startTime + blockStep);
        vm.expectRevert("Vote not active");
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId);
    }

    function testEndVoteWhileActive(uint256 blockStep) public {
        uint256 voteDelay = Constant.MINIMUM_VOTE_DURATION;
        // note one voteDelay one vote duration
        vm.assume(blockStep < Constant.MINIMUM_VOTE_DURATION);
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumRequired(proposalId, 1, _SUPERVISOR);
        _storage.setVoteDelay(proposalId, voteDelay, _SUPERVISOR);
        _storage.setVoteDuration(proposalId, Constant.MINIMUM_VOTE_DURATION, _SUPERVISOR);
        _storage.makeFinal(proposalId, _SUPERVISOR);
        vm.stopPrank();
        uint256 startTime = block.timestamp;
        vm.prank(_SUPERVISOR);
        governance.startVote(proposalId);
        vm.warp(startTime + voteDelay + blockStep);
        vm.expectRevert("Vote in progress");
        vm.prank(_SUPERVISOR);
        governance.endVote(proposalId);
    }

    function testEndVoteWhenFinished(uint256 blockStep) public {
        uint256 voteDelay = Constant.MINIMUM_VOTE_DURATION;
        vm.assume(
            blockStep >= voteDelay + Constant.MINIMUM_VOTE_DURATION &&
                blockStep < UINT256MAX - voteDelay - block.timestamp - Constant.MINIMUM_VOTE_DURATION
        );
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
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

    function testDirectStorageAccessToUndoVote() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.enableUndoVote(proposalId, _SUPERVISOR);
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

    function testDirectStorageAccessToUndo() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_VOTER1, _VOTER1);
        _storage.undoVoteById(proposalId, _VOTER1, TOKEN_ID1);
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

    function testCancelPropose() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.cancel(proposalId);
        uint256 nextProposalId = governance.propose();
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
        vm.expectRevert("Vote not modifiable");
        governance.configure(proposalId, 2);
        vm.stopPrank();
    }

    function testOpenAfterCancel() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.cancel(proposalId);
        vm.expectRevert("Vote cancelled");
        governance.startVote(proposalId);
        vm.stopPrank();
    }

    function testCancelAfterOpen() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        uint256 blockTimestamp = block.timestamp;
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.warp(blockTimestamp + 2);
        vm.expectRevert("Not possible");
        governance.cancel(proposalId);
        vm.stopPrank();
    }

    function testCancelAfterEnd() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        uint256 blockTimestamp = block.timestamp;
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.warp(blockTimestamp + Constant.MINIMUM_VOTE_DURATION);
        governance.endVote(proposalId);
        vm.expectRevert("Not possible");
        governance.cancel(proposalId);
        vm.stopPrank();
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
        vm.expectRevert("Invalid proposal");
        governance.veto(proposalId + 1);
        vm.stopPrank();
    }

    function testAttachTransaction(uint256 systemClock) public {
        vm.assume(systemClock < Constant.UINT_MAX - block.timestamp - Constant.TIMELOCK_MAXIMUM_DELAY);
        vm.warp(systemClock);
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory clldata = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = block.timestamp + 2 days;
        vm.prank(_OWNER);
        governance.attachTransaction(proposalId, flagMock, 0, "", clldata, scheduleTime);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 1);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        vm.warp(scheduleTime + 7 days);
        assertFalse(flag.isSet());
        vm.prank(_OWNER);
        governance.endVote(proposalId);
        assertTrue(flag.isSet());
        assertTrue(_storage.isExecuted(proposalId));
    }

    function testAttachTransactionThenDoubleExecute(uint256 systemClock) public {
        vm.assume(systemClock < Constant.UINT_MAX - block.timestamp - Constant.TIMELOCK_MAXIMUM_DELAY);
        vm.warp(systemClock);
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory clldata = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = block.timestamp + 2 days;
        vm.prank(_OWNER);
        governance.attachTransaction(proposalId, flagMock, 0, "", clldata, scheduleTime);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 1);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        vm.warp(scheduleTime + 7 days);
        assertFalse(flag.isSet());
        vm.prank(_OWNER);
        governance.endVote(proposalId);
        vm.expectRevert("Voting is closed");
        vm.prank(_OWNER);
        governance.endVote(proposalId);
    }

    function testAttachAndClearMultipleTransaction() public {
        vm.warp(400000000);
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory data = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = block.timestamp + 2 days;
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(_OWNER);
            governance.attachTransaction(proposalId, address(0x10), i, "", "", scheduleTime + i);
        }
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(address(governance));
            _storage.clearTransaction(proposalId, i, _OWNER);
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
        vm.prank(_OWNER);
        governance.endVote(proposalId);
        assertTrue(flag.isSet());
        assertTrue(_storage.isExecuted(proposalId));
    }

    function testAttachTransactionWithSuccessfulOutcomeButDoNotExecute() public {
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
        governance.voteFor(proposalId, TOKEN_ID1);
        vm.warp(scheduleTime + 7 days);
        assertFalse(flag.isSet());
        vm.prank(_OWNER);
        governance.endVoteAndCancelTransaction(proposalId);
        assertFalse(flag.isSet());
        assertFalse(_storage.isExecuted(proposalId));
    }

    function testAttachTransactionButVeto() public {
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
        governance.voteFor(proposalId, TOKEN_ID1);
        vm.warp(block.timestamp + 1 days);
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
        uint256 etaOfLock = block.timestamp + 7 days;
        governance.attachTransaction(proposalId, address(0x7fff), 0, "", "save()", etaOfLock);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 1);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        TimeLocker locker = new TimeLock(Constant.TIMELOCK_MINIMUM_DELAY);
        bytes32 txHash = locker.getTxHash(address(0x7fff), 0, "", "save()", etaOfLock);
        vm.expectRevert(abi.encodeWithSelector(TimeLocker.TransactionLocked.selector, txHash, etaOfLock));
        vm.warp(block.timestamp + Constant.MINIMUM_VOTE_DURATION);
        vm.prank(_OWNER);
        governance.endVote(proposalId);
    }

    function testCastVoteNotOrigin() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.expectRevert("Not origin");
        vm.prank(_VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
    }

    function testCastAgainstVoteNotOrigin() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.expectRevert("Not origin");
        vm.prank(_VOTER1);
        governance.voteAgainst(proposalId, TOKEN_ID1);
    }

    function testCastAbstainNotOrigin() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.expectRevert("Not origin");
        vm.prank(_VOTER1);
        governance.abstainFrom(proposalId, TOKEN_ID1);
    }

    function testFailCastVoteAndUndoNotOrigin() public {
        vm.prank(_governanceAddress);
        _storage.enableUndoVote(proposalId, _SUPERVISOR);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        // solhint-disable-next-line avoid-tx-origin
        address origOrigin = tx.origin;
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        vm.expectRevert("Not origin");
        vm.prank(_VOTER1, origOrigin);
        governance.undoVote(proposalId, TOKEN_ID1);
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
        assertTrue(_VOTER1.balance > 0);
        assertApproxEqAbs(_VOTER1.balance, 8806356 gwei, 500 gwei);
    }

    function testCastAgainstVoteWithRefund() public {
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
        assertTrue(_VOTER1.balance > 0);
        assertApproxEqAbs(_VOTER1.balance, 7765420 gwei, 500 gwei);
    }

    function testAbstainWithRefund() public {
        vm.fee(50 gwei);

        vm.deal(_OWNER, 1 ether);
        vm.prank(_OWNER);
        _governanceAddress.transfer(1 ether);

        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.abstainFrom(proposalId, TOKEN_ID1);
        assertTrue(_VOTER1.balance > 0);
        assertApproxEqAbs(_VOTER1.balance, 8531692 gwei, 500 gwei);
    }

    function testVoteAndUndoWithRefund() public {
        vm.fee(50 gwei);

        vm.deal(_OWNER, 1 ether);
        vm.prank(_OWNER);
        _governanceAddress.transfer(1 ether);
        vm.prank(_governanceAddress);
        _storage.enableUndoVote(proposalId, _SUPERVISOR);
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.startPrank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        governance.undoVote(proposalId, TOKEN_ID1);
        vm.stopPrank();
        assertTrue(_VOTER1.balance > 0);
        assertApproxEqAbs(_VOTER1.balance, 12192804 gwei, 500 gwei);
    }

    function testCastVoteWithMaximumRefund() public {
        vm.fee(1000 gwei);

        vm.deal(_OWNER, 1 ether);
        vm.prank(_OWNER);
        _governanceAddress.transfer(1 ether);

        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(proposalId, 2);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1);
        assertTrue(_VOTER1.balance > 0);
        uint256 expectRefund = 17104653 gwei;
        assertApproxEqAbs(_VOTER1.balance, expectRefund, 500 gwei);
        assertApproxEqAbs(_governanceAddress.balance, 1 ether - expectRefund, 500 gwei);
    }

    function testConfigureWithDescriptionAndUrl() public {
        vm.startPrank(_OWNER, _OWNER);
        governance.describe(proposalId, "A test vote", "https://https://collectivexyz.github.io/collective-governance-v1/");
        governance.configure(proposalId, 2);
        vm.stopPrank();

        assertEq(governance.meta().description(proposalId), "A test vote");
        assertEq(governance.meta().url(proposalId), "https://https://collectivexyz.github.io/collective-governance-v1/");
    }

    function testConfigureWithDescriptionAndUrlIfFinal() public {
        vm.startPrank(_OWNER, _OWNER);
        governance.configure(proposalId, 2);
        vm.expectRevert("Vote is final");
        governance.describe(proposalId, "A test vote", "https://https://collectivexyz.github.io/collective-governance-v1/");
        vm.stopPrank();
    }

    function testConfigureWithMeta() public {
        vm.startPrank(_OWNER, _OWNER);
        uint256 mid = governance.addMeta(proposalId, "e", "2.718281828459045235");
        governance.configure(proposalId, 2);
        vm.stopPrank();
        (bytes32 _name, string memory _value) = governance.meta().getMeta(proposalId, mid);
        assertEq(_name, "e");
        assertEq(_value, "2.718281828459045235");
    }

    function testChoiceVoteConfigurationRequired() public {
        vm.startPrank(_OWNER, _OWNER);
        governance.cancel(proposalId);
        vm.warp(block.timestamp + Constant.MINIMUM_VOTE_DURATION);
        proposalId = governance.propose(7);
        vm.expectRevert("Choice vote requires setup");
        governance.configure(proposalId, 2);
        vm.stopPrank();
    }

    function testChoiceVoteSimple() public {
        vm.startPrank(_OWNER, _OWNER);
        governance.cancel(proposalId);
        vm.warp(block.timestamp + Constant.MINIMUM_VOTE_DURATION);
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory data = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = block.timestamp + 2 days;
        proposalId = governance.propose(3);
        uint256 tid = governance.attachTransaction(proposalId, flagMock, 0, "", data, scheduleTime);
        governance.setChoice(proposalId, 2, "choice", "a choice for this vote", tid);
        for (uint256 i = 0; i < 2; i++) {
            governance.setChoice(proposalId, i, "choice", "a choice for this vote", 0);
        }
        governance.configure(proposalId, 1);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.prank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1, 2);
        vm.warp(scheduleTime);
        vm.prank(_OWNER, _OWNER);
        governance.endVote(proposalId);
        // vote is passed, choice is executed
        assertTrue(flag.isSet());
        assertTrue(_storage.isExecuted(proposalId));
    }

    function testChoiceVoteQuorumNotReached() public {
        vm.startPrank(_OWNER, _OWNER);
        governance.cancel(proposalId);
        vm.warp(block.timestamp + Constant.MINIMUM_VOTE_DURATION);
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory data = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = block.timestamp + 2 days;
        proposalId = governance.propose(3);
        uint256 tid = governance.attachTransaction(proposalId, flagMock, 0, "", data, scheduleTime);
        governance.setChoice(proposalId, 2, "choice", "a choice for this vote", tid);
        for (uint256 i = 0; i < 2; i++) {
            governance.setChoice(proposalId, i, "choice", "a choice for this vote", 0);
        }
        governance.configure(proposalId, _NTOKEN);
        governance.startVote(proposalId);
        vm.stopPrank();
        vm.startPrank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1, 2);
        governance.voteFor(proposalId, TOKEN_ID2, 2);
        governance.voteFor(proposalId, TOKEN_ID3, 2);
        governance.voteFor(proposalId, TOKEN_ID4, 0);
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
        proposalId = governance.propose(3);
        uint256 tid = governance.attachTransaction(proposalId, flagMock, 0, "", data, scheduleTime);
        governance.setChoice(proposalId, 0, "choice", "a choice for this vote", 0);
        governance.setChoice(proposalId, 1, "choice", "a choice for this vote", tid);
        governance.setChoice(proposalId, 2, "choice", "a choice for this vote", 0);
        governance.configure(proposalId, _NTOKEN);
        governance.startVote(proposalId);
        vm.stopPrank();
        // cid 1 must execute
        vm.startPrank(_VOTER1, _VOTER1);
        governance.voteFor(proposalId, TOKEN_ID1, 1);
        governance.voteFor(proposalId, TOKEN_ID2, 2);
        governance.voteFor(proposalId, TOKEN_ID3, 2);
        governance.voteFor(proposalId, TOKEN_ID4, 1);
        governance.voteFor(proposalId, TOKEN_ID5, 1);
        vm.stopPrank();
        vm.warp(scheduleTime);
        vm.prank(_OWNER, _OWNER);
        governance.endVote(proposalId);
        // vote is passed, choice is executed
        assertTrue(flag.isSet());
        assertTrue(_storage.isExecuted(proposalId));
    }

    function mintTokens() private returns (IERC721) {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_VOTER1, TOKEN_ID1);
        merc721.mintTo(_VOTER1, TOKEN_ID2);
        merc721.mintTo(_VOTER1, TOKEN_ID3);
        merc721.mintTo(_VOTER1, TOKEN_ID4);
        merc721.mintTo(_VOTER1, TOKEN_ID5);
        _tokenIdList.push(TOKEN_ID1);
        _tokenIdList.push(TOKEN_ID2);
        _tokenIdList.push(TOKEN_ID3);
        _tokenIdList.push(TOKEN_ID4);
        _tokenIdList.push(TOKEN_ID5);
        return merc721;
    }

    function buildERC721(address projectAddress) private returns (address payable) {
        VoterClass _class = new VoterClassERC721(projectAddress, 1);
        return _builder.aGovernance().withVoterClass(_class).withSupervisor(_SUPERVISOR).build();
    }

    function buildERC721(
        address projectAddress,
        uint256 minimumProjectQuorum,
        uint256 minimumVoteDelay,
        uint256 minimumDuration
    ) private returns (address payable) {
        VoterClass _class = new VoterClassERC721(projectAddress, 1);
        return
            _builder
                .aGovernance()
                .withVoterClass(_class)
                .withSupervisor(_SUPERVISOR)
                .withProjectQuorum(minimumProjectQuorum)
                .withMinimumDelay(minimumVoteDelay)
                .withMinimumDuration(minimumDuration)
                .build();
    }

    function buildVoterPool() private returns (address payable) {
        VoterClassVoterPool _class = new VoterClassVoterPool(1);
        _class.addVoter(_VOTER1);
        _class.makeFinal();
        return _builder.aGovernance().withVoterClass(_class).withSupervisor(_SUPERVISOR).build();
    }

    function buildOpenVote() private returns (address payable) {
        VoterClass _class = new VoterClassOpenVote(1);
        return _builder.aGovernance().withVoterClass(_class).withSupervisor(_SUPERVISOR).build();
    }
}

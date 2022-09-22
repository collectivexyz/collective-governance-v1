// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "forge-std/Test.sol";

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

contract CollectiveGovernanceTest is Test {
    uint256 private constant UINT256MAX = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

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
    uint256 private constant TOKEN_ID2 = 78;
    uint256 private constant TOKEN_ID3 = 79;
    uint256 private constant INVALID_TOKEN = TOKEN_ID1 - 1;

    GovernanceBuilder private _builder;
    CollectiveGovernance private governance;
    Storage private _storage;
    IERC721 private _erc721;
    address private _governanceAddress;

    uint32 private version;
    uint256 private pid;
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
        pid = governance.propose();
    }

    function testFailClassNotFinal() public {
        VoterClass _class = new VoterClassVoterPool(1);
        address[] memory superList = new address[](1);
        superList[0] = _SUPERVISOR;
        new CollectiveGovernance(superList, _class);
    }

    function testGetStorageAddress() public {
        address storageAddress = governance.getStorageAddress();
        assertTrue(storageAddress != address(0x0));
    }

    function testName() public {
        assertEq(governance.name(), "collective.xyz governance");
    }

    function testVersion() public {
        assertEq(governance.version(), 1);
    }

    function testPropose() public {
        assertEq(pid, PROPOSAL_ID);
    }

    function testConfigure721() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        assertTrue(governance.isOpen(PROPOSAL_ID));
        assertEq(_storage.quorumRequired(PROPOSAL_ID), 2);
        assertTrue(governance.isOpen(PROPOSAL_ID));
    }

    function testCastSimpleVote721() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID, TOKEN_ID1);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
    }

    function testCastSimpleVote721BadShare() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_VOTER1);
        vm.expectRevert("Share id is not valid");
        governance.voteFor(PROPOSAL_ID, NONE);
    }

    function testCastSimpleVote721NoShare() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.expectRevert("No such token");
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID, INVALID_TOKEN);
    }

    function testCastSimpleVoteOpen() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID, TOKEN_ID1);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
    }

    function testCastMultipleVote() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 5, 2);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID, _tokenIdList);
        assertEq(_storage.forVotes(PROPOSAL_ID), 3);
    }

    function testCastMultipleVoteAgainst() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 5, 2);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_VOTER1);
        governance.voteAgainst(PROPOSAL_ID, _tokenIdList);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 3);
    }

    function testCastMultipleVoteAbstain() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 5, 2);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_VOTER1);
        governance.abstainFrom(PROPOSAL_ID, _tokenIdList);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 3);
    }

    function testCastSimpleVoteWhileActive() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 2, 10);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_VOTER1);
        vm.roll(block.number + 2);
        governance.voteFor(PROPOSAL_ID, TOKEN_ID1);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
    }

    function testNonVoter() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.expectRevert("Not owner");
        vm.prank(_NOT_VOTER);
        governance.voteFor(PROPOSAL_ID, TOKEN_ID1);
    }

    function testVoteAgainst() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_VOTER1);
        governance.voteAgainst(PROPOSAL_ID, TOKEN_ID1);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 1);
    }

    function testVoteAgainstNonVoter() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.expectRevert("Not owner");
        vm.prank(_NOT_VOTER);
        governance.voteAgainst(PROPOSAL_ID, TOKEN_ID1);
    }

    function testAbstain() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_VOTER1);
        governance.abstainFrom(PROPOSAL_ID, TOKEN_ID1);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 1);
    }

    function testAbstentionNonVoter() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_NOT_VOTER);
        vm.expectRevert("Not owner");
        governance.abstainFrom(PROPOSAL_ID, TOKEN_ID1);
    }

    function testOpenVote() public {
        vm.startPrank(_governanceAddress);
        _storage.setQuorumThreshold(PROPOSAL_ID, 75, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        governance.isOpen(PROPOSAL_ID);
    }

    function testOpenVoteRequiresReady() public {
        vm.prank(_governanceAddress);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        vm.expectRevert("Voting is not ready");
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
    }

    function testOwnerOpenVote() public {
        vm.startPrank(_governanceAddress);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_OWNER);
        governance.openVote(PROPOSAL_ID);
    }

    function testOwnerEndVote() public {
        uint256 blockNumber = block.number;
        vm.startPrank(_governanceAddress);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        assertTrue(governance.isOpen(PROPOSAL_ID));
        vm.roll(blockNumber + 2);
        vm.prank(_OWNER);
        governance.endVote(PROPOSAL_ID);
        assertFalse(governance.isOpen(PROPOSAL_ID));
    }

    function testEarlyEndVote() public {
        vm.startPrank(_governanceAddress);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        assertTrue(governance.isOpen(PROPOSAL_ID));
        vm.prank(_OWNER);
        vm.expectRevert("Vote open");
        governance.endVote(PROPOSAL_ID);
    }

    function testDoubleOpenVote() public {
        vm.startPrank(_governanceAddress);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.expectRevert("Already open");
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
    }

    function testEndVoteWhenNotOpen() public {
        vm.startPrank(_governanceAddress);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.expectRevert("Voting is closed");
        vm.prank(_SUPERVISOR);
        governance.endVote(PROPOSAL_ID);
    }

    function testOwnerCastVote() public {
        address[] memory voter = new address[](1);
        voter[0] = _VOTER1;
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        governance.configure(PROPOSAL_ID, 2, 2);
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.expectRevert("Not voter");
        vm.prank(_OWNER);
        governance.voteFor(PROPOSAL_ID);
    }

    function testSupervisorCastVote() public {
        address[] memory voter = new address[](1);
        voter[0] = _VOTER1;
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        _storage = Storage(governance.getStorageAddress());
        vm.startPrank(_governanceAddress);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.expectRevert("Not voter");
        vm.prank(_SUPERVISOR);
        governance.voteFor(PROPOSAL_ID);
    }

    function testCastOneVoteNotOpen() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.expectRevert("Voting is closed");
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testCastOneVoteFromAll() public {
        _governanceAddress = buildOpenVote();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testCastVoteNotOpened() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        _storage = Storage(governance.getStorageAddress());
        vm.expectRevert("Voting is closed");
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testCastTwoVote() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID);
        vm.expectRevert("Already voted");
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testCastDoubleVoteOnTransferToken() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID, TOKEN_ID1);
        vm.prank(_VOTER1);
        _erc721.transferFrom(_VOTER1, _VOTER2, TOKEN_ID1);
        vm.expectRevert("Already voted");
        vm.prank(_VOTER2);
        governance.voteFor(PROPOSAL_ID, TOKEN_ID1);
    }

    function testUndoRequiresOpen() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.enableUndoVote(PROPOSAL_ID, _SUPERVISOR);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.expectRevert("Voting is closed");
        vm.prank(_VOTER1);
        governance.undoVote(PROPOSAL_ID);
    }

    function testVoterMayOnlyUndoPreviousVote() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.enableUndoVote(PROPOSAL_ID, _SUPERVISOR);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.expectRevert("No vote cast");
        vm.prank(_VOTER1);
        governance.undoVote(PROPOSAL_ID);
    }

    function testUndoVoteOfPreviousOwner() public {
        vm.startPrank(_governanceAddress);
        _storage.enableUndoVote(PROPOSAL_ID, _SUPERVISOR);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_OWNER);
        governance.openVote(PROPOSAL_ID);
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID, TOKEN_ID1);
        vm.prank(_VOTER1);
        _erc721.transferFrom(_VOTER1, _VOTER2, TOKEN_ID1);
        vm.expectRevert("Not voter");
        vm.prank(_VOTER2);
        governance.undoVote(PROPOSAL_ID, TOKEN_ID1);
    }

    function testUndoVoteNotDefaultEnabled() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID);
        vm.expectRevert("Undo not enabled");
        vm.prank(_VOTER1);
        governance.undoVote(PROPOSAL_ID);
    }

    function testSupervisorMayNotUndoVote() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID);
        vm.expectRevert("Not voter");
        vm.prank(_SUPERVISOR);
        governance.undoVote(PROPOSAL_ID);
    }

    function testOwnerMayNotUndoVote() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID);
        vm.expectRevert("Not voter");
        vm.prank(_OWNER);
        governance.undoVote(PROPOSAL_ID);
    }

    function testVotePassed() public {
        vm.roll(10);
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
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.maxPassThreshold.selector), abi.encode(0xffffffff));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.startBlock.selector), abi.encode(block.number - 2));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.endBlock.selector), abi.encode(block.number - 1));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isReady.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isVeto.selector), abi.encode(false));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isSupervisor.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.validOrRevert.selector), abi.encode(PROPOSAL_ID));

        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.prank(_SUPERVISOR);
        governance.endVote(PROPOSAL_ID);

        assertTrue(governance.getVoteSucceeded(PROPOSAL_ID));
    }

    function testVoteDidNotPass() public {
        vm.roll(10);
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
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.maxPassThreshold.selector), abi.encode(0xffffffff));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.startBlock.selector), abi.encode(block.number - 2));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.endBlock.selector), abi.encode(block.number - 1));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isReady.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isVeto.selector), abi.encode(false));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isSupervisor.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.validOrRevert.selector), abi.encode(PROPOSAL_ID));

        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.prank(_SUPERVISOR);
        governance.endVote(PROPOSAL_ID);

        assertFalse(governance.getVoteSucceeded(PROPOSAL_ID));
    }

    function testTieVoteDidNotPass() public {
        vm.roll(10);
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
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.maxPassThreshold.selector), abi.encode(0xffffffff));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.startBlock.selector), abi.encode(block.number - 2));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.endBlock.selector), abi.encode(block.number - 1));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isReady.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isVeto.selector), abi.encode(false));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isSupervisor.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.validOrRevert.selector), abi.encode(PROPOSAL_ID));

        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.prank(_SUPERVISOR);
        governance.endVote(PROPOSAL_ID);

        assertFalse(governance.getVoteSucceeded(PROPOSAL_ID));
    }

    function testMeasureNoQuorum() public {
        vm.roll(10);
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
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.startBlock.selector), abi.encode(block.number - 2));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.endBlock.selector), abi.encode(block.number - 1));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.maxPassThreshold.selector), abi.encode(0xffffffff));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isReady.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isVeto.selector), abi.encode(false));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isSupervisor.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.validOrRevert.selector), abi.encode(PROPOSAL_ID));

        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.prank(_SUPERVISOR);
        governance.endVote(PROPOSAL_ID);

        vm.expectRevert("Not enough participants");
        governance.getVoteSucceeded(PROPOSAL_ID);
    }

    function testGetVoteSucceededOnOpenMeasure() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.expectRevert("Vote is not closed");
        governance.getVoteSucceeded(PROPOSAL_ID);
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
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        uint256 blockNumber = block.number;
        governance.openVote(PROPOSAL_ID);
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID);
        vm.prank(_VOTER2);
        governance.voteFor(PROPOSAL_ID);
        vm.prank(_SUPERVISOR);
        governance.veto(PROPOSAL_ID);
        assertTrue(_storage.isVeto(PROPOSAL_ID));
        vm.roll(blockNumber + 2);
        vm.prank(_SUPERVISOR);
        governance.endVote(PROPOSAL_ID);
        vm.expectRevert("Vote cancelled");
        governance.getVoteSucceeded(PROPOSAL_ID);
    }

    function testMeasureLateVeto() public {
        uint256 blockNumber = block.number;
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
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID);
        vm.prank(_VOTER2);
        governance.voteFor(PROPOSAL_ID);
        vm.roll(blockNumber + 2);
        vm.prank(_SUPERVISOR);
        governance.endVote(PROPOSAL_ID);
        vm.expectRevert("Voting is closed");
        vm.prank(_SUPERVISOR);
        governance.veto(PROPOSAL_ID);
    }

    function testCastAgainstVoteNotOpen() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.expectRevert("Voting is closed");
        vm.prank(_VOTER1);
        governance.voteAgainst(PROPOSAL_ID);
    }

    function testAbstainFromVoteNotOpen() public {
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        vm.expectRevert("Voting is closed");
        vm.prank(_VOTER1);
        governance.abstainFrom(PROPOSAL_ID);
    }

    function testVoteDelayPreventsVote(uint256 blockStep) public {
        vm.assume(blockStep >= 1 && blockStep < 100);
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, _SUPERVISOR);
        _storage.setVoteDelay(PROPOSAL_ID, 100, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        uint256 startBlock = block.number;
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.roll(startBlock + blockStep);
        vm.expectRevert("Vote not active");
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testVoteAfterDuration(uint256 blockStep) public {
        vm.assume(blockStep > 10 && blockStep < UINT256MAX - block.number);
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        _storage = Storage(governance.getStorageAddress());
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, _SUPERVISOR);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        uint256 startBlock = block.number;
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.roll(startBlock + blockStep);
        vm.expectRevert("Vote not active");
        vm.prank(_VOTER1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testEndVoteWhileActive(uint256 blockStep) public {
        vm.assume(blockStep > 0 && blockStep < 15);
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, _SUPERVISOR);
        _storage.setVoteDelay(PROPOSAL_ID, 5, _SUPERVISOR);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        uint256 startBlock = block.number;
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.roll(startBlock + blockStep);
        vm.expectRevert("Vote open");
        vm.prank(_SUPERVISOR);
        governance.endVote(PROPOSAL_ID);
    }

    function testEndVoteWhenFinished(uint256 blockStep) public {
        vm.assume(blockStep >= 16 && blockStep < UINT256MAX - block.number);
        _governanceAddress = buildVoterPool();
        governance = CollectiveGovernance(_governanceAddress);
        governance.propose();
        vm.startPrank(_governanceAddress);
        _storage = Storage(governance.getStorageAddress());
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, _SUPERVISOR);
        _storage.setVoteDelay(PROPOSAL_ID, 5, _SUPERVISOR);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10, _SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
        vm.stopPrank();
        uint256 startBlock = block.number;
        vm.prank(_SUPERVISOR);
        governance.openVote(PROPOSAL_ID);
        vm.roll(startBlock + blockStep);
        vm.prank(_SUPERVISOR);
        governance.endVote(PROPOSAL_ID);
        assertFalse(governance.isOpen(PROPOSAL_ID));
    }

    function testDirectStorageAccessToSupervisor() public {
        vm.expectRevert("Not permitted");
        vm.prank(_OWNER);
        _storage.registerSupervisor(PROPOSAL_ID, _VOTER1, _OWNER);
    }

    function testDirectStorageAccessToQuorum() public {
        vm.expectRevert("Not permitted");
        vm.prank(_SUPERVISOR);
        _storage.setQuorumThreshold(PROPOSAL_ID, 0xffffffff, _SUPERVISOR);
    }

    function testDirectStorageAccessToDuration() public {
        vm.expectRevert("Not permitted");
        vm.prank(_SUPERVISOR);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 0xffffffff, _SUPERVISOR);
    }

    function testDirectStorageAccessToDelay() public {
        vm.expectRevert("Not permitted");
        vm.prank(_SUPERVISOR);
        _storage.setVoteDelay(PROPOSAL_ID, 0xffffffff, _SUPERVISOR);
    }

    function testDirectStorageAccessToUndoVote() public {
        vm.expectRevert("Not permitted");
        vm.prank(_SUPERVISOR);
        _storage.enableUndoVote(PROPOSAL_ID, _SUPERVISOR);
    }

    function testDirectStorageAccessToReady() public {
        vm.expectRevert("Not permitted");
        vm.prank(_SUPERVISOR);
        _storage.makeReady(PROPOSAL_ID, _SUPERVISOR);
    }

    function testDirectStorageAccessToCastVote() public {
        vm.expectRevert("Not permitted");
        vm.prank(_VOTER1);
        _storage.voteForByShare(PROPOSAL_ID, _VOTER1, TOKEN_ID1);
    }

    function testDirectStorageAccessToCastVoteAgainst() public {
        vm.expectRevert("Not permitted");
        vm.prank(_VOTER1);
        _storage.voteAgainstByShare(PROPOSAL_ID, _VOTER1, TOKEN_ID1);
    }

    function testDirectStorageAccessToAbstain() public {
        vm.expectRevert("Not permitted");
        vm.prank(_VOTER1);
        _storage.abstainForShare(PROPOSAL_ID, _VOTER1, TOKEN_ID1);
    }

    function testDirectStorageAccessToUndo() public {
        vm.expectRevert("Not permitted");
        vm.prank(_VOTER1);
        _storage.undoVoteById(PROPOSAL_ID, _VOTER1, TOKEN_ID1);
    }

    function testDirectStorageAccessToVeto() public {
        vm.expectRevert("Not permitted");
        vm.prank(_SUPERVISOR);
        _storage.veto(PROPOSAL_ID, msg.sender);
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
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.cancel(PROPOSAL_ID);
        vm.stopPrank();
        assertFalse(governance.isOpen(PROPOSAL_ID));
        assertTrue(_storage.isCancel(PROPOSAL_ID));
    }

    function testCancelNotConfigured() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.cancel(PROPOSAL_ID);
        vm.stopPrank();
        assertFalse(governance.isOpen(PROPOSAL_ID));
        assertTrue(_storage.isCancel(PROPOSAL_ID));
    }

    function testConfigureAfterCancel() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.cancel(PROPOSAL_ID);
        vm.expectRevert("Vote not modifiable");
        governance.configure(PROPOSAL_ID, 2, 2);
        vm.stopPrank();
    }

    function testOpenAfterCancel() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.cancel(PROPOSAL_ID);
        vm.expectRevert("Vote cancelled");
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
    }

    function testCancelAfterOpen() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.openVote(PROPOSAL_ID);
        vm.expectRevert("Not possible");
        governance.cancel(PROPOSAL_ID);
        vm.stopPrank();
    }

    function testCancelAfterEnd() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        uint256 blockNumber = block.number;
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.openVote(PROPOSAL_ID);
        vm.roll(blockNumber + 2);
        governance.endVote(PROPOSAL_ID);
        vm.expectRevert("Not possible");
        governance.cancel(PROPOSAL_ID);
        vm.stopPrank();
    }

    function testEndNowIfVeto() public {
        vm.startPrank(_SUPERVISOR, _SUPERVISOR);
        governance.configure(PROPOSAL_ID, 2, 2);
        governance.openVote(PROPOSAL_ID);
        governance.veto(PROPOSAL_ID);
        governance.endVote(PROPOSAL_ID);
        vm.stopPrank();
    }

    function mintTokens() private returns (IERC721) {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_VOTER1, TOKEN_ID1);
        merc721.mintTo(_VOTER1, TOKEN_ID2);
        merc721.mintTo(_VOTER1, TOKEN_ID3);
        _tokenIdList.push(TOKEN_ID1);
        _tokenIdList.push(TOKEN_ID2);
        _tokenIdList.push(TOKEN_ID3);
        return merc721;
    }

    function buildERC721(address projectAddress) private returns (address) {
        VoterClass _class = new VoterClassERC721(projectAddress, 1);
        return _builder.aGovernance().withVoterClass(_class).withSupervisor(_SUPERVISOR).build();
    }

    function buildVoterPool() private returns (address) {
        VoterClassVoterPool _class = new VoterClassVoterPool(1);
        _class.addVoter(_VOTER1);
        _class.makeFinal();
        return _builder.aGovernance().withVoterClass(_class).withSupervisor(_SUPERVISOR).build();
    }

    function buildOpenVote() private returns (address) {
        VoterClass _class = new VoterClassOpenVote(1);
        return _builder.aGovernance().withVoterClass(_class).withSupervisor(_SUPERVISOR).build();
    }
}

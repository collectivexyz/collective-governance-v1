// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "forge-std/Test.sol";

import "../contracts/Storage.sol";
import "../contracts/GovernanceStorage.sol";
import "../contracts/VoteStrategy.sol";
import "../contracts/Governance.sol";
import "../contracts/CollectiveGovernance.sol";
import "./MockERC721.sol";

contract CollectiveGovernanceTest is Test {
    uint256 public constant UINT256MAX = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    CollectiveGovernance private governance;
    Storage private _storage;
    IERC721 private _erc721;
    address private _cognate;

    address public immutable owner = address(0x1);
    address public immutable supervisor = address(0x123);
    address public immutable nonSupervisor = address(0x123eee);
    address public immutable voter1 = address(0xfff1);
    address public immutable voter2 = address(0xfff2);
    address public immutable voter3 = address(0xfff3);
    uint256 public immutable NONE = 0;
    uint256 public immutable PROPOSAL_ID = 1;

    address public immutable someoneElse = address(0x123);
    address public immutable nonvoter = address(0xffff);
    uint256 public immutable TOKEN_ID1 = 77;
    uint256 public immutable TOKEN_ID2 = 78;
    uint256 public immutable TOKEN_ID3 = 79;
    uint32 private version;
    uint256 private pid;
    uint256[] private _tokenIdList;

    function setUp() public {
        vm.clearMockedCalls();
        governance = new CollectiveGovernance();
        _cognate = address(governance);
        _storage = Storage(governance.getStorageAddress());
        version = governance.version();
        _erc721 = mintTokens();
        vm.prank(owner);
        pid = governance.propose();
        vm.prank(_cognate);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
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
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        assertTrue(governance.isOpen(PROPOSAL_ID));
        assertEq(_storage.quorumRequired(PROPOSAL_ID), 2);
        assertTrue(governance.isOpen(PROPOSAL_ID));
    }

    function testCastSimpleVote721() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteForWithTokenId(PROPOSAL_ID, TOKEN_ID1);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
    }

    function testCastSimpleVoteOpen() public {
        vm.startPrank(owner, owner);
        governance.configureOpenVote(PROPOSAL_ID, 2, 2);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
    }

    function testCastMultipleVote() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 5, address(_erc721), 2);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteForWithTokenList(PROPOSAL_ID, _tokenIdList);
        assertEq(_storage.forVotes(PROPOSAL_ID), 3);
    }

    function testCastMultipleVoteAgainst() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 5, address(_erc721), 2);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteAgainstWithTokenList(PROPOSAL_ID, _tokenIdList);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 3);
    }

    function testCastMultipleVoteAbstain() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 5, address(_erc721), 2);
        vm.stopPrank();
        vm.prank(voter1);
        governance.abstainWithTokenList(PROPOSAL_ID, _tokenIdList);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 3);
    }

    function testCastSimpleVoteWhileActive() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 10);
        vm.stopPrank();
        vm.prank(voter1);
        vm.roll(block.number + 2);
        governance.voteForWithTokenId(PROPOSAL_ID, TOKEN_ID1);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
    }

    function testNonVoter() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.expectRevert("Not owner of specified token");
        vm.prank(nonvoter);
        governance.voteForWithTokenId(PROPOSAL_ID, TOKEN_ID1);
    }

    function testVoteAgainst() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteAgainstWithTokenId(PROPOSAL_ID, TOKEN_ID1);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 1);
    }

    function testVoteAgainstNonVoter() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.expectRevert("Not owner of specified token");
        vm.prank(nonvoter);
        governance.voteAgainstWithTokenId(PROPOSAL_ID, TOKEN_ID1);
    }

    function testAbstain() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.prank(voter1);
        governance.abstainWithTokenId(PROPOSAL_ID, TOKEN_ID1);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 1);
    }

    function testAbstentionNonVoter() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.prank(nonvoter);
        vm.expectRevert("Not owner of specified token");
        governance.abstainWithTokenId(PROPOSAL_ID, TOKEN_ID1);
    }

    function testOpenVote() public {
        vm.startPrank(_cognate);
        _storage.setQuorumThreshold(PROPOSAL_ID, 75, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        governance.isOpen(PROPOSAL_ID);
    }

    function testOpenVoteRequiresReady() public {
        vm.prank(_cognate);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        vm.expectRevert("Voting is not ready");
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
    }

    function testAddVoterIfOpen() public {
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.expectRevert("Vote not modifiable");
        vm.prank(_cognate);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testBurnVoterIfOpen() public {
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.expectRevert("Vote not modifiable");
        vm.prank(_cognate);
        _storage.burnVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testOwnerOpenVote() public {
        vm.startPrank(_cognate);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(owner);
        governance.openVote(PROPOSAL_ID);
    }

    function testOwnerEndVote() public {
        uint256 blockNumber = block.number;
        vm.startPrank(_cognate);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.roll(blockNumber + 2);
        vm.prank(owner);
        governance.endVote(PROPOSAL_ID);
    }

    function testDoubleOpenVote() public {
        vm.startPrank(_cognate);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.expectRevert("Already open");
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
    }

    function testEndVoteWhenNotOpen() public {
        vm.startPrank(_cognate);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.expectRevert("Voting is closed");
        vm.prank(supervisor);
        governance.endVote(PROPOSAL_ID);
    }

    function testOwnerCastVote() public {
        vm.startPrank(_cognate);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.expectRevert("Not a voter");
        vm.prank(owner);
        governance.voteFor(PROPOSAL_ID);
    }

    function testSupervisorCastVote() public {
        vm.startPrank(_cognate);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.expectRevert("Not a voter");
        vm.prank(supervisor);
        governance.voteFor(PROPOSAL_ID);
    }

    function testCastOneVoteNotOpen() public {
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.expectRevert("Voting is closed");
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testCastOneVoteFromAll() public {
        vm.startPrank(_cognate);
        _storage.registerVoterClassOpenVote(PROPOSAL_ID, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testCastOneVoteWithBurnedClass() public {
        vm.startPrank(_cognate);
        _storage.registerVoterClassOpenVote(PROPOSAL_ID, supervisor);
        _storage.burnVoterClass(PROPOSAL_ID, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.expectRevert("Not a voter");
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testCastVoteNotOpened() public {
        vm.prank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        vm.prank(_cognate);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        vm.expectRevert("Voting is closed");
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testCastTwoVote() public {
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
        vm.expectRevert("Already voted");
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testCastDoubleVoteOnTransferToken() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteForWithTokenId(PROPOSAL_ID, TOKEN_ID1);
        vm.prank(voter1);
        _erc721.transferFrom(voter1, voter2, TOKEN_ID1);
        vm.expectRevert("Already voted");
        vm.prank(voter2);
        governance.voteForWithTokenId(PROPOSAL_ID, TOKEN_ID1);
    }

    function testUndoRequiresOpen() public {
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.enableUndoVote(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.expectRevert("Voting is closed");
        vm.prank(voter1);
        governance.undoVote(PROPOSAL_ID);
    }

    function testVoterMayOnlyUndoPreviousVote() public {
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.enableUndoVote(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.expectRevert("No vote cast");
        vm.prank(voter1);
        governance.undoVote(PROPOSAL_ID);
    }

    function testUndoVoteOfPreviousOwner() public {
        vm.prank(_cognate);
        _storage.enableUndoVote(PROPOSAL_ID, supervisor);
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteForWithTokenId(PROPOSAL_ID, TOKEN_ID1);
        vm.prank(voter1);
        _erc721.transferFrom(voter1, voter2, TOKEN_ID1);
        vm.expectRevert("Not voter");
        vm.prank(voter2);
        governance.undoWithTokenId(PROPOSAL_ID, TOKEN_ID1);
    }

    function testUndoVoteNotDefaultEnabled() public {
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
        vm.expectRevert("Undo not enabled");
        vm.prank(voter1);
        governance.undoVote(PROPOSAL_ID);
    }

    function testSupervisorMayNotUndoVote() public {
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
        vm.expectRevert("Not voter");
        vm.prank(supervisor);
        governance.undoVote(PROPOSAL_ID);
    }

    function testOwnerMayNotUndoVote() public {
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
        vm.expectRevert("Not voter");
        vm.prank(owner);
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

        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(supervisor);
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

        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(supervisor);
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

        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(supervisor);
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

        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(supervisor);
        governance.endVote(PROPOSAL_ID);

        vm.expectRevert("Not enough participants");
        governance.getVoteSucceeded(PROPOSAL_ID);
    }

    function testGetVoteSucceededOnOpenMeasure() public {
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.expectRevert("Voting is not closed");
        governance.getVoteSucceeded(PROPOSAL_ID);
    }

    function testMeasureIsVeto() public {
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter2, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        uint256 blockNumber = block.number;
        governance.openVote(PROPOSAL_ID);
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
        vm.prank(voter2);
        governance.voteFor(PROPOSAL_ID);
        vm.prank(supervisor);
        governance.veto(PROPOSAL_ID);
        assertTrue(_storage.isVeto(PROPOSAL_ID));
        vm.roll(blockNumber + 2);
        vm.prank(supervisor);
        governance.endVote(PROPOSAL_ID);
        vm.expectRevert("Voting is not closed");
        governance.getVoteSucceeded(PROPOSAL_ID);
    }

    function testMeasureLateVeto() public {
        uint256 blockNumber = block.number;
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter2, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
        vm.prank(voter2);
        governance.voteFor(PROPOSAL_ID);
        vm.roll(blockNumber + 2);
        vm.prank(supervisor);
        governance.endVote(PROPOSAL_ID);
        vm.expectRevert("Voting is closed");
        vm.prank(supervisor);
        governance.veto(PROPOSAL_ID);
    }

    function testCastAgainstVoteNotOpen() public {
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.expectRevert("Voting is closed");
        vm.prank(voter1);
        governance.voteAgainst(PROPOSAL_ID);
    }

    function testAbstainFromVoteNotOpen() public {
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.expectRevert("Voting is closed");
        vm.prank(voter1);
        governance.abstainFromVote(PROPOSAL_ID);
    }

    function testVoteDelayPreventsVote(uint256 blockStep) public {
        vm.assume(blockStep >= 1 && blockStep < 100);
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, supervisor);
        _storage.setVoteDelay(PROPOSAL_ID, 100, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        uint256 startBlock = block.number;
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.roll(startBlock + blockStep);
        vm.expectRevert("Vote not active");
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testVoteAfterDuration(uint256 blockStep) public {
        vm.assume(blockStep > 10 && blockStep < UINT256MAX - block.number);
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, supervisor);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        uint256 startBlock = block.number;
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.roll(startBlock + blockStep);
        vm.expectRevert("Vote not active");
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testEndVoteWhileActive(uint256 blockStep) public {
        vm.assume(blockStep > 0 && blockStep < 16);
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, supervisor);
        _storage.setVoteDelay(PROPOSAL_ID, 5, supervisor);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        uint256 startBlock = block.number;
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.roll(startBlock + blockStep);
        vm.expectRevert("Voting remains active");
        vm.prank(supervisor);
        governance.endVote(PROPOSAL_ID);
    }

    function testEndVoteWhenFinished(uint256 blockStep) public {
        vm.assume(blockStep >= 16 && blockStep < UINT256MAX - block.number);
        vm.startPrank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, supervisor);
        _storage.setVoteDelay(PROPOSAL_ID, 5, supervisor);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        uint256 startBlock = block.number;
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.roll(startBlock + blockStep);
        vm.prank(supervisor);
        governance.endVote(PROPOSAL_ID);
        assertFalse(governance.isOpen(PROPOSAL_ID));
    }

    function testDirectStorageAccessToSupervisor() public {
        vm.expectRevert("Not permitted");
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, voter1, owner);
    }

    function testDirectStorageAccessToBurnSupervisor() public {
        vm.expectRevert("Not permitted");
        vm.prank(owner);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor, owner);
    }

    function testDirectStorageAccessToVoter() public {
        vm.prank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testDirectStorageAccessToVoterSupervisor() public {
        vm.prank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testDirectStorageAccessToBurnVoter() public {
        vm.prank(_cognate);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        vm.prank(_cognate);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.burnVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testDirectStorageAccessToBurnClass() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.burnVoterClass(PROPOSAL_ID, supervisor);
    }

    function testDirectStorageAccessToQuorum() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 0xffffffff, supervisor);
    }

    function testDirectStorageAccessToDuration() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 0xffffffff, supervisor);
    }

    function testDirectStorageAccessToDelay() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.setVoteDelay(PROPOSAL_ID, 0xffffffff, supervisor);
    }

    function testDirectStorageAccessToUndoVote() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.enableUndoVote(PROPOSAL_ID, supervisor);
    }

    function testDirectStorageAccessToReady() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
    }

    function testDirectStorageAccessToCastVote() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.expectRevert("Not permitted");
        vm.prank(voter1);
        _storage.voteForByShare(PROPOSAL_ID, voter1, TOKEN_ID1);
    }

    function testDirectStorageAccessToCastVoteAgainst() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.expectRevert("Not permitted");
        vm.prank(voter1);
        _storage.voteAgainstByShare(PROPOSAL_ID, voter1, TOKEN_ID1);
    }

    function testDirectStorageAccessToAbstain() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.expectRevert("Not permitted");
        vm.prank(voter1);
        _storage.abstainForShare(PROPOSAL_ID, voter1, TOKEN_ID1);
    }

    function testDirectStorageAccessToUndo() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.expectRevert("Not permitted");
        vm.prank(voter1);
        _storage.undoVoteById(PROPOSAL_ID, voter1, TOKEN_ID1);
    }

    function testDirectStorageAccessToVeto() public {
        vm.startPrank(owner, owner);
        governance.configureTokenVoteERC721(PROPOSAL_ID, 2, address(_erc721), 2);
        vm.stopPrank();
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.veto(PROPOSAL_ID, msg.sender);
    }

    function testSupportsInterfaceGovernance() public {
        bytes4 govId = type(Governance).interfaceId;
        assertTrue(governance.supportsInterface(govId));
    }

    function testSupportsInterfaceVoteStrategy() public {
        bytes4 vsId = type(VoteStrategy).interfaceId;
        assertTrue(governance.supportsInterface(vsId));
    }

    function testSupportsInterfaceERC165() public {
        bytes4 esId = type(ERC165).interfaceId;
        assertTrue(governance.supportsInterface(esId));
    }

    function mintTokens() private returns (IERC721) {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(voter1, TOKEN_ID1);
        merc721.mintTo(voter1, TOKEN_ID2);
        merc721.mintTo(voter1, TOKEN_ID3);
        _tokenIdList.push(TOKEN_ID1);
        _tokenIdList.push(TOKEN_ID2);
        _tokenIdList.push(TOKEN_ID3);
        return merc721;
    }
}

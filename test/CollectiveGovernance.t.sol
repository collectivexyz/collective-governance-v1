// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC721.sol";

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
    IERC721 private erc721;

    address public immutable owner = address(0x1);
    address public immutable supervisor = address(0x123);
    address public immutable nonSupervisor = address(0x123eee);
    address public immutable voter1 = address(0xfff1);
    address public immutable voter2 = address(0xfff2);
    address public immutable voter3 = address(0xfff3);
    uint256 public immutable NONE = 0;
    uint256 public immutable PROPOSAL_ID = 1;

    address public immutable someoneElse = address(0x123);
    address public immutable voter = address(0xffee);
    address public immutable nonvoter = address(0xffff);
    uint256 public immutable TOKEN_ID = 77;
    uint32 private version;
    uint256 private pid;

    function setUp() public {
        vm.clearMockedCalls();
        governance = new CollectiveGovernance();
        _storage = Storage(governance.getStorageAddress());
        version = governance.version();
        erc721 = new MockERC721(voter, TOKEN_ID);
        vm.prank(owner);
        pid = governance.propose();
        vm.prank(address(governance));
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

    function testConfigure() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();
        assertTrue(governance.isOpen(PROPOSAL_ID));
        assertEq(_storage.quorumRequired(PROPOSAL_ID), 2);
        assertTrue(governance.isOpen(PROPOSAL_ID));
    }

    function testCastSimpleVote() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();
        vm.prank(voter);
        governance.voteFor(PROPOSAL_ID);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
    }

    function testCastSimpleVoteWhileActive() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 10);
        vm.stopPrank();
        vm.prank(voter);
        vm.roll(block.number + 2);
        governance.voteFor(PROPOSAL_ID);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
    }

    function testFailNonVoter() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();
        vm.prank(nonvoter);
        governance.voteFor(PROPOSAL_ID);
    }

    function testVoteAgainst() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();
        vm.prank(voter);
        governance.voteAgainst(PROPOSAL_ID);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 1);
    }

    function testFailVoteAgainstNonVoter() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();
        vm.prank(nonvoter);
        governance.voteAgainst(PROPOSAL_ID);
    }

    function testAbstain() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();
        vm.prank(voter);
        governance.abstainFromVote(PROPOSAL_ID);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 1);
    }

    function testFailAbstentionNonVoter() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();
        vm.prank(nonvoter);
        governance.abstainFromVote(PROPOSAL_ID);
    }

    function testOpenVote() public {
        vm.startPrank(address(governance));
        _storage.setQuorumThreshold(PROPOSAL_ID, 75, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        governance.isOpen(PROPOSAL_ID);
    }

    function testFailOpenVoteRequiresReady() public {
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, address(governance));
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
    }

    function testFailAddVoterIfOpen() public {
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, address(governance));
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID, address(governance));
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testFailBurnVoterIfOpen() public {
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(supervisor);
        _storage.burnVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testFailOwnerOpenVote() public {
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        governance.openVote(PROPOSAL_ID);
    }

    function testFailOwnerEndVote() public {
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(owner);
        governance.endVote(PROPOSAL_ID);
    }

    function testFailDoubleOpenVote() public {
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
    }

    function testFailendVoteWhenNotOpen() public {
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        governance.endVote(PROPOSAL_ID);
    }

    function testFailOwnerCastVote() public {
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(owner);
        governance.voteFor(PROPOSAL_ID);
    }

    function testFailSupervisorCastVote() public {
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(supervisor);
        governance.voteFor(PROPOSAL_ID);
    }

    function testFailCastOneVoteNotOpen() public {
        vm.startPrank(address(governance));
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testCastOneVoteFromAll() public {
        address strategy = address(governance);
        vm.startPrank(strategy);
        _storage.registerVoterClassOpenVote(PROPOSAL_ID, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testFailCastOneVoteWithBurnedClass() public {
        address strategy = address(governance);
        vm.startPrank(strategy);
        _storage.registerVoterClassOpenVote(PROPOSAL_ID, supervisor);
        _storage.burnVoterClass(PROPOSAL_ID, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testFailCastVoteNotOpened() public {
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testFailCastTwoVote() public {
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testFailUndoRequiresOpen() public {
        vm.startPrank(supervisor);
        _storage.enableUndoVote(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(voter1);
        governance.undoVote(PROPOSAL_ID);
    }

    function testFailVoterMayOnlyUndoPreviousVote() public {
        vm.startPrank(supervisor);
        _storage.enableUndoVote(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.expectRevert("Voter required");
        vm.prank(owner);
        governance.undoVote(PROPOSAL_ID);
    }

    function testFailUndoVoteNotDefaultEnabled() public {
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.expectRevert();
        vm.prank(owner);
        governance.undoVote(PROPOSAL_ID);
    }

    function testFailSupervisorMayNotUndoVote() public {
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
        vm.prank(voter1);
        governance.undoVote(PROPOSAL_ID);
    }

    function testFailOwnerMayNotUndoVote() public {
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
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

    function testFailMeasureNoQuorum() public {
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

        governance.getVoteSucceeded(PROPOSAL_ID);
    }

    function testFailGetVoteSucceededOnOpenMeasure() public {
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        governance.openVote(PROPOSAL_ID);
        governance.getVoteSucceeded(PROPOSAL_ID);
    }

    function testFailMeasureIsVeto() public {
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter2, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
        vm.prank(voter2);
        governance.voteFor(PROPOSAL_ID);
        vm.prank(supervisor);
        governance.veto(PROPOSAL_ID);
        assertTrue(_storage.isVeto(PROPOSAL_ID));
        vm.prank(supervisor);
        governance.endVote(PROPOSAL_ID);
        governance.getVoteSucceeded(PROPOSAL_ID);
    }

    function testFailMeasureLateVeto() public {
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter2, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
        vm.prank(voter2);
        governance.voteFor(PROPOSAL_ID);
        vm.prank(supervisor);
        governance.endVote(PROPOSAL_ID);
        vm.prank(supervisor);
        governance.veto(PROPOSAL_ID);
    }

    function testFailCastAgainstVoteNotOpen() public {
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(voter1);
        governance.voteAgainst(PROPOSAL_ID);
    }

    function testFailAbstainFromVoteNotOpen() public {
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.stopPrank();
        vm.prank(voter1);
        governance.abstainFromVote(PROPOSAL_ID);
    }

    function testFailVoteDelayPreventsVote(uint256 blockStep) public {
        vm.assume(blockStep >= 1 && blockStep < 100);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, supervisor);
        _storage.setVoteDelay(PROPOSAL_ID, 100, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        uint256 startBlock = block.number;
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        vm.roll(startBlock + blockStep);
        vm.expectRevert("Vote not ready");
        governance.voteFor(PROPOSAL_ID);
    }

    function testFailVoteAfterDuration(uint256 blockStep) public {
        vm.assume(blockStep > 10 && blockStep < UINT256MAX - block.number);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, supervisor);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        uint256 startBlock = block.number;
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.roll(startBlock + blockStep);
        vm.prank(voter1);
        governance.voteFor(PROPOSAL_ID);
    }

    function testFailEndVoteWhileActive(uint256 blockStep) public {
        vm.assume(blockStep > 0 && blockStep < 16);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, supervisor);
        _storage.setVoteDelay(PROPOSAL_ID, 5, supervisor);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        uint256 startBlock = block.number;
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.roll(startBlock + blockStep);
        vm.expectRevert("Vote not active");
        governance.endVote(PROPOSAL_ID);
    }

    function testEndVoteWhenFinished(uint256 blockStep) public {
        vm.assume(blockStep >= 16 && blockStep < UINT256MAX - block.number);
        address strategy = address(governance);
        vm.startPrank(strategy);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, supervisor);
        _storage.setVoteDelay(PROPOSAL_ID, 5, supervisor);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        uint256 startBlock = block.number;
        governance.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.roll(startBlock + blockStep);
        vm.prank(supervisor);
        governance.endVote(PROPOSAL_ID);
        assertFalse(governance.isOpen(PROPOSAL_ID));
    }

    function testFailDirectStorageAccessToSupervisor() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, voter1, owner);
    }

    function testFailDirectStorageAccessToBurnSupervisor() public {
        vm.prank(address(governance));
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.prank(owner);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor, owner);
    }

    function testFailDirectStorageAccessToVoter() public {
        vm.prank(owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testFailDirectStorageAccessToVoterSupervisor() public {
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testFailDirectStorageAccessToBurnVoter() public {
        vm.prank(address(governance));
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.burnVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testFailDirectStorageAccessToBurnClass() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();

        _storage.burnVoterClass(PROPOSAL_ID, supervisor);
    }

    function testFailDirectStorageAccessToQuorum() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();
        _storage.setQuorumThreshold(PROPOSAL_ID, 0xffffffff, supervisor);
    }

    function testFailDirectStorageAccessToDuration() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();

        _storage.setRequiredVoteDuration(PROPOSAL_ID, 0xffffffff, supervisor);
    }

    function testFailDirectStorageAccessToDelay() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();

        _storage.setVoteDelay(PROPOSAL_ID, 0xffffffff, supervisor);
    }

    function testFailDirectStorageAccessToUndoVote() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();

        _storage.enableUndoVote(PROPOSAL_ID, supervisor);
    }

    function testFailDirectStorageAccessToReady() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();

        _storage.makeReady(PROPOSAL_ID, supervisor);
    }

    function testFailDirectStorageAccessToCastVote() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();
        _storage.voteForByShare(PROPOSAL_ID, voter1, uint160(voter1), 1);
    }

    function testFailDirectStorageAccessToCastVoteAgainst() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();

        _storage.voteAgainstByShare(PROPOSAL_ID, voter1, uint160(voter1), 1);
    }

    function testFailDirectStorageAccessToAbstain() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();
        _storage.abstainForShare(PROPOSAL_ID, voter1, uint160(voter1), 1);
    }

    function testFailDirectStorageAccessToUndo() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();
        _storage.undoVoteById(PROPOSAL_ID, voter1, uint160(voter1));
    }

    function testFailDirectStorageAccessToVeto() public {
        vm.startPrank(owner, owner);
        governance.configure(PROPOSAL_ID, 2, address(erc721), 2);
        vm.stopPrank();
        _storage.veto(PROPOSAL_ID, msg.sender);
    }
}

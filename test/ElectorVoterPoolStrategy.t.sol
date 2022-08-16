// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/Storage.sol";
import "../contracts/GovernanceStorage.sol";
import "../contracts/ElectorVoterPoolStrategy.sol";
import "../contracts/VoterClass.sol";
import "./MockERC721.sol";

contract ElectorVoterPoolTest is Test {
    uint256 public constant UINT256MAX = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    Storage private _storage;
    VoteStrategy private elector;

    address public immutable owner = address(0x1);
    address public immutable supervisor = address(0x123);
    address public immutable nonSupervisor = address(0x123eee);
    address public immutable voter1 = address(0xfff1);
    address public immutable voter2 = address(0xfff2);
    address public immutable voter3 = address(0xfff3);
    uint256 public immutable NONE = 0;
    uint256 public immutable PROPOSAL_ID = 1;

    function setUp() public {
        vm.clearMockedCalls();
        _storage = new GovernanceStorage();
        elector = new ElectorVoterPoolStrategy(_storage);
        vm.startPrank(owner);
        address electorAddress = address(elector);
        _storage._initializeProposal(electorAddress);
        vm.stopPrank();
    }

    function testOpenVote() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 75);
        _storage.makeReady(PROPOSAL_ID);
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        elector.isOpen(PROPOSAL_ID);
    }

    function testFailOpenVoteRequiresReady() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        elector.openVote(PROPOSAL_ID);
    }

    function testFailAddVoterIfOpen() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVote(PROPOSAL_ID);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
    }

    function testFailBurnVoterIfOpen() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVote(PROPOSAL_ID);
        vm.prank(supervisor);
        _storage.burnVoter(PROPOSAL_ID, voter1);
    }

    function testFailOwnerOpenVote() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        elector.openVote(PROPOSAL_ID);
    }

    function testFailOwnerEndVote() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVote(PROPOSAL_ID);
        vm.prank(owner);
        elector.endVote(PROPOSAL_ID);
    }

    function testFailDoubleOpenVote() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVote(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVote(PROPOSAL_ID);
    }

    function testFailendVoteWhenNotOpen() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.endVote(PROPOSAL_ID);
    }

    function testFailOwnerCastVote() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVote(PROPOSAL_ID);
        elector.voteFor(PROPOSAL_ID);
    }

    function testFailSupervisorCastVote() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVote(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.voteFor(PROPOSAL_ID);
    }

    function testFailCastOneVoteNotOpen() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
    }

    function testFailCastOneVoteUpdatedStrategy() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        VoteStrategy strategy = new EVP2(_storage);
        vm.prank(voter1);
        strategy.voteFor(PROPOSAL_ID);
    }

    function testCastOneVoteFromAll() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoterClassOpenVote(PROPOSAL_ID);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        assertEq(_storage.totalParticipation(PROPOSAL_ID), 1);
    }

    function testFailCastOneVoteWithBurnedClass() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoterClassOpenVote(PROPOSAL_ID);
        _storage.burnVoterClass(PROPOSAL_ID);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
    }

    function testFailCastVoteNotOpened() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
    }

    function testFailCastTwoVote() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
    }

    function testFailUndoStrategyUpgrade() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.enableUndoVote(PROPOSAL_ID);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        _storage._castVoteFor(PROPOSAL_ID);
        assertEq(_storage.totalParticipation(PROPOSAL_ID), 1);
        vm.prank(voter1);
        VoteStrategy strategy = new EVP2(_storage);
        strategy.undoVote(PROPOSAL_ID);
        assertEq(_storage.totalParticipation(PROPOSAL_ID), NONE);
    }

    function testFailUndoRequiresOpen() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.enableUndoVote(PROPOSAL_ID);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.undoVote(PROPOSAL_ID);
    }

    function testVoterMayOnlyUndoPreviousVote() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.enableUndoVote(PROPOSAL_ID);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.expectRevert("Voter required");
        elector.undoVote(PROPOSAL_ID);
    }

    function testFailUndoVoteNotDefaultEnabled() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.expectRevert();
        elector.undoVote(PROPOSAL_ID);
    }

    function testFailSupervisorMayNotUndoVote() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(supervisor);
        elector.openVote(PROPOSAL_ID);
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.undoVote(PROPOSAL_ID);
    }

    function testFailOwnerMayNotUndoVote() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(owner);
        elector.undoVote(PROPOSAL_ID);
    }

    function testMeasurePassed() public {
        vm.roll(10);
        bytes memory code = address(_storage).code;

        address storageMock = address(0x99991111);
        VoteStrategy strategy = new ElectorVoterPoolStrategy(Storage(storageMock));
        vm.etch(storageMock, code);
        uint256 requiredParticipation = 0;
        vm.mockCall(
            storageMock,
            abi.encodeWithSelector(Storage.requiredParticipation.selector),
            abi.encode(requiredParticipation)
        );
        uint256 forVotes = 201;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.forVotes.selector), abi.encode(forVotes));
        uint256 totalParticipation = forVotes;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.totalParticipation.selector), abi.encode(totalParticipation));
        uint256 quorumRequired = 200;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.quorumRequired.selector), abi.encode(quorumRequired));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage._maxPassThreshold.selector), abi.encode(0xffffffff));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.startBlock.selector), abi.encode(block.number - 2));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.endBlock.selector), abi.encode(block.number - 1));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isReady.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isVeto.selector), abi.encode(false));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isSupervisor.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage._validOrRevert.selector), abi.encode(PROPOSAL_ID));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.voteStrategy.selector), abi.encode(address(strategy)));

        vm.prank(supervisor);
        strategy.openVote(PROPOSAL_ID);
        vm.prank(supervisor);
        strategy.endVote(PROPOSAL_ID);

        assertTrue(strategy.getVoteSucceeded(PROPOSAL_ID));
    }

    function testMeasureFailNoQuorum() public {
        vm.roll(10);
        bytes memory code = address(_storage).code;

        address storageMock = address(0x99991111);
        VoteStrategy strategy = new ElectorVoterPoolStrategy(Storage(storageMock));
        vm.etch(storageMock, code);
        uint256 requiredParticipation = 0;
        vm.mockCall(
            storageMock,
            abi.encodeWithSelector(Storage.requiredParticipation.selector),
            abi.encode(requiredParticipation)
        );
        uint256 forVotes = 199;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.forVotes.selector), abi.encode(forVotes));
        uint256 totalParticipation = forVotes;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.totalParticipation.selector), abi.encode(totalParticipation));
        uint256 quorumRequired = 200;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.quorumRequired.selector), abi.encode(quorumRequired));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.startBlock.selector), abi.encode(block.number - 2));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.endBlock.selector), abi.encode(block.number - 1));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage._maxPassThreshold.selector), abi.encode(0xffffffff));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isReady.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isVeto.selector), abi.encode(false));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isSupervisor.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage._validOrRevert.selector), abi.encode(PROPOSAL_ID));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.voteStrategy.selector), abi.encode(address(strategy)));

        vm.prank(supervisor);
        strategy.openVote(PROPOSAL_ID);
        vm.prank(supervisor);
        strategy.endVote(PROPOSAL_ID);

        assertFalse(strategy.getVoteSucceeded(PROPOSAL_ID));
    }

    function testFailMeasureFailRequiredParticipation() public {
        vm.roll(10);
        bytes memory code = address(_storage).code;

        address storageMock = address(0x99991111);
        VoteStrategy strategy = new ElectorVoterPoolStrategy(Storage(storageMock));
        vm.etch(storageMock, code);
        uint256 requiredParticipation = 1000;
        vm.mockCall(
            storageMock,
            abi.encodeWithSelector(Storage.requiredParticipation.selector),
            abi.encode(requiredParticipation)
        );
        uint256 forVotes = 199;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.forVotes.selector), abi.encode(forVotes));
        uint256 totalParticipation = forVotes;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.totalParticipation.selector), abi.encode(totalParticipation));
        uint256 quorumRequired = 200;
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.quorumRequired.selector), abi.encode(quorumRequired));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.quorumRequired.selector), abi.encode(quorumRequired));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.startBlock.selector), abi.encode(block.number - 2));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.endBlock.selector), abi.encode(block.number - 1));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage._maxPassThreshold.selector), abi.encode(0xffffffff));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isReady.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isVeto.selector), abi.encode(false));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.isSupervisor.selector), abi.encode(true));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage._validOrRevert.selector), abi.encode(PROPOSAL_ID));
        vm.mockCall(storageMock, abi.encodeWithSelector(Storage.voteStrategy.selector), abi.encode(address(strategy)));

        vm.prank(supervisor);
        strategy.openVote(PROPOSAL_ID);
        vm.prank(supervisor);
        strategy.endVote(PROPOSAL_ID);
        strategy.getVoteSucceeded(PROPOSAL_ID);
    }

    function testFailGetVoteSucceededOnOpenMeasure() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.openVote(PROPOSAL_ID);
        elector.getVoteSucceeded(PROPOSAL_ID);
    }

    function testFailMeasureIsVeto() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.registerVoter(PROPOSAL_ID, voter2);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(voter2);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.veto(PROPOSAL_ID);
        assertTrue(_storage.isVeto(PROPOSAL_ID));
        vm.prank(supervisor);
        elector.endVote(PROPOSAL_ID);
        elector.getVoteSucceeded(PROPOSAL_ID);
    }

    function testFailMeasureLateVeto() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.registerVoter(PROPOSAL_ID, voter2);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(voter2);
        elector.voteFor(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.endVote(PROPOSAL_ID);
        vm.prank(supervisor);
        elector.veto(PROPOSAL_ID);
    }

    function testFailCastAgainstVoteNotOpen() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.voteAgainst(PROPOSAL_ID);
    }

    function testFailCastAgainstVoteUpdatedStrategy() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        VoteStrategy strategy = new EVP2(_storage);
        vm.prank(voter1);
        strategy.voteAgainst(PROPOSAL_ID);
    }

    function testFailAbstainFromVoteInvalidStrategy() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        VoteStrategy strategy = new EVP2(_storage);
        vm.prank(voter1);
        strategy.abstainFromVote(PROPOSAL_ID);
        assertEq(_storage.forVotes(PROPOSAL_ID), 0);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 0);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 1);
        assertEq(_storage.totalParticipation(PROPOSAL_ID), 1);
    }

    function testFailAbstainFromVoteNotOpen() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        elector.abstainFromVote(PROPOSAL_ID);
    }

    function testFailVoteDelayPreventsVote(uint256 blockStep) public {
        vm.assume(blockStep >= 1 && blockStep < 100);
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1);
        _storage.setVoteDelay(PROPOSAL_ID, 100);
        _storage.makeReady(PROPOSAL_ID);
        uint256 startBlock = block.number;
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        vm.roll(startBlock + blockStep);
        vm.expectRevert("Vote not ready");
        elector.voteFor(PROPOSAL_ID);
    }

    function testFailVoteAfterDuration(uint256 blockStep) public {
        vm.assume(blockStep > 10 && blockStep < UINT256MAX - block.number);
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10);
        _storage.makeReady(PROPOSAL_ID);
        uint256 startBlock = block.number;
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(voter1);
        vm.roll(startBlock + blockStep);
        elector.voteFor(PROPOSAL_ID);
    }

    function testFailEndVoteWhileActive(uint256 blockStep) public {
        vm.assume(blockStep > 0 && blockStep < 16);
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1);
        _storage.setVoteDelay(PROPOSAL_ID, 5);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10);
        _storage.makeReady(PROPOSAL_ID);
        uint256 startBlock = block.number;
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.roll(startBlock + blockStep);
        vm.expectRevert("Vote not active");
        elector.endVote(PROPOSAL_ID);
    }

    function testEndVoteWhenFinished(uint256 blockStep) public {
        vm.assume(blockStep >= 16 && blockStep < UINT256MAX - block.number);
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1);
        _storage.setVoteDelay(PROPOSAL_ID, 5);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10);
        _storage.makeReady(PROPOSAL_ID);
        uint256 startBlock = block.number;
        elector.openVote(PROPOSAL_ID);
        vm.stopPrank();
        vm.roll(startBlock + blockStep);
        vm.prank(supervisor);
        elector.endVote(PROPOSAL_ID);
        assertFalse(elector.isOpen(PROPOSAL_ID));
    }
}

contract EVP2 is ElectorVoterPoolStrategy {
    constructor(Storage _storage) ElectorVoterPoolStrategy(_storage) {}

    function version() public pure virtual override returns (uint32) {
        return 0xffffffff;
    }
}

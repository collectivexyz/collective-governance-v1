// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "forge-std/Test.sol";
import "../contracts/GovernanceStorage.sol";
import "../contracts/CollectiveGovernance.sol";
import "../contracts/VoteStrategy.sol";
import "./MockERC721.sol";

contract GovernanceStorageTest is Test {
    using stdStorage for StdStorage;

    address public immutable owner = address(0x155);
    address public immutable supervisor = address(0x123);
    address public immutable nonSupervisor = address(0x123eee);
    address public immutable voter1 = address(0xfff1);
    address public immutable voter2 = address(0xfff2);
    address public immutable voter3 = address(0xfff3);
    uint256 public immutable BLOCK = 0x300;
    uint256 public immutable NONE = 0;
    uint256 public immutable PROPOSAL_ID = 1;

    Storage private _storage;
    VoteStrategy private _strategy;
    address private _strategyAddress;

    function setUp() public {
        _storage = new GovernanceStorage();
        _strategy = new CollectiveGovernance();
        _strategyAddress = address(_strategy);
        vm.startPrank(owner);
        _storage._initializeProposal(_strategyAddress);
        vm.stopPrank();
    }

    function testVotesCastZero() public {
        assertEq(_storage.forVotes(PROPOSAL_ID), NONE);
        assertEq(_storage.againstVotes(PROPOSAL_ID), NONE);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), NONE);
        assertEq(_storage.quorum(PROPOSAL_ID), NONE);
    }

    function testIsReady() public {
        assertFalse(_storage.isReady(PROPOSAL_ID));
    }

    function testGetSender() public {
        address sender = _storage.getSender(PROPOSAL_ID);
        assertEq(sender, owner);
    }

    function testFailOnlyOneOwnerCanRegisterSupervisor() public {
        vm.prank(address(0));
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
    }

    function testRegisterSupervisor() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        assertTrue(_storage.isSupervisor(PROPOSAL_ID, supervisor));
    }

    function testFailRegisterSupervisorBadProposal() public {
        vm.prank(owner);
        _storage.registerSupervisor(0, supervisor);
    }

    function testFailRegisterSupervisorIfOpen() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        _storage.registerSupervisor(PROPOSAL_ID, nonSupervisor);
    }

    function testRegisterAndBurnSupervisor() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(owner);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor);
        assertFalse(_storage.isSupervisor(PROPOSAL_ID, supervisor));
    }

    function testFailReadyByBurnedSupervisor() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(owner);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
    }

    function testFailVoterByBurnedSupervisor() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(owner);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
    }

    function testFailBurnVoterByBurnedSupervisor() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(owner);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.burnVoter(PROPOSAL_ID, voter1);
    }

    function testSupervisorRegisterVoter() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        assertTrue(_storage.isVoter(PROPOSAL_ID, voter1));
    }

    function testFailSupervisorRegisterVoterIfReady() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
    }

    function testSupervisorRegisterMoreThanOneVoter() public {
        address[] memory voter = new address[](2);
        voter[0] = voter1;
        voter[1] = voter2;

        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);

        _storage.registerVoters(PROPOSAL_ID, voter);
        assertTrue(_storage.isVoter(PROPOSAL_ID, voter1));
        assertTrue(_storage.isVoter(PROPOSAL_ID, voter2));
    }

    function testSupervisorRegisterThenBurnVoter() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(supervisor);
        _storage.burnVoter(PROPOSAL_ID, voter1);
        assertFalse(_storage.isVoter(PROPOSAL_ID, voter1));
    }

    function testFailAddVoterIfReady() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
    }

    function testFailBurnVoterIfOpen() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        _storage.burnVoter(PROPOSAL_ID, voter1);
    }

    function testFailOwnerRegisterVoter() public {
        vm.prank(owner);
        _storage.registerVoter(PROPOSAL_ID, voter1);
    }

    function testFailOwnerBurnVoter() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(owner);
        _storage.burnVoter(PROPOSAL_ID, voter1);
    }

    function testSetQuorumThreshold() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 100);
        assertEq(_storage.quorumRequired(PROPOSAL_ID), 100);
    }

    function testFailSetQuorumThresholdIfReady() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 100);
        assertEq(_storage.quorumRequired(PROPOSAL_ID), 100);
    }

    function testSetVoteDelay() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.setVoteDelay(PROPOSAL_ID, 100);
        assertEq(_storage.voteDelay(PROPOSAL_ID), 100);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        assertEq(_storage.startBlock(PROPOSAL_ID), block.number + 100);
    }

    function testFailSetVoteDelayRequiresSupervisor() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        _storage.setVoteDelay(PROPOSAL_ID, 100);
    }

    function testFailSetVoteDelayIfReady() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        _storage.setVoteDelay(PROPOSAL_ID, 2);
    }

    function testSetMinimumVoteDuration() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10);
        assertEq(_storage.voteDuration(PROPOSAL_ID), 10);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        assertEq(_storage.endBlock(PROPOSAL_ID), block.number + 10);
    }

    function testFailSetMinimumVoteDurationNonZero() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 0);
    }

    function testFailSetMinimumVoteDurationIfReady() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 1);
    }

    function testFailSetMinimumVoteDurationRequiredSupervisor() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 0);
    }

    function testMakeReady() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        assertTrue(_storage.isReady(PROPOSAL_ID));
    }

    function testFailMakeReadyDoubleCall() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID);
    }

    function testFailMakeReadyRequireSupervisor() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        _storage.makeReady(PROPOSAL_ID);
    }

    function testVeto() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        assertFalse(_storage.isVeto(PROPOSAL_ID));
        vm.prank(supervisor);
        _storage._veto(PROPOSAL_ID);
        assertTrue(_storage.isVeto(PROPOSAL_ID));
    }

    function testFailOwnerMayNotVeto() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(owner);
        _storage._veto(PROPOSAL_ID);
    }

    function testFailVoterMayNotVeto() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(voter1);
        _storage._veto(PROPOSAL_ID);
    }

    function testCurrentStrategy() public {
        assertEq(address(_storage.voteStrategy(PROPOSAL_ID)), address(_strategy));
    }

    function testFailRevertInvalidProposal(uint256 _proposalId) public {
        vm.assume(_proposalId > PROPOSAL_ID);
        _storage._validOrRevert(_proposalId);
    }

    function testAbstainFromVote() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_strategyAddress);
        _storage._abstainFromVote(PROPOSAL_ID, voter1);
        assertEq(_storage.forVotes(PROPOSAL_ID), 0);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 0);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 1);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testCastAgainstVote() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_strategyAddress);
        _storage._castVoteAgainst(PROPOSAL_ID, voter1);
        assertEq(_storage.forVotes(PROPOSAL_ID), 0);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 1);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 0);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testCastOneVote() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_strategyAddress);
        _storage._castVoteFor(PROPOSAL_ID, voter1);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testQuorumAllThree() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.registerVoter(PROPOSAL_ID, voter2);
        _storage.registerVoter(PROPOSAL_ID, voter3);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_strategyAddress);
        _storage._castVoteFor(PROPOSAL_ID, voter1);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
        vm.prank(_strategyAddress);
        _storage._castVoteAgainst(PROPOSAL_ID, voter2);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 1);
        vm.prank(_strategyAddress);
        _storage._abstainFromVote(PROPOSAL_ID, voter3);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 1);
        assertEq(_storage.quorum(PROPOSAL_ID), 3);
    }

    function testCastOneVoteFromAll() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoterClassOpenVote(PROPOSAL_ID);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_strategyAddress);
        _storage._castVoteFor(PROPOSAL_ID, voter1);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testCastVoteFromERC721() public {
        uint256 tokenId = 0x71;
        IERC721 token = new MockERC721(voter2, tokenId);
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoterClassERC721(PROPOSAL_ID, address(token));
        _storage.setQuorumThreshold(PROPOSAL_ID, 1);
        _storage.makeReady(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_strategyAddress);
        _storage._castVoteFor(PROPOSAL_ID, voter2);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 0);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 0);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testPermittedAfterObservingVoteDelay() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1);
        _storage.setVoteDelay(PROPOSAL_ID, 100);
        _storage.makeReady(PROPOSAL_ID);
        uint256 startBlock = block.number;
        vm.stopPrank();
        vm.roll(startBlock + 100);
        vm.prank(_strategyAddress);
        _storage._castVoteFor(PROPOSAL_ID, voter1);
        assertEq(1, _storage.forVotes(PROPOSAL_ID));
    }

    function testVoterMayChangeTheirMind() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.startPrank(supervisor);
        _storage.enableUndoVote(PROPOSAL_ID);
        _storage.registerVoter(PROPOSAL_ID, voter1);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2);
        _storage.makeReady(PROPOSAL_ID);
        vm.stopPrank();
        vm.prank(_strategyAddress);
        _storage._castVoteFor(PROPOSAL_ID, voter1);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
        vm.prank(_strategyAddress);
        _storage._castVoteUndo(PROPOSAL_ID, voter1);
        assertEq(_storage.quorum(PROPOSAL_ID), NONE);
    }

    function testName() public {
        assertEq(_storage.name(), "collective.xyz governance storage");
    }

    function testVersion() public {
        assertEq(_storage.version(), 1);
    }
}

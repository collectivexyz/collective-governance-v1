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
    address public immutable cognate = address(this);
    address public immutable supervisor = address(0x123);
    address public immutable nonSupervisor = address(0x123eee);
    address public immutable voter1 = address(0xfff1);
    address public immutable voter2 = address(0xfff2);
    address public immutable voter3 = address(0xfff3);
    address public immutable nobody = address(0x0);
    uint256 public immutable BLOCK = 0x300;
    uint256 public immutable NONE = 0;
    uint256 public immutable PROPOSAL_ID = 1;

    Storage private _storage;
    VoteStrategy private _strategy;
    address private _strategyAddress;

    function setUp() public {
        _storage = new GovernanceStorage(address(this));
        _storage._initializeProposal(owner);
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
        vm.prank(nobody);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, nobody);
    }

    function testRegisterSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        assertTrue(_storage.isSupervisor(PROPOSAL_ID, supervisor));
    }

    function testFailOwnerRegisterSupervisor() public {
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
    }

    function testFailRegisterSupervisorBadProposal() public {
        _storage.registerSupervisor(0, supervisor, owner);
    }

    function testFailRegisterSupervisorIfOpen() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.registerSupervisor(PROPOSAL_ID, nonSupervisor, supervisor);
    }

    function testRegisterAndBurnSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor, owner);
        assertFalse(_storage.isSupervisor(PROPOSAL_ID, supervisor));
    }

    function testFailRegisterAndOwnerBurnSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.prank(owner);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor, owner);
    }

    function testFailReadyByBurnedSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, supervisor);
    }

    function testFailVoterByBurnedSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testFailBurnVoterByBurnedSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.burnVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testSupervisorRegisterVoter() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        assertTrue(_storage.isVoter(PROPOSAL_ID, voter1));
    }

    function testFailSupervisorDirectlyRegisterVoter() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testFailSupervisorRegisterVoterIfReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testSupervisorRegisterMoreThanOneVoter() public {
        address[] memory voter = new address[](2);
        voter[0] = voter1;
        voter[1] = voter2;

        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoters(PROPOSAL_ID, voter, supervisor);
        assertTrue(_storage.isVoter(PROPOSAL_ID, voter1));
        assertTrue(_storage.isVoter(PROPOSAL_ID, voter2));
    }

    function testFailSupervisorDirectlyRegisterMoreThanOneVoter() public {
        address[] memory voter = new address[](2);
        voter[0] = voter1;
        voter[1] = voter2;
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.prank(supervisor);
        _storage.registerVoters(PROPOSAL_ID, voter, supervisor);
    }

    function testSupervisorRegisterThenBurnVoter() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.burnVoter(PROPOSAL_ID, voter1, supervisor);
        assertFalse(_storage.isVoter(PROPOSAL_ID, voter1));
    }

    function testFailSupervisorRegisterDirectlyThenBurnVoter() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        vm.prank(supervisor);
        _storage.burnVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testFailAddVoterIfReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testFailBurnVoterIfOpen() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.burnVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testFailOwnerRegisterVoter() public {
        _storage.registerVoter(PROPOSAL_ID, voter1, owner);
    }

    function testFailOwnerBurnVoter() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.burnVoter(PROPOSAL_ID, voter1, owner);
    }

    function testFailOwnerHackBurnVoter() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        vm.prank(owner);
        _storage.burnVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testSetQuorumThreshold() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.setQuorumThreshold(PROPOSAL_ID, 100, supervisor);
        assertEq(_storage.quorumRequired(PROPOSAL_ID), 100);
    }

    function testFailSetQuorumThresholdDirect() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 100, supervisor);
    }

    function testFailSetQuorumThresholdIfReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 100, supervisor);
        assertEq(_storage.quorumRequired(PROPOSAL_ID), 100);
    }

    function testSetVoteDelay() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.setVoteDelay(PROPOSAL_ID, 100, supervisor);
        assertEq(_storage.voteDelay(PROPOSAL_ID), 100);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        assertEq(_storage.startBlock(PROPOSAL_ID), block.number + 100);
    }

    function testFailSetVoteDelay() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.prank(supervisor);
        _storage.setVoteDelay(PROPOSAL_ID, 100, supervisor);
    }

    function testFailSetVoteDelayRequiresSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.setVoteDelay(PROPOSAL_ID, 100, cognate);
    }

    function testFailSetVoteDelayIfReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.setVoteDelay(PROPOSAL_ID, 2, supervisor);
    }

    function testSetMinimumVoteDuration() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10, supervisor);
        assertEq(_storage.voteDuration(PROPOSAL_ID), 10);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        assertEq(_storage.endBlock(PROPOSAL_ID), block.number + 10);
    }

    function testFailSetMinimumVoteDurationDirect() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.prank(supervisor);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10, supervisor);
    }

    function testFailSetMinimumVoteDurationNonZero() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 0, supervisor);
    }

    function testFailSetMinimumVoteDurationIfReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 1, supervisor);
    }

    function testFailSetMinimumVoteDurationRequiredSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 0, cognate);
    }

    function testMakeReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        assertTrue(_storage.isReady(PROPOSAL_ID));
    }

    function testFailMakeReadyDirect() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
    }

    function testFailMakeReadyDoubleCall() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
    }

    function testFailMakeReadyRequireSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, cognate);
    }

    function testVeto() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        assertFalse(_storage.isVeto(PROPOSAL_ID));
        _storage._veto(PROPOSAL_ID, supervisor);
        assertTrue(_storage.isVeto(PROPOSAL_ID));
    }

    function testFailVetoDirect() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.prank(supervisor);
        _storage._veto(PROPOSAL_ID, supervisor);
    }

    function testFailOwnerMayNotVeto() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage._veto(PROPOSAL_ID, owner);
    }

    function testFailVoterMayNotVeto() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage._veto(PROPOSAL_ID, voter1);
    }

    function testFailRevertInvalidProposal(uint256 _proposalId) public {
        vm.assume(_proposalId > PROPOSAL_ID);
        _storage._validOrRevert(_proposalId);
    }

    function testAbstainFromVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage._abstainFromVote(PROPOSAL_ID, voter1);
        assertEq(_storage.forVotes(PROPOSAL_ID), 0);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 0);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 1);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testFailVoterDirectAbstainFromVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.prank(voter1);
        _storage._abstainFromVote(PROPOSAL_ID, voter1);
    }

    function testCastAgainstVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage._castVoteAgainst(PROPOSAL_ID, voter1);
        assertEq(_storage.forVotes(PROPOSAL_ID), 0);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 1);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 0);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testFailVoterDirectCastAgainstVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.prank(voter1);
        _storage._castVoteAgainst(PROPOSAL_ID, voter1);
    }

    function testCastOneVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage._castVoteFor(PROPOSAL_ID, voter1);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testFailVoterDirectlyCastOneVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.prank(voter1);
        _storage._castVoteFor(PROPOSAL_ID, voter1);
    }

    function testQuorumAllThree() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter2, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter3, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage._castVoteFor(PROPOSAL_ID, voter1);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
        _storage._castVoteAgainst(PROPOSAL_ID, voter2);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 1);
        _storage._abstainFromVote(PROPOSAL_ID, voter3);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 1);
        assertEq(_storage.quorum(PROPOSAL_ID), 3);
    }

    function testCastOneVoteFromAll() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassOpenVote(PROPOSAL_ID, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage._castVoteFor(PROPOSAL_ID, voter1);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testCastVoteFromERC721() public {
        uint256 tokenId = 0x71;
        IERC721 token = new MockERC721(voter2, tokenId);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassERC721(PROPOSAL_ID, address(token), supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage._castVoteFor(PROPOSAL_ID, voter2);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 0);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 0);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testPermittedAfterObservingVoteDelay() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, supervisor);
        _storage.setVoteDelay(PROPOSAL_ID, 100, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        uint256 startBlock = block.number;
        vm.roll(startBlock + 100);
        _storage._castVoteFor(PROPOSAL_ID, voter1);
        assertEq(1, _storage.forVotes(PROPOSAL_ID));
    }

    function testVoterMayChangeTheirMind() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.enableUndoVote(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage._castVoteFor(PROPOSAL_ID, voter1);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
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

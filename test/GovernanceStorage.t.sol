// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/GovernanceStorage.sol";
import "../contracts/VoteStrategy.sol";
import "../contracts/ElectorVoterPoolStrategy.sol";

contract GovernanceStorageTest is Test {
    GovernanceStorage gStorage;

    address public immutable owner = address(0x155);
    address public immutable supervisor = address(0x123);
    address public immutable nonSupervisor = address(0x123eee);
    address public immutable voter1 = address(0xfff1);
    address public immutable voter2 = address(0xfff2);
    uint256 public immutable BLOCK = 0x300;
    uint256 public immutable NONE = 0;
    uint256 public immutable PROPOSAL_ID = 1;

    VoteStrategy private _strategy;

    function setUp() public {
        _strategy = new ElectorVoterPoolStrategy();
        gStorage = new GovernanceStorage();
        vm.startPrank(owner);
        gStorage.initializeProposal(_strategy);
        vm.stopPrank();
    }

    function testVotesCastZero() public {
        assertEq(gStorage.forVotes(PROPOSAL_ID), NONE);
        assertEq(gStorage.againstVotes(PROPOSAL_ID), NONE);
        assertEq(gStorage.abstentionCount(PROPOSAL_ID), NONE);
        assertEq(gStorage.totalParticipation(PROPOSAL_ID), NONE);
    }

    function testIsReady() public {
        assertFalse(gStorage.isReady(PROPOSAL_ID));
    }

    function testGetSender() public {
        address sender = gStorage.getSender(PROPOSAL_ID);
        assertEq(sender, owner);
    }

    function testFailOnlyOneOwnerCanRegisterSupervisor() public {
        vm.prank(address(0));
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
    }

    function testRegisterSupervisor() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        assertTrue(gStorage.isSupervisor(PROPOSAL_ID, supervisor));
    }

    function testFailRegisterSupervisorBadProposal() public {
        vm.prank(owner);
        gStorage.registerSupervisor(0, supervisor);
    }

    function testFailRegisterSupervisorIfOpen() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.makeReady(PROPOSAL_ID);
        gStorage.registerSupervisor(PROPOSAL_ID, nonSupervisor);
    }

    function testRegisterAndBurnSupervisor() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(owner);
        gStorage.burnSupervisor(PROPOSAL_ID, supervisor);
        assertFalse(gStorage.isSupervisor(PROPOSAL_ID, supervisor));
    }

    function testFailReadyByBurnedSupervisor() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(owner);
        gStorage.burnSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.makeReady(PROPOSAL_ID);
    }

    function testFailVoterByBurnedSupervisor() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(owner);
        gStorage.burnSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.registerVoter(PROPOSAL_ID, voter1);
    }

    function testFailBurnVoterByBurnedSupervisor() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(owner);
        gStorage.burnSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.burnVoter(PROPOSAL_ID, voter1);
    }

    function testSupervisorRegisterVoter() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.registerVoter(PROPOSAL_ID, voter1);
        assertTrue(gStorage.isVoter(PROPOSAL_ID, voter1));
    }

    function testFailSupervisorRegisterVoterIfReady() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        gStorage.registerVoter(PROPOSAL_ID, voter1);
    }

    function testSupervisorRegisterMoreThanOneVoter() public {
        address[] memory voter = new address[](2);
        voter[0] = voter1;
        voter[1] = voter2;

        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);

        gStorage.registerVoters(PROPOSAL_ID, voter);
        assertTrue(gStorage.isVoter(PROPOSAL_ID, voter1));
        assertTrue(gStorage.isVoter(PROPOSAL_ID, voter2));
    }

    function testSupervisorRegisterThenBurnVoter() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(supervisor);
        gStorage.burnVoter(PROPOSAL_ID, voter1);
        assertFalse(gStorage.isVoter(PROPOSAL_ID, voter1));
    }

    function testFailAddVoterIfReady() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        gStorage.registerVoter(PROPOSAL_ID, voter1);
    }

    function testFailBurnVoterIfOpen() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(supervisor);
        gStorage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        gStorage.burnVoter(PROPOSAL_ID, voter1);
    }

    function testFailOwnerRegisterVoter() public {
        vm.prank(owner);
        gStorage.registerVoter(PROPOSAL_ID, voter1);
    }

    function testFailOwnerBurnVoter() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(owner);
        gStorage.burnVoter(PROPOSAL_ID, voter1);
    }

    function testSetQuorumThreshold() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.setQuorumThreshold(PROPOSAL_ID, 100);
        assertEq(gStorage.quorumRequired(PROPOSAL_ID), 100);
    }

    function testFailSetQuorumThresholdIfReady() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        gStorage.setQuorumThreshold(PROPOSAL_ID, 100);
        assertEq(gStorage.quorumRequired(PROPOSAL_ID), 100);
    }

    function testRequiredParticipation() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.setRequiredParticipation(PROPOSAL_ID, 101);
        assertEq(gStorage.requiredParticipation(PROPOSAL_ID), 101);
    }

    function testFailRequiredParticipationIfReady() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        gStorage.setRequiredParticipation(PROPOSAL_ID, 101);
    }

    function testSetVoteDelay() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.setVoteDelay(PROPOSAL_ID, 100);
        assertEq(gStorage.voteDelay(PROPOSAL_ID), 100);
        vm.prank(supervisor);
        gStorage.makeReady(PROPOSAL_ID);
        assertEq(gStorage.startBlock(PROPOSAL_ID), block.number + 100);
    }

    function testFailSetVoteDelayRequiresSupervisor() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        gStorage.setVoteDelay(PROPOSAL_ID, 100);
    }

    function testFailSetVoteDelayIfReady() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        gStorage.setVoteDelay(PROPOSAL_ID, 2);
    }

    function testSetMinimumVoteDuration() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.setRequiredVoteDuration(PROPOSAL_ID, 10);
        assertEq(gStorage.voteDuration(PROPOSAL_ID), 10);
        vm.prank(supervisor);
        gStorage.makeReady(PROPOSAL_ID);
        assertEq(gStorage.endBlock(PROPOSAL_ID), block.number + 10);
    }

    function testFailSetMinimumVoteDurationNonZero() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.setRequiredVoteDuration(PROPOSAL_ID, 0);
    }

    function testFailSetMinimumVoteDurationIfReady() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        gStorage.setRequiredVoteDuration(PROPOSAL_ID, 1);
    }

    function testFailSetMinimumVoteDurationRequiredSupervisor() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        gStorage.setRequiredVoteDuration(PROPOSAL_ID, 0);
    }

    function testMakeReady() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.makeReady(PROPOSAL_ID);
        assertTrue(gStorage.isReady(PROPOSAL_ID));
    }

    function testFailMakeReadyDoubleCall() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.makeReady(PROPOSAL_ID);
        vm.prank(supervisor);
        gStorage.makeReady(PROPOSAL_ID);
    }

    function testFailMakeReadyRequireSupervisor() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        gStorage.makeReady(PROPOSAL_ID);
    }

    function testVeto() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        assertFalse(gStorage.isVeto(PROPOSAL_ID));
        vm.prank(supervisor);
        gStorage._veto(PROPOSAL_ID);
        assertTrue(gStorage.isVeto(PROPOSAL_ID));
    }

    function testFailOwnerMayNotVeto() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(owner);
        gStorage._veto(PROPOSAL_ID);
    }

    function testFailVoterMayNotVeto() public {
        vm.prank(owner);
        gStorage.registerSupervisor(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        gStorage.registerVoter(PROPOSAL_ID, voter1);
        vm.prank(voter1);
        gStorage._veto(PROPOSAL_ID);
    }
}

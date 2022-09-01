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

    function setUp() public {
        _storage = new GovernanceStorage();
        _storage.initializeProposal(owner);
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

    function testOnlyOneOwnerCanRegisterSupervisor() public {
        vm.prank(nobody);
        vm.expectRevert("Not permitted");
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, nobody);
    }

    function testRegisterSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        assertTrue(_storage.isSupervisor(PROPOSAL_ID, supervisor));
    }

    function testOwnerRegisterSupervisor() public {
        vm.expectRevert("Not permitted");
        vm.prank(owner);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
    }

    function testRegisterSupervisorBadProposal() public {
        vm.expectRevert("Invalid proposal");
        _storage.registerSupervisor(0, supervisor, owner);
    }

    function testRegisterSupervisorIfOpen() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.expectRevert("Vote not modifiable");
        _storage.registerSupervisor(PROPOSAL_ID, nonSupervisor, owner);
    }

    function testRegisterAndBurnSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor, owner);
        assertFalse(_storage.isSupervisor(PROPOSAL_ID, supervisor));
    }

    function testRegisterAndOwnerBurnSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.expectRevert("Not permitted");
        vm.prank(owner);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor, owner);
    }

    function testReadyByBurnedSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.expectRevert("Operation requires supervisor");
        _storage.makeReady(PROPOSAL_ID, supervisor);
    }

    function testVoterByBurnedSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.expectRevert("Operation requires supervisor");
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testVoterClassByBurnedSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.expectRevert("Operation requires supervisor");
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
    }

    function testBurnVoterByBurnedSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.burnSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.expectRevert("Operation requires supervisor");
        _storage.burnVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testSupervisorRegisterVoter() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        assertTrue(_storage.isVoter(PROPOSAL_ID, voter1));
    }

    function testSupervisorDirectlyRegisterVoter() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testSupervisorRegisterVoterIfReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.expectRevert("Vote not modifiable");
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testSupervisorRegisterMoreThanOneVoter() public {
        address[] memory voter = new address[](2);
        voter[0] = voter1;
        voter[1] = voter2;

        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoters(PROPOSAL_ID, voter, supervisor);
        assertTrue(_storage.isVoter(PROPOSAL_ID, voter1));
        assertTrue(_storage.isVoter(PROPOSAL_ID, voter2));
    }

    function testSupervisorDirectlyRegisterMoreThanOneVoter() public {
        address[] memory voter = new address[](2);
        voter[0] = voter1;
        voter[1] = voter2;
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        vm.prank(supervisor);
        vm.expectRevert("Not permitted");
        _storage.registerVoters(PROPOSAL_ID, voter, supervisor);
    }

    function testSupervisorRegisterThenBurnVoter() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.burnVoter(PROPOSAL_ID, voter1, supervisor);
        assertFalse(_storage.isVoter(PROPOSAL_ID, voter1));
    }

    function testSupervisorRegisterDirectlyThenBurnVoter() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.burnVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testAddVoterIfReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.expectRevert("Vote not modifiable");
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testBurnVoterIfOpen() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.expectRevert("Vote not modifiable");
        _storage.burnVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testOwnerRegisterVoter() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        vm.expectRevert("Operation requires supervisor");
        _storage.registerVoter(PROPOSAL_ID, voter1, owner);
    }

    function testOwnerBurnVoter() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        vm.expectRevert("Operation requires supervisor");
        _storage.burnVoter(PROPOSAL_ID, voter1, owner);
    }

    function testOwnerHackBurnVoter() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        vm.expectRevert("Not permitted");
        vm.prank(owner);
        _storage.burnVoter(PROPOSAL_ID, voter1, supervisor);
    }

    function testSetQuorumThreshold() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.setQuorumThreshold(PROPOSAL_ID, 100, supervisor);
        assertEq(_storage.quorumRequired(PROPOSAL_ID), 100);
    }

    function testSetQuorumThresholdDirect() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 100, supervisor);
    }

    function testSetQuorumThresholdIfReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.expectRevert("Vote not modifiable");
        _storage.setQuorumThreshold(PROPOSAL_ID, 100, supervisor);
    }

    function testSetVoteDelay() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.setVoteDelay(PROPOSAL_ID, 100, supervisor);
        assertEq(_storage.voteDelay(PROPOSAL_ID), 100);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        assertEq(_storage.startBlock(PROPOSAL_ID), block.number + 100);
    }

    function testSetVoteDelayDirect() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.setVoteDelay(PROPOSAL_ID, 100, supervisor);
    }

    function testSetVoteDelayRequiresSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.expectRevert("Not permitted");
        vm.prank(owner);
        _storage.setVoteDelay(PROPOSAL_ID, 100, owner);
    }

    function testSetVoteDelayIfReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.expectRevert("Vote not modifiable");
        _storage.setVoteDelay(PROPOSAL_ID, 2, supervisor);
    }

    function testSetMinimumVoteDuration() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10, supervisor);
        assertEq(_storage.voteDuration(PROPOSAL_ID), 10);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        assertEq(_storage.endBlock(PROPOSAL_ID), block.number + 10);
    }

    function testSetMinimumVoteDurationDirect() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 10, supervisor);
    }

    function testSetMinimumVoteDurationNonZero() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.expectRevert("Voting duration is not valid");
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 0, supervisor);
    }

    function testSetMinimumVoteDurationIfReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.expectRevert("Vote not modifiable");
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 1, supervisor);
    }

    function testSetMinimumVoteDurationRequiredSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.expectRevert("Operation requires supervisor");
        _storage.setRequiredVoteDuration(PROPOSAL_ID, 0, cognate);
    }

    function testMakeReady() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        assertTrue(_storage.isReady(PROPOSAL_ID));
    }

    function testMakeReadyDirect() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
    }

    function testMakeReadyDoubleCall() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.expectRevert("Vote not modifiable");
        _storage.makeReady(PROPOSAL_ID, supervisor);
    }

    function testMakeReadyRequireSupervisor() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.expectRevert("Operation requires supervisor");
        _storage.makeReady(PROPOSAL_ID, cognate);
    }

    function testVeto() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        assertFalse(_storage.isVeto(PROPOSAL_ID));
        _storage.veto(PROPOSAL_ID, supervisor);
        assertTrue(_storage.isVeto(PROPOSAL_ID));
    }

    function testVetoDirect() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.expectRevert("Not permitted");
        vm.prank(supervisor);
        _storage.veto(PROPOSAL_ID, supervisor);
    }

    function testOwnerMayNotVeto() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        vm.expectRevert("Operation requires supervisor");
        _storage.veto(PROPOSAL_ID, owner);
    }

    function testVoterMayNotVeto() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        vm.expectRevert("Operation requires supervisor");
        _storage.veto(PROPOSAL_ID, voter1);
    }

    function testRevertInvalidProposal(uint256 _proposalId) public {
        vm.assume(_proposalId > PROPOSAL_ID);
        vm.expectRevert("Invalid proposal");
        _storage.validOrRevert(_proposalId);
    }

    function testAbstainFromVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.abstainForShare(PROPOSAL_ID, voter1, uint160(voter1));
        assertEq(_storage.forVotes(PROPOSAL_ID), 0);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 0);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 1);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testVoterDirectAbstainFromVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.expectRevert("Not permitted");
        vm.prank(voter1);
        _storage.abstainForShare(PROPOSAL_ID, voter1, uint160(voter1));
    }

    function testCastAgainstVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.voteAgainstByShare(PROPOSAL_ID, voter1, uint160(voter1));
        assertEq(_storage.forVotes(PROPOSAL_ID), 0);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 1);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 0);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testVoterDirectCastAgainstVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.expectRevert("Not permitted");
        vm.prank(voter1);
        _storage.voteAgainstByShare(PROPOSAL_ID, voter1, uint160(voter1));
    }

    function testCastOneVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.voteForByShare(PROPOSAL_ID, voter1, uint160(voter1));
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testVoterReceipt() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.voteForByShare(PROPOSAL_ID, voter1, uint160(voter1));

        (uint256 shareId, uint256 shareFor, uint256 voteCast, bool abstention, bool isUndo) = _storage.voteReceipt(
            PROPOSAL_ID,
            uint160(voter1)
        );

        assertEq(shareId, uint160(voter1));
        assertEq(shareFor, 1);
        assertEq(voteCast, 1);
        assertFalse(abstention);
        assertFalse(isUndo);
    }

    function testVoterReceiptWithUndo() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.enableUndoVote(PROPOSAL_ID, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.voteForByShare(PROPOSAL_ID, voter1, uint160(voter1));
        _storage.undoVoteById(PROPOSAL_ID, voter1, uint160(voter1));

        (uint256 shareId, uint256 shareFor, uint256 voteCast, bool abstention, bool isUndo) = _storage.voteReceipt(
            PROPOSAL_ID,
            uint160(voter1)
        );

        assertEq(shareId, uint160(voter1));
        assertEq(shareFor, 1);
        assertEq(voteCast, 1);
        assertFalse(abstention);
        assertTrue(isUndo);
    }

    function testAgainstWithUndo() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.enableUndoVote(PROPOSAL_ID, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.voteAgainstByShare(PROPOSAL_ID, voter1, uint160(voter1));
        vm.expectRevert("Vote not affirmative");
        _storage.undoVoteById(PROPOSAL_ID, voter1, uint160(voter1));
    }

    function testAbstainWithUndo() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.enableUndoVote(PROPOSAL_ID, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.abstainForShare(PROPOSAL_ID, voter1, uint160(voter1));
        vm.expectRevert("No affirmative vote");
        _storage.undoVoteById(PROPOSAL_ID, voter1, uint160(voter1));
    }

    function testVoteAgainstReceipt() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.voteAgainstByShare(PROPOSAL_ID, voter1, uint160(voter1));

        (uint256 shareId, uint256 shareFor, uint256 voteCast, bool abstention, bool isUndo) = _storage.voteReceipt(
            PROPOSAL_ID,
            uint160(voter1)
        );

        assertEq(shareId, uint160(voter1));
        assertEq(shareFor, 0);
        assertEq(voteCast, 1);
        assertFalse(abstention);
        assertFalse(isUndo);
    }

    function testAbstentionReceipt() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.abstainForShare(PROPOSAL_ID, voter1, uint160(voter1));

        (uint256 shareId, uint256 shareFor, uint256 voteCast, bool abstention, bool isUndo) = _storage.voteReceipt(
            PROPOSAL_ID,
            uint160(voter1)
        );

        assertEq(shareId, uint160(voter1));
        assertEq(shareFor, 0);
        assertEq(voteCast, 1);
        assertTrue(abstention);
        assertFalse(isUndo);
    }

    function testVoterDirectlyCastOneVote() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        vm.expectRevert("Not permitted");
        vm.prank(voter1);
        _storage.voteForByShare(PROPOSAL_ID, voter1, uint160(voter1));
    }

    function testQuorumAllThree() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter2, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter3, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.voteForByShare(PROPOSAL_ID, voter1, uint160(voter1));
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
        _storage.voteAgainstByShare(PROPOSAL_ID, voter2, uint160(voter2));
        assertEq(_storage.againstVotes(PROPOSAL_ID), 1);
        _storage.abstainForShare(PROPOSAL_ID, voter3, uint160(voter3));
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 1);
        assertEq(_storage.quorum(PROPOSAL_ID), 3);
    }

    function testCastOneVoteFromAll() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassOpenVote(PROPOSAL_ID, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.voteForByShare(PROPOSAL_ID, voter1, uint160(voter1));
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testCastVoteFromERC721() public {
        uint256 tokenId = 0x71;
        MockERC721 token = new MockERC721();
        token.mintTo(voter2, tokenId);
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassERC721(PROPOSAL_ID, address(token), supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.voteForByShare(PROPOSAL_ID, voter2, tokenId);
        assertEq(_storage.forVotes(PROPOSAL_ID), 1);
        assertEq(_storage.againstVotes(PROPOSAL_ID), 0);
        assertEq(_storage.abstentionCount(PROPOSAL_ID), 0);
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
    }

    function testPermittedAfterObservingVoteDelay() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 1, supervisor);
        _storage.setVoteDelay(PROPOSAL_ID, 100, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        uint256 startBlock = block.number;
        vm.roll(startBlock + 100);
        _storage.voteForByShare(PROPOSAL_ID, voter1, uint160(voter1));
        assertEq(1, _storage.forVotes(PROPOSAL_ID));
    }

    function testVoteWithUndo() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.enableUndoVote(PROPOSAL_ID, supervisor);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.voteForByShare(PROPOSAL_ID, voter1, uint160(voter1));
        assertEq(_storage.quorum(PROPOSAL_ID), 1);
        _storage.undoVoteById(PROPOSAL_ID, voter1, uint160(voter1));
        assertEq(_storage.quorum(PROPOSAL_ID), NONE);
    }

    function testVoteWithDoubleUndo() public {
        _storage.registerSupervisor(PROPOSAL_ID, supervisor, owner);
        _storage.enableUndoVote(PROPOSAL_ID, supervisor);
        _storage.registerVoterClassVoterPool(PROPOSAL_ID, supervisor);
        _storage.registerVoter(PROPOSAL_ID, voter1, supervisor);
        _storage.setQuorumThreshold(PROPOSAL_ID, 2, supervisor);
        _storage.makeReady(PROPOSAL_ID, supervisor);
        _storage.voteForByShare(PROPOSAL_ID, voter1, uint160(voter1));
        _storage.undoVoteById(PROPOSAL_ID, voter1, uint160(voter1));
        vm.expectRevert("No affirmative vote");
        _storage.undoVoteById(PROPOSAL_ID, voter1, uint160(voter1));
    }

    function testName() public {
        assertEq(_storage.name(), "collective.xyz governance storage");
    }

    function testVersion() public {
        assertEq(_storage.version(), 1);
    }
}

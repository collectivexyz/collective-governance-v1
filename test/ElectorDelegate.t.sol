// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import '../contract/ElectorDelegate.sol';
import '../contract/VoterClass.sol';

contract ElectorDelegateTest is Test {
  ElectorDelegate delegate;

  address public immutable owner = msg.sender;
  address public immutable supervisor = address(0x123);
  address public immutable nonSupervisor = address(0x123eee);
  address public immutable voter1 = address(0xfff1);
  address public immutable voter2 = address(0xfff2);
  uint256 public immutable NONE = uint256(0);

  function setUp() public {
    delegate = new ElectorDelegate();
  }

  function testVoterPoolZero() public {
    assertEq(delegate.totalVoterPool(), NONE);
  }

  function testSupervisorPoolZero() public {
    assertEq(delegate.totalSupervisorPool(), NONE);
  }

  function testVotesCastZero() public {
    assertEq(delegate.totalVotesCast(), NONE);
  }

  function testFailOnlyOneOwnerCanRegisterSupervisor() public {
    vm.prank(address(0));
    delegate.registerSupervisor(supervisor);
  }

  function testRegisterSupervisor() public {
    delegate.registerSupervisor(supervisor);
    assertEq(delegate.totalSupervisorPool(), uint256(1));
  }

  function testFailRegisterSupervisorIfOpen() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.openVoting();
    delegate.registerSupervisor(nonSupervisor);
  }

  function testRegisterAndBurnSupervisor() public {
    delegate.registerSupervisor(supervisor);
    delegate.burnSupervisor(supervisor);
    assertEq(delegate.totalSupervisorPool(), NONE);
  }

  function testFailOpenByBurnedSupervisor() public {
    delegate.registerSupervisor(supervisor);
    delegate.burnSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.openVoting();
  }

  function testFailVoterByBurnedSupervisor() public {
    delegate.registerSupervisor(supervisor);
    delegate.burnSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
  }

  function testFailBurnVoterByBurnedSupervisor() public {
    delegate.registerSupervisor(supervisor);
    delegate.registerVoter(voter1);
    delegate.burnSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.burnVoter(voter1);
  }

  function testSupervisorRegisterVoter() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    assertEq(delegate.totalVoterPool(), uint256(1));
  }

  function testSupervisorRegisterMoreThanOneVoter() public {
    address[] memory voter = new address[](2);
    voter[0] = voter1;
    voter[1] = voter2;

    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);

    delegate.registerVoters(voter);
    assertEq(delegate.totalVoterPool(), uint256(2));
  }

  function testSupervisorRegisterThenBurnVoter() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    vm.prank(supervisor);
    delegate.burnVoter(voter1);
    assertEq(delegate.totalVoterPool(), NONE);
  }

  function testFailAddVoterIfOpen() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.openVoting();
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
  }

  function testFailBurnVoterIfOpen() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    vm.prank(supervisor);
    delegate.openVoting();
    vm.prank(supervisor);
    delegate.burnVoter(voter1);
  }

  function testFailOwnerRegisterVoter() public {
    delegate.registerVoter(voter1);
  }

  function testFailOwnerBurnVoter() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    vm.prank(owner);
    delegate.burnVoter(voter1);
  }

  function testSetPassThreshold() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.setPassThreshold(uint256(100));
    assertEq(delegate.requiredPassThreshold(), uint256(100));
  }

  function testFailOwnerOpenVoting() public {
    delegate.openVoting();
  }

  function testFailOwnerEndVoting() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.openVoting();
    vm.prank(owner);
    delegate.endVoting();
  }

  function testFailDoubleOpenVoting() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.openVoting();
    vm.prank(supervisor);
    delegate.openVoting();
  }

  function testFailEndVotingWhenNotOpen() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.endVoting();
  }

  function testFailOwnerCastVote() public {
    delegate.voteFor();
  }

  function testFailSupervisorCastVote() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.voteFor();
  }

  function testCastOneVote() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    vm.prank(supervisor);
    delegate.openVoting();
    vm.prank(voter1);
    delegate.voteFor();
    assertEq(delegate.totalVotesCast(), uint256(1));
  }

  function testCastOneVoteFromClass() public {
    VoterClass _voterClass = new VoterClassOpenAccess();
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoterClass(_voterClass);
    vm.prank(supervisor);
    delegate.openVoting();
    vm.prank(voter1);
    delegate.voteFor();
    assertEq(delegate.totalVotesCast(), uint256(1));
  }

  function testFailCastOneVoteWithBurnedClass() public {
    VoterClass _voterClass = new VoterClassOpenAccess();
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoterClass(_voterClass);
    vm.prank(supervisor);
    delegate.burnVoterClass();
    vm.prank(supervisor);
    delegate.openVoting();
    vm.prank(voter1);
    delegate.voteFor();
  }

  function testFailCastVoteNotOpened() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    vm.prank(voter1);
    delegate.voteFor();
  }

  function testFailCastTwoVote() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    vm.prank(supervisor);
    delegate.openVoting();
    vm.prank(voter1);
    delegate.voteFor();
    vm.prank(voter1);
    delegate.voteFor();
  }

  function testVoterMayChangeTheirMind() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    vm.prank(supervisor);
    delegate.openVoting();
    vm.prank(voter1);
    delegate.voteFor();
    assertEq(delegate.totalVotesCast(), uint256(1));
    vm.prank(voter1);
    delegate.undoVote();
    assertEq(delegate.totalVotesCast(), NONE);
  }

  function testVoterMayOnlyUndoPreviousVote() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    vm.prank(supervisor);
    delegate.openVoting();
    vm.expectRevert();
    delegate.undoVote();
  }

  function testFailSupervisorMayNotUndoVote() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    vm.prank(supervisor);
    delegate.openVoting();
    vm.prank(voter1);
    delegate.voteFor();
    vm.prank(supervisor);
    delegate.undoVote();
  }

  function testFailOwnerMayNotUndoVote() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    vm.prank(supervisor);
    delegate.openVoting();
    vm.prank(voter1);
    delegate.voteFor();
    vm.prank(owner);
    delegate.undoVote();
  }

  function testMeasureHasPassed() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    vm.prank(supervisor);
    delegate.registerVoter(voter2);
    vm.prank(supervisor);
    delegate.setPassThreshold(2);
    vm.prank(supervisor);
    delegate.openVoting();
    vm.prank(voter1);
    delegate.voteFor();
    vm.prank(voter2);
    delegate.voteFor();
    vm.prank(supervisor);
    delegate.endVoting();
    assertTrue(delegate.getResult());
  }

  function testMeasureFailed() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    vm.prank(supervisor);
    delegate.registerVoter(voter2);
    vm.prank(supervisor);
    delegate.setPassThreshold(76);
    vm.prank(supervisor);
    delegate.openVoting();
    vm.prank(voter1);
    delegate.voteFor();
    vm.prank(voter2);
    delegate.voteFor();
    vm.prank(supervisor);
    delegate.endVoting();
    assertFalse(delegate.getResult());
  }

  function testFailGetResultOnOpenMeasure() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    vm.prank(supervisor);
    delegate.openVoting();
    delegate.getResult();
  }

  function testFailMeasureIsVeto() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    vm.prank(supervisor);
    delegate.registerVoter(voter2);
    vm.prank(supervisor);
    delegate.setPassThreshold(2);
    vm.prank(supervisor);
    delegate.openVoting();
    vm.prank(voter1);
    delegate.voteFor();
    vm.prank(voter2);
    delegate.voteFor();
    vm.prank(supervisor);
    delegate.vetoMeasure();
    assertTrue(delegate.isSupervisorVeto());
    vm.prank(supervisor);
    delegate.endVoting();
    delegate.getResult();
  }

  function testFailMeasureLateVeto() public {
    delegate.registerSupervisor(supervisor);
    vm.prank(supervisor);
    delegate.registerVoter(voter1);
    vm.prank(supervisor);
    delegate.registerVoter(voter2);
    vm.prank(supervisor);
    delegate.setPassThreshold(2);
    vm.prank(supervisor);
    delegate.openVoting();
    vm.prank(voter1);
    delegate.voteFor();
    vm.prank(voter2);
    delegate.voteFor();
    vm.prank(supervisor);
    delegate.endVoting();
    vm.prank(supervisor);
    delegate.vetoMeasure();
  }
}

contract VoterClassOpenAccess is VoterClass {
  function isVoter(address) external view returns (bool) {
    return true;
  }
}

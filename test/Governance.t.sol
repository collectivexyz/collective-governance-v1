// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import '../src/Governance.sol';

contract GovernanceTest is Test {
  Governance governance;

  function setUp() public {
    governance = new Governance();
  }

  function testGetQuestion() public {
    assertTrue(compareString(governance.get(), ''));
  }

  function testSetQuestion() public {
    string memory q = 'testing';
    governance.set(q);
    assertTrue(compareString(governance.get(), q));
  }

  function compareString(string memory a, string memory b) private returns (bool isEqual) {
    bytes32 hashA = keccak256(abi.encodePacked(a));
    bytes32 hashB = keccak256(abi.encodePacked(b));
    return hashA == hashB;
  }
}

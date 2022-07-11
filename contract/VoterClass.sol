// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

/// @notice Interface indicating membership in a voting class
interface VoterClass {
  function isVoter(address _wallet) external view returns (bool);
}

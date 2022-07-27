// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;
import './VoterClass.sol';

/// @notice voting class for ERC-721 contract
contract VoterClassNullObject is VoterClass {
  function isVoter(address) external view returns (bool) {
    return false;
  }

  function votesAvailable(address _wallet) external view returns (uint256) {
    return 1;
  }
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import '@openzeppelin/contracts/interfaces/IERC721.sol';
import './VoterClass.sol';

/// @notice voting class for ERC-721 contract
contract VoterClassERC721 is VoterClass {
  address public _contractAddress;

  constructor(address _contract) {
    _contractAddress = _contract;
  }

  function isVoter(address _wallet) external view returns (bool) {
    return IERC721(_contractAddress).balanceOf(_wallet) > 0;
  }
}

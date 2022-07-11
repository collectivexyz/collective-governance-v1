import './VoterClass.sol';

/// @notice voting class for ERC-721 contract
contract VoterClassNullObject is VoterClass {
  function isVoter(address) external view returns (bool) {
    return false;
  }
}

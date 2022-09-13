// SPDX-License-Identifier: BSD-3-Clause
/*
 * Copyright 2022 collective.xyz
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "./VoterClass.sol";

/// @notice voting class for ERC-721 contract
contract VoterClassNullObject is VoterClass, ERC165 {
    string public constant name = "collective.xyz VoterClassNullObject";

    // solium-disable-next-line no-empty-blocks
    constructor() {}

    modifier requireValidAddress(address _wallet) {
        require(_wallet != address(0), "Not a valid wallet");
        _;
    }

    function isFinal() external pure returns (bool) {
        return true;
    }

    function isVoter(address _wallet) external pure requireValidAddress(_wallet) returns (bool) {
        return false;
    }

    function discover(address _wallet) external pure requireValidAddress(_wallet) returns (uint256[] memory) {
        revert("Not a voter");
    }

    /// @notice commit votes for shareId return number voted
    function confirm(
        address, /* _wallet */
        uint256 /* shareId */
    ) external pure returns (uint256) {
        return 0;
    }

    /// @notice return voting weight of each confirmed share
    function weight() external pure returns (uint256) {
        return 0;
    }

    function supportsInterface(bytes4) public view virtual override(ERC165) returns (bool) {
        return false;
    }

    function version() external pure returns (uint32) {
        return 0;
    }
}

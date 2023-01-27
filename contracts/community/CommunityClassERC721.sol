// SPDX-License-Identifier: BSD-3-Clause
/*
 *                          88  88                                   88
 *                          88  88                            ,d     ""
 *                          88  88                            88
 *  ,adPPYba,   ,adPPYba,   88  88   ,adPPYba,   ,adPPYba,  MM88MMM  88  8b       d8   ,adPPYba,
 * a8"     ""  a8"     "8a  88  88  a8P_____88  a8"     ""    88     88  `8b     d8'  a8P_____88
 * 8b          8b       d8  88  88  8PP"""""""  8b            88     88   `8b   d8'   8PP"""""""
 * "8a,   ,aa  "8a,   ,a8"  88  88  "8b,   ,aa  "8a,   ,aa    88,    88    `8b,d8'    "8b,   ,aa
 *  `"Ybbd8"'   `"YbbdP"'   88  88   `"Ybbd8"'   `"Ybbd8"'    "Y888  88      "8"       `"Ybbd8"'
 *
 */
/*
 * BSD 3-Clause License
 *
 * Copyright (c) 2022, collective
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "../../contracts/access/AlwaysFinal.sol";
import "../../contracts/community/ScheduledCommunityClass.sol";

/// @title ERC721 Implementation of CommunityClass
/// @notice This contract implements a voter pool based on ownership of an ERC-721 token.
/// A class member is considered a voter if they have signing access to a wallet that is marked
/// ownerOf a token of the specified address
/// @dev ERC721Enumerable is supported for discovery, however if the token contract does not support enumeration
/// then vote by specific tokenId is still supported
contract CommunityClassERC721 is ScheduledCommunityClass, AlwaysFinal {
    error ERC721EnumerableRequired(address contractAddress);

    string public constant NAME = "CommunityClassERC721";

    address internal immutable _contractAddress;

    uint256 internal immutable _weight;

    /// @param _contract Address of the token contract
    /// @param _voteWeight The integral weight to apply to each token held by the wallet
    /// @param _minimumQuorum the least possible quorum for any vote
    /// @param _minimumDelay the least possible vote delay
    /// @param _maximumDelay the least possible vote delay
    /// @param _minimumDuration the least possible voting duration
    /// @param _maximumDuration the least possible voting duration
    constructor(
        address _contract,
        uint256 _voteWeight,
        uint256 _minimumQuorum,
        uint256 _minimumDelay,
        uint256 _maximumDelay,
        uint256 _minimumDuration,
        uint256 _maximumDuration
    ) ScheduledCommunityClass(_minimumQuorum, _minimumDelay, _maximumDelay, _minimumDuration, _maximumDuration) {
        _contractAddress = _contract;
        _weight = _voteWeight;
    }

    modifier requireValidToken(uint256 _shareId) {
        if (_shareId == 0) revert UnknownToken(_shareId);
        _;
    }

    /// @notice determine if wallet holds at least one token from the ERC-721 contract
    /// @return bool true if wallet can sign for votes on this class
    function isVoter(address _wallet) public view returns (bool) {
        return IERC721(_contractAddress).balanceOf(_wallet) > 0;
    }

    /// @notice determine if adding a proposal is approved for this voter
    /// @return bool true if this address is approved
    function canPropose(address) external view virtual returns (bool) {
        return true;
    }

    /// @notice tabulate the number of votes available for the specific wallet and tokenId
    /// @param _wallet The wallet to test for ownership
    /// @param _tokenId The id of the token associated with the ERC-721 contract
    function votesAvailable(address _wallet, uint256 _tokenId) external view returns (uint256) {
        address tokenOwner = IERC721(_contractAddress).ownerOf(_tokenId);
        if (_wallet == tokenOwner) {
            return 1;
        }
        return 0;
    }

    /// @notice discover an array of tokenIds associated with the specified wallet
    /// @dev discovery requires support for ERC721Enumerable, otherwise execution will revert
    /// @return uint256[] array in memory of share ids
    function discover(address _wallet) external view returns (uint256[] memory) {
        bytes4 interfaceId721 = type(IERC721Enumerable).interfaceId;
        if (!IERC721(_contractAddress).supportsInterface(interfaceId721)) revert ERC721EnumerableRequired(_contractAddress);
        IERC721Enumerable enumContract = IERC721Enumerable(_contractAddress);
        IERC721 _nft = IERC721(_contractAddress);
        uint256 tokenBalance = _nft.balanceOf(_wallet);
        if (tokenBalance == 0) revert NotOwner(_contractAddress, _wallet);
        uint256[] memory tokenIdList = new uint256[](tokenBalance);
        for (uint256 i = 0; i < tokenBalance; i++) {
            tokenIdList[i] = enumContract.tokenOfOwnerByIndex(_wallet, i);
        }
        return tokenIdList;
    }

    /// @notice confirm tokenId is associated with wallet for voting
    /// @dev does not require IERC721Enumerable, tokenId ownership is checked directly using ERC-721
    /// @return uint256 The number of weighted votes confirmed
    function confirm(address _wallet, uint256 _tokenId) external view requireValidToken(_tokenId) returns (uint256) {
        uint256 voteCount = this.votesAvailable(_wallet, _tokenId);
        if (voteCount == 0) revert NotOwner(_contractAddress, _wallet);
        return _weight * voteCount;
    }

    /// @notice return voting weight of each confirmed share
    /// @return uint256 weight applied to one share
    function weight() external view returns (uint256) {
        return _weight;
    }

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure virtual returns (string memory) {
        return NAME;
    }
}

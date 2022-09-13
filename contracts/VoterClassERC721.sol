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
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./VoterClass.sol";

/// @notice voting class for ERC-721 contract
contract VoterClassERC721 is VoterClass, ERC165 {
    string public constant name = "collective.xyz VoterClassERC721";
    uint32 public constant VERSION_1 = 1;

    address private _cognate;

    address private _contractAddress;

    uint256 private _weight;

    constructor(address _contract, uint256 _voteWeight) {
        _cognate = msg.sender;
        _contractAddress = _contract;
        _weight = _voteWeight;
    }

    modifier requireCognate() {
        require(_cognate == msg.sender, "Not permitted");
        _;
    }

    modifier requireValidAddress(address _wallet) {
        require(_wallet != address(0), "Not a valid wallet");
        _;
    }

    modifier requireValidShare(uint256 _shareId) {
        require(_shareId != 0, "Share not valid");
        _;
    }

    function isFinal() external pure returns (bool) {
        return true;
    }

    function isVoter(address _wallet) external view requireValidAddress(_wallet) returns (bool) {
        return IERC721(_contractAddress).balanceOf(_wallet) > 0;
    }

    function votesAvailable(address _wallet, uint256 _shareId) external view requireValidAddress(_wallet) returns (uint256) {
        address tokenOwner = IERC721(_contractAddress).ownerOf(_shareId);
        if (_wallet == tokenOwner) {
            return 1;
        }
        return 0;
    }

    function discover(address _wallet) external view requireValidAddress(_wallet) returns (uint256[] memory) {
        bytes4 interfaceId721 = type(IERC721Enumerable).interfaceId;
        require(IERC721(_contractAddress).supportsInterface(interfaceId721), "ERC-721 Enumerable required");
        IERC721Enumerable enumContract = IERC721Enumerable(_contractAddress);
        IERC721 _nft = IERC721(_contractAddress);
        uint256 tokenBalance = _nft.balanceOf(_wallet);
        require(tokenBalance > 0, "Token owner required");
        uint256[] memory tokenIdList = new uint256[](tokenBalance);
        for (uint256 i = 0; i < tokenBalance; i++) {
            tokenIdList[i] = enumContract.tokenOfOwnerByIndex(_wallet, i);
        }
        return tokenIdList;
    }

    /// @notice commit votes for shareId return number voted
    function confirm(address _wallet, uint256 _shareId) external view requireValidShare(_shareId) returns (uint256) {
        uint256 voteCount = this.votesAvailable(_wallet, _shareId);
        require(voteCount > 0, "Not owner of specified token");
        return _weight * voteCount;
    }

    /// @notice return voting weight of each confirmed share
    function weight() external view returns (uint256) {
        return _weight;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return interfaceId == type(VoterClass).interfaceId || super.supportsInterface(interfaceId);
    }

    function version() external pure returns (uint32) {
        return VERSION_1;
    }
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/interfaces/IERC721.sol";

contract MockERC721 is IERC721 {
    address private _owner;
    uint256 private _tokenId;

    constructor(address owner, uint256 tokenId) {
        _owner = owner;
        _tokenId = tokenId;
    }

    function balanceOf(address owner) external view returns (uint256) {
        if (_owner == owner) {
            return 1;
        }
        return 0;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        if (_tokenId == tokenId) {
            return _owner;
        }
        revert("token does not exist");
    }

    function safeTransferFrom(
        address, /* from */
        address, /* to */
        uint256, /* tokenId */
        bytes calldata /* data */
    ) external pure {
        revert("Not implemented");
    }

    function safeTransferFrom(
        address, /* from */
        address, /* to */
        uint256 /* tokenId */
    ) external pure {
        revert("Not implemented");
    }

    function transferFrom(
        address, /* from */
        address, /* to */
        uint256 /* tokenId */
    ) external pure {
        revert("Not implemented");
    }

    function approve(
        address, /* to */
        uint256 /*tokenId*/
    ) external pure {
        revert("Not implemented");
    }

    function setApprovalForAll(
        address, /* operator */
        bool /* _approved */
    ) external pure {
        revert("Not implemented");
    }

    function getApproved(
        uint256 /* tokenId */
    ) external pure returns (address) {
        revert("Not implemented");
    }

    function isApprovedForAll(
        address, /* owner */
        address /* operator */
    ) external pure returns (bool) {
        revert("Not implemented");
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        revert("Not implemented");
    }
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";

contract MockERC721 is IERC721, ERC165 {
    mapping(address => uint256) private _ownerBalanceMap;
    mapping(uint256 => address) private _tokenMap;

    modifier tokenExists(uint256 _tokenId) {
        require(_tokenMap[_tokenId] != address(0x0), "Token does not exist");
        _;
    }

    modifier tokenDoesNotExist(uint256 _tokenId) {
        require(_tokenMap[_tokenId] == address(0x0), "Token exists");
        _;
    }

    modifier tokenOwnedBy(uint256 _tokenId, address _owner) {
        require(_tokenMap[_tokenId] == _owner, "Not token owner");
        _;
    }

    function mintTo(address _owner, uint256 _tokenId) public virtual tokenDoesNotExist(_tokenId) {
        _ownerBalanceMap[_owner] += 1;
        _tokenMap[_tokenId] = _owner;
    }

    function balanceOf(address _owner) external view returns (uint256) {
        return _ownerBalanceMap[_owner];
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        address owner = _tokenMap[_tokenId];
        if (owner == address(0)) {
            revert("No such token");
        }
        return owner;
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata /* data */
    ) external tokenExists(_tokenId) tokenOwnedBy(_tokenId, _from) {
        require(_from == msg.sender, "Not token owner");
        _ownerBalanceMap[_from] -= 1;
        _ownerBalanceMap[_to] += 1;
        _tokenMap[_tokenId] = _to;
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external tokenExists(_tokenId) tokenOwnedBy(_tokenId, _from) {
        require(_from == msg.sender, "Not token owner");
        _ownerBalanceMap[_from] -= 1;
        _ownerBalanceMap[_to] += 1;
        _tokenMap[_tokenId] = _to;
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        require(_from == msg.sender, "Not token owner");
        _ownerBalanceMap[_from] -= 1;
        _ownerBalanceMap[_to] += 1;
        _tokenMap[_tokenId] = _to;
    }

    function approve(address /* to */, uint256 /*tokenId*/) external pure {
        revert("Not implemented");
    }

    function setApprovalForAll(address /* operator */, bool /* _approved */) external pure {
        revert("Not implemented");
    }

    function getApproved(uint256 /* tokenId */) external pure returns (address) {
        revert("Not implemented");
    }

    function isApprovedForAll(address /* owner */, address /* operator */) external pure returns (bool) {
        revert("Not implemented");
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC721).interfaceId || super.supportsInterface(interfaceId);
    }
}

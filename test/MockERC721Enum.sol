// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "./MockERC721.sol";

contract MockERC721Enum is MockERC721, IERC721Enumerable {
    uint256 private _totalCount = 0;
    mapping(uint256 => uint256) private _tokenSupply;
    mapping(address => OwnerSupply) private _ownerSupply;

    struct OwnerSupply {
        uint256 _totalCount;
        mapping(uint256 => uint256) _supply;
    }

    function mintTo(address _owner, uint256 _tokenId) public override(MockERC721) {
        super.mintTo(_owner, _tokenId);
        _tokenSupply[_totalCount] = _tokenId;
        OwnerSupply storage ownerSupply = _ownerSupply[_owner];
        uint256 index = ownerSupply._totalCount++;
        ownerSupply._supply[index] = _tokenId;
        _totalCount++;
    }

    function totalSupply() external view returns (uint256) {
        return _totalCount;
    }

    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256) {
        OwnerSupply storage ownerSupply = _ownerSupply[_owner];
        require(_index < ownerSupply._totalCount, "Invalid token index");
        return ownerSupply._supply[_index];
    }

    function tokenByIndex(uint256 index) external view returns (uint256) {
        require(index < _totalCount, "Invalid token index");
        return _tokenSupply[index];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, MockERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }
}

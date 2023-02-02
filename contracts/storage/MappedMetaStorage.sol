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

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../contracts/Constant.sol";
import "../../contracts/storage/MetaStorage.sol";
import "../../contracts/access/Versioned.sol";
import "../../contracts/access/VersionedContract.sol";

contract MappedMetaStorage is MetaStorage, VersionedContract, ERC165, Ownable {
    string public constant NAME = "meta storage";

    bytes32 public immutable _communityName;

    string public _communityUrl;

    string public _communityDescription;

    /// @notice global map of metadata storage
    mapping(uint256 => MetaStore) public metaStoreMap;

    /// @notice create a new storage object
    /// @param _community The community name
    /// @param _url The Url for this community
    /// @param _description The community description
    constructor(
        bytes32 _community,
        string memory _url,
        string memory _description
    ) requireValidString(_url) requireValidString(_description) {
        _communityName = _community;
        _communityUrl = _url;
        _communityDescription = _description;
    }

    modifier requireValid(uint256 _metaId) {
        MetaStore storage metaStore = metaStoreMap[_metaId];
        if (_metaId == 0 || metaStore.id != _metaId) revert IndexInvaliddataId(_metaId);
        _;
    }

    modifier requireValidString(string memory _data) {
        uint256 length = Constant.len(_data);
        if (length > Constant.STRING_DATA_LIMIT) revert StringSizeLimit(length);
        _;
    }

    /// @notice get the number of attached metadata
    /// @param _metaId the id of the metadata
    /// @return uint256 current number of meta elements
    function metaCount(uint256 _metaId) external view requireValid(_metaId) returns (uint256) {
        MetaStore storage metaStore = metaStoreMap[_metaId];
        return metaStore.meta.size();
    }

    /// @notice set metadata
    /// @dev requires owner
    /// @param _metaId the id of the metadata
    /// @param _url the url
    /// @param _description the description
    function describe(
        uint256 _metaId,
        string memory _url,
        string memory _description
    ) external onlyOwner requireValidString(_url) requireValidString(_description) {
        if (_metaId == 0) revert IndexInvaliddataId(_metaId);
        MetaStore storage metaStore = metaStoreMap[_metaId];
        if (metaStore.id != _metaId) initializeStore(_metaId);
        metaStore.url = _url;
        metaStore.description = _description;
        emit DescribeMeta(_metaId, _url, _description);
    }

    /// @notice get the url by id
    /// @param _metaId the id of the metadata
    /// @return string the url
    function url(uint256 _metaId) external view requireValid(_metaId) returns (string memory) {
        MetaStore storage metaStore = metaStoreMap[_metaId];
        return metaStore.url;
    }

    /// @notice get the metadata description by id
    /// @param _metaId the id of the metadata
    /// @return string the description
    function description(uint256 _metaId) external view requireValid(_metaId) returns (string memory) {
        MetaStore storage metaStore = metaStoreMap[_metaId];
        return metaStore.description;
    }

    /// @notice attach arbitrary metadata
    /// @dev requires owner
    /// @param _metaId the id of the metadata to modify
    /// @param _name the name of the metadata field
    /// @param _value the value of the metadata
    /// @return uint256 the id of the attached element
    function addMeta(
        uint256 _metaId,
        bytes32 _name,
        string memory _value
    ) external onlyOwner requireValid(_metaId) requireValidString(_value) returns (uint256) {
        MetaStore storage metaStore = metaStoreMap[_metaId];
        uint256 metaElementId = metaStore.meta.add(Meta(_name, _value));
        emit AddMeta(_metaId, metaElementId, _name, _value);
        return metaElementId;
    }

    /// @notice get arbitrary metadata element
    /// @param _metaId the id of the metadata
    /// @param _metaElementId the id of the element
    /// @return Meta the metadata element
    function getMeta(uint256 _metaId, uint256 _metaElementId) external view requireValid(_metaId) returns (Meta memory) {
        MetaStore storage metaStore = metaStoreMap[_metaId];
        return metaStore.meta.get(_metaElementId);
    }

    /// @notice return the name of the community
    /// @return bytes32 the community name
    function community() external view returns (bytes32) {
        return _communityName;
    }

    /// @notice return the community url
    /// @return string memory representation of url
    function url() external view returns (string memory) {
        return _communityUrl;
    }

    /// @notice return community description
    /// @return string memory representation of community description
    function description() external view returns (string memory) {
        return _communityDescription;
    }

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure virtual returns (string memory) {
        return NAME;
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(MetaStorage).interfaceId ||
            interfaceId == type(Ownable).interfaceId ||
            interfaceId == type(Versioned).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function initializeStore(uint256 _metaId) internal {
        MetaStore storage metaStore = metaStoreMap[_metaId];
        metaStore.id = _metaId;
        metaStore.description = "";
        metaStore.url = "";
        metaStore.meta = new MetaSet();
    }
}

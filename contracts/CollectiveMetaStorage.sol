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

import "../contracts/Constant.sol";
import "../contracts/MetaStorage.sol";

contract CollectiveMetaStorage is MetaStorage, ERC165, Ownable {
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
    ) {
        if (Constant.len(_url) > Constant.STRING_DATA_LIMIT) revert CommunityUrlExceedsDataLimit();
        if (Constant.len(_description) > Constant.STRING_DATA_LIMIT) revert CommunityDescriptionExceedsDataLimit();
        _communityName = _community;
        _communityUrl = _url;
        _communityDescription = _description;
    }

    modifier requireValid(uint256 _metadataId) {
        MetaStore storage metaStore = metaStoreMap[_metadataId];
        if (metaStore.id != _metadataId) revert InvalidMetadataId(_metadataId);
        _;
    }

    /// @notice get the number of attached metadata
    /// @param _metaId the id of the metadata
    /// @return uint256 current number of meta elements
    function metaCount(uint256 _metaId) external view requireValid(_metaId) returns (uint256) {
        MetaStore storage metaStore = metaStoreMap[_metaId];
        return metaStore.metaCount;
    }

    /// @notice set metadata
    /// @dev requires supervisor
    /// @param _metadataId the id of the metadata
    /// @param _url the url
    /// @param _description the description
    function describe(
        uint256 _metadataId,
        string memory _url,
        string memory _description
    ) external onlyOwner {
        if (Constant.len(_url) > Constant.STRING_DATA_LIMIT) revert UrlExceedsDataLimit(_metadataId);
        if (Constant.len(_description) > Constant.STRING_DATA_LIMIT) revert DescriptionExceedsDataLimit(_metadataId);
        MetaStore storage metaStore = metaStoreMap[_metadataId];
        if (metaStore.id != _metadataId) {
            metaStore.id = _metadataId;
        }
        metaStore.url = _url;
        metaStore.description = _description;
        emit Describe(_metadataId, _url, _description);
    }

    /// @notice get the url
    /// @param _metadataId the id of the metadata
    /// @return string the url
    function url(uint256 _metadataId) external view requireValid(_metadataId) returns (string memory) {
        MetaStore storage metaStore = metaStoreMap[_metadataId];
        return metaStore.url;
    }

    /// @notice get the metadata description
    /// @param _metadataId the id of the metadata
    /// @return string the description
    function description(uint256 _metadataId) external view requireValid(_metadataId) returns (string memory) {
        MetaStore storage metaStore = metaStoreMap[_metadataId];
        return metaStore.description;
    }

    /// @notice attach arbitrary metadata to metadata
    /// @dev requires supervisor
    /// @param _metadataId the id of the metadata
    /// @param _name the name of the metadata field
    /// @param _value the value of the metadata
    /// @return uint256 the metadata id
    function addMeta(
        uint256 _metadataId,
        bytes32 _name,
        string memory _value
    ) external onlyOwner returns (uint256) {
        if (Constant.len(_value) > Constant.STRING_DATA_LIMIT) revert ValueExceedsDataLimit(_metadataId);
        MetaStore storage metaStore = metaStoreMap[_metadataId];
        if (metaStore.id != _metadataId) {
            metaStore.id = _metadataId;
        }
        uint256 metaId = metaStore.metaCount++;
        metaStore.metadata[metaId] = Meta(metaId, _name, _value);
        emit AddMeta(_metadataId, metaId, _name, _value);
        return metaId;
    }

    /// @notice get arbitrary metadata from metadata
    /// @param _metadataId the id of the metadata
    /// @param _metaId the id of the metadata
    /// @return _name the name of the metadata field
    /// @return _value the value of the metadata field
    function getMeta(uint256 _metadataId, uint256 _metaId)
        external
        view
        requireValid(_metadataId)
        returns (bytes32 _name, string memory _value)
    {
        MetaStore storage metaStore = metaStoreMap[_metadataId];
        if (_metaId >= metaStore.metaCount) revert UnknownMetadata(_metadataId, _metaId);
        Meta memory meta = metaStore.metadata[_metaId];
        if (meta.id != _metaId) revert InvalidMetadata(_metadataId, _metaId);
        return (meta.name, meta.value);
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

    /// @notice return the version of this implementation
    /// @return uint32 version number
    function version() public pure virtual returns (uint32) {
        return Constant.VERSION_1;
    }

    /// @notice see ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(MetaStorage).interfaceId ||
            interfaceId == type(Ownable).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
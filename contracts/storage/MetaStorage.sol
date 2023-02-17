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

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "../../contracts/access/Versioned.sol";
import "../../contracts/collection/MetaSet.sol";

/// @title Metadata storage interface
/// @notice store community metadata
/// @custom:type interface
interface MetaStorage is Versioned, IERC165 {
    error StringSizeLimit(uint256 length);
    error IndexInvaliddataId(uint256 metadataId);

    event DescribeMeta(uint256 metadataId, string url, string description);
    event AddMeta(uint256 metadataId, uint256 metaId, bytes32 name, string value);

    struct MetaStore {
        /// @notice id of metadata store
        /// @dev implements a parity check to prevent accessing uninitialized storage
        uint256 id;
        /// @notice metadata description
        string description;
        /// @notice metadata url
        string url;
        /// arbitrary metadata
        MetaSet meta;
    }

    /// @notice return the name of the community
    /// @return bytes32 the community name
    function community() external view returns (bytes32);

    /// @notice return the community url
    /// @return string memory representation of url
    function url() external view returns (string memory);

    /// @notice return community description
    /// @return string memory representation of community description
    function description() external view returns (string memory);

    /// @notice get the metadata url
    /// @param _metaId the id of the metadata
    /// @return string the url
    function url(uint256 _metaId) external returns (string memory);

    /// @notice set metadata
    /// @dev requires owner
    /// @param _metaId the id of the metadata
    /// @param _url the url
    /// @param _description the description
    function describe(uint256 _metaId, string memory _url, string memory _description) external;

    /// @notice get the metadata description
    /// @param _metaId the id of the metadata
    /// @return string the url
    function description(uint256 _metaId) external returns (string memory);

    /// @notice get the number of attached metadata
    /// @param _metaId the id of the metadata
    /// @return uint256 current number of meta elements
    function size(uint256 _metaId) external view returns (uint256);

    /// @notice attach arbitrary metadata to metadata
    /// @dev requires ownera
    /// @param _metaId the id of the metadata
    /// @param _name the name of the metadata field
    /// @param _value the value of the metadata
    /// @return uint256 the meta element id
    function add(uint256 _metaId, bytes32 _name, string memory _value) external returns (uint256);

    /// @notice get arbitrary metadata from metadata
    /// @param _metaId the id of the metadata
    /// @param _metaElementId the id of the metadata
    /// @return Meta the meta data
    function get(uint256 _metaId, uint256 _metaElementId) external returns (Meta memory);

    /// @notice return the name of this implementation
    /// @return string memory representation of name
    function name() external pure returns (string memory);
}

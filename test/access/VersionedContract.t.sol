// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable no-empty-blocks
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { Constant } from "../../contracts/Constant.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";
import { VersionedContract } from "../../contracts/access/VersionedContract.sol";

contract VersionedContractTest is Test {
    Versioned private _trinket;

    function setUp() public {
        _trinket = new VersionedTrinket();
    }

    function testVersion() public {
        assertEq(_trinket.version(), Constant.CURRENT_VERSION);
    }
}

contract VersionedTrinket is VersionedContract {}

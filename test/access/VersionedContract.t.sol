// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable no-empty-blocks
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../../contracts/access/VersionedContract.sol";

contract VersionedContractTest is Test {
    Versioned private _trinket;

    function setUp() public {
        _trinket = new VersionedTrinket();
    }

    function testVersion() public {
        assertEq(_trinket.version(), Constant.VERSION_3);
    }
}

contract VersionedTrinket is VersionedContract {}

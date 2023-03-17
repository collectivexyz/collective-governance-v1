// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable no-empty-blocks
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { Mutable } from "../../contracts/access/Mutable.sol";
import { ConfigurableMutable } from "../../contracts/access/ConfigurableMutable.sol";
import { AlwaysFinal } from "../../contracts/access/AlwaysFinal.sol";

contract MutableTest is Test {
    ConfigMutable private _config;

    address private constant _NOT_OWNER = address(0x15);

    function setUp() public {
        _config = new ConfigMutable();
    }

    function testIsFinal() public {
        assertFalse(_config.isFinal());
    }

    function testConfigWrite() public {
        _config.write();
    }

    function testFailMakeFinalWrite() public {
        _config.makeFinal();
        _config.write();
    }

    function testFailReadNotFinal() public {
        _config.read();
    }

    function testImmutableRead() public {
        AlwaysImmutable _never = new AlwaysImmutable();
        _never.read();
    }
}

contract ConfigMutable is ConfigurableMutable {
    function write() external onlyMutable {}

    function read() external onlyFinal {}
}

contract AlwaysImmutable is AlwaysFinal {
    function read() external onlyFinal {}
}

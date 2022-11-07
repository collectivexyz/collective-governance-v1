// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable no-empty-blocks
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../../contracts/access/Mutable.sol";
import "../../contracts/access/ConfigurableMutable.sol";
import "../../contracts/access/AlwaysImmutable.sol";

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
        NeverMutable _never = new NeverMutable();
        _never.read();
    }
}

contract ConfigMutable is ConfigurableMutable {
    function write() external onlyMutable {}

    function read() external onlyFinal {}
}

contract NeverMutable is AlwaysImmutable {
    function read() external onlyFinal {}
}

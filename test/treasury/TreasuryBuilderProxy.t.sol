// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { TreasuryBuilder } from "../../contracts/treasury/TreasuryBuilder.sol";
import { createTreasuryBuilder, TreasuryBuilderProxy } from "../../contracts/treasury/TreasuryBuilderProxy.sol";

contract TreasuryBuilderProxyTest is Test {
    TreasuryBuilder private _builder;

    function setUp() public {
        _builder = createTreasuryBuilder();
    }

    function testProxyCreate() public {
        assertEq(_builder.name(), "treasury builder");
    }

    function testProxyUpgrade() public {
        address payable _paddr = payable(address(_builder));
        TreasuryBuilderProxy _proxy = TreasuryBuilderProxy(_paddr);
        TreasuryBuilder _tbuilder = new TBuilder2();
        _proxy.upgrade(address(_tbuilder), uint8(_tbuilder.version()));
        assertEq(_builder.name(), "test upgrade");
    }

    function testProxyUpgrade2Times() public {
        address payable _paddr = payable(address(_builder));
        TreasuryBuilderProxy _proxy = TreasuryBuilderProxy(_paddr);
        TreasuryBuilder _tbuilder = new TBuilder2();
        _proxy.upgrade(address(_tbuilder), uint8(_tbuilder.version()));
        _proxy.upgrade(address(_tbuilder), uint8(_tbuilder.version() + 1));
        assertEq(_builder.name(), "test upgrade");
    }
}

contract TBuilder2 is TreasuryBuilder {
    function name() external pure virtual override(TreasuryBuilder) returns (string memory) {
        return "test upgrade";
    }
}

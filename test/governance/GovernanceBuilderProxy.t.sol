// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { StorageFactory } from "../../contracts/storage/StorageFactory.sol";
import { MetaStorageFactory } from "../../contracts/storage/MetaStorageFactory.sol";
import { GovernanceFactory } from "../../contracts/governance/GovernanceFactory.sol";
import { GovernanceBuilder } from "../../contracts/governance/GovernanceBuilder.sol";
import { createGovernanceBuilder, GovernanceBuilderProxy } from "../../contracts/governance/GovernanceBuilderProxy.sol";

contract GovernanceBuilderProxyTest is Test {
    GovernanceBuilder private _builder;

    function setUp() public {
        GovernanceFactory _governanceFactory = new GovernanceFactory();
        StorageFactory _storageFactory = new StorageFactory();
        MetaStorageFactory _metaStorageFactory = new MetaStorageFactory();
        _builder = createGovernanceBuilder(_governanceFactory, _storageFactory, _metaStorageFactory);
    }

    function testProxyCreate() public {
        assertEq(_builder.name(), "governance builder");
    }

    function testProxyUpgrade() public {
        GovernanceFactory _governanceFactory = new GovernanceFactory();
        StorageFactory _storageFactory = new StorageFactory();
        MetaStorageFactory _metaStorageFactory = new MetaStorageFactory();
        address payable _paddr = payable(address(_builder));
        GovernanceBuilderProxy _proxy = GovernanceBuilderProxy(_paddr);
        GovernanceBuilder _gbuilder = new GBuilder2();
        _proxy.upgrade(address(_gbuilder), address(_governanceFactory), address(_storageFactory), address(_metaStorageFactory));
        assertEq(_builder.name(), "test upgrade");
    }
}

contract GBuilder2 is GovernanceBuilder {
    function name() external pure virtual override(GovernanceBuilder) returns (string memory) {
        return "test upgrade";
    }
}

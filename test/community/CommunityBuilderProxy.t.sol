// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { CommunityBuilder } from "../../contracts/community/CommunityBuilder.sol";
import { createCommunityBuilder, CommunityBuilderProxy } from "../../contracts/community/CommunityBuilderProxy.sol";
import { WeightedClassFactory, ProjectClassFactory, TokenClassFactory } from "../../contracts/community/CommunityFactory.sol";

contract CommunityBuilderProxyTest is Test {
    CommunityBuilder private _builder;

    function setUp() public {
        _builder = createCommunityBuilder();
    }

    function testProxyCreate() public {
        assertEq(_builder.name(), "community builder");
    }

    function testProxyUpgrade() public {
        WeightedClassFactory _weightedFactory = new WeightedClassFactory();
        ProjectClassFactory _projectFactory = new ProjectClassFactory();
        TokenClassFactory _tokenFactory = new TokenClassFactory();
        address payable _paddr = payable(address(_builder));
        CommunityBuilderProxy _proxy = CommunityBuilderProxy(_paddr);
        CommunityBuilder _cbuilder = new CBuilder2();
        _proxy.upgrade(
            address(_cbuilder),
            address(_weightedFactory),
            address(_projectFactory),
            address(_tokenFactory),
            uint8(_cbuilder.version())
        );
        assertEq(_builder.name(), "test upgrade");
    }

    function testProxyUpgrade2Times() public {
        WeightedClassFactory _weightedFactory = new WeightedClassFactory();
        ProjectClassFactory _projectFactory = new ProjectClassFactory();
        TokenClassFactory _tokenFactory = new TokenClassFactory();
        address payable _paddr = payable(address(_builder));
        CommunityBuilderProxy _proxy = CommunityBuilderProxy(_paddr);
        CommunityBuilder _cbuilder = new CBuilder2();
        _proxy.upgrade(
            address(_cbuilder),
            address(_weightedFactory),
            address(_projectFactory),
            address(_tokenFactory),
            uint8(_cbuilder.version())
        );
        _proxy.upgrade(
            address(_cbuilder),
            address(_weightedFactory),
            address(_projectFactory),
            address(_tokenFactory),
            uint8(_cbuilder.version()+1)
        );
        assertEq(_builder.name(), "test upgrade");
    }

}

contract CBuilder2 is CommunityBuilder {
    function name() external pure virtual override(CommunityBuilder) returns (string memory) {
        return "test upgrade";
    }
}

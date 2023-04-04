// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { CommunityClass } from "../contracts/community/CommunityClass.sol";
import { ProposalBuilder } from "../contracts/ProposalBuilder.sol";
import { createProposalBuilder, ProposalBuilderProxy } from "../contracts/ProposalBuilderProxy.sol";
import { CommunityBuilder } from "../contracts/community/CommunityBuilder.sol";
import { StorageFactory } from "../contracts/storage/StorageFactory.sol";
import { MetaStorageFactory } from "../contracts/storage/MetaStorageFactory.sol";
import { GovernanceFactory } from "../contracts/governance/GovernanceFactory.sol";
import { createCommunityBuilder } from "../contracts/community/CommunityBuilderProxy.sol";
import { GovernanceBuilder } from "../contracts/governance/GovernanceBuilder.sol";
import { createGovernanceBuilder } from "../contracts/governance/GovernanceBuilderProxy.sol";

contract ProposalBuilderProxyTest is Test {
    address private constant _CREATOR = address(0x2);

    CommunityClass private _class;
    ProposalBuilder private _builder;
    GovernanceBuilder private _gbuilder;

    function setUp() public {
        CommunityBuilder _communityBuilder = createCommunityBuilder();
        address _classAddr = _communityBuilder
            .aCommunity()
            .withCommunitySupervisor(_CREATOR)
            .asOpenCommunity()
            .withQuorum(1)
            .build();
        _class = CommunityClass(_classAddr);
        GovernanceFactory _governanceFactory = new GovernanceFactory();
        StorageFactory _storageFactory = new StorageFactory();
        MetaStorageFactory _metaStorageFactory = new MetaStorageFactory();
        _gbuilder = createGovernanceBuilder(_governanceFactory, _storageFactory, _metaStorageFactory);
        (address payable _govAddr, address _stoAddr, address _metaAddr) = _gbuilder
            .aGovernance()
            .withCommunityClassAddress(_classAddr)
            .build();
        _builder = createProposalBuilder(_govAddr, _stoAddr, _metaAddr);
    }

    function testProxyCreate() public {
        assertEq(_builder.name(), "proposal builder");
    }

    function testProxyUpgrade() public {
        address payable _paddr = payable(address(_builder));
        ProposalBuilderProxy _proxy = ProposalBuilderProxy(_paddr);
        address _classAddr = address(_class);
        (address payable _govAddr, address _stoAddr, address _metaAddr) = _gbuilder
            .aGovernance()
            .withCommunityClassAddress(_classAddr)
            .build();
        ProposalBuilder _pbuilder = new PBuilder2();
        _proxy.upgrade(address(_pbuilder), _govAddr, _stoAddr, _metaAddr);
        assertEq(_builder.name(), "test upgrade");
    }
}

contract PBuilder2 is ProposalBuilder {
    function name() external pure virtual override(ProposalBuilder) returns (string memory) {
        return "test upgrade";
    }
}

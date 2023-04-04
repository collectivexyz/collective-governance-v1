// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import { Constant } from "../../contracts/Constant.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";
import { OwnableInitializable } from "../../contracts/access/OwnableInitializable.sol";
import { MetaStorage } from "../../contracts/storage/MetaStorage.sol";
import { MetaStorageFactory } from "../../contracts/storage/MetaStorageFactory.sol";
import { Storage } from "../../contracts/storage/Storage.sol";
import { StorageFactory } from "../../contracts/storage/StorageFactory.sol";
import { GovernanceFactory } from "../../contracts/governance/GovernanceFactory.sol";
import { Governance } from "../../contracts/governance/Governance.sol";
import { CollectiveGovernance } from "../../contracts/governance/CollectiveGovernance.sol";
import { CommunityClass } from "../../contracts/community/CommunityClass.sol";
import { CommunityBuilder } from "../../contracts/community/CommunityBuilder.sol";
import { createCommunityBuilder } from "../../contracts/community/CommunityBuilderProxy.sol";
import { GovernanceBuilder } from "../../contracts/governance/GovernanceBuilder.sol";
import { createGovernanceBuilder } from "../../contracts/governance/GovernanceBuilderProxy.sol";

import { MockERC721 } from "../mock/MockERC721.sol";

contract GovernanceBuilderTest is Test {
    address private constant _OWNER = address(0x1);
    address private constant _OTHER = address(0x2);
    address private constant _SUPERVISOR = address(0x123);
    address private constant _VOTER1 = address(0xfff1);

    GovernanceBuilder private _builder;
    CommunityBuilder private _communityBuilder;

    CommunityClass private _class;

    function setUp() public {
        vm.clearMockedCalls();
        vm.prank(_OWNER, _OWNER);
        GovernanceFactory _governanceFactory = new GovernanceFactory();
        StorageFactory _storageFactory = new StorageFactory();
        MetaStorageFactory _metaStorageFactory = new MetaStorageFactory();
        _builder = createGovernanceBuilder(_governanceFactory, _storageFactory, _metaStorageFactory);
        _communityBuilder = createCommunityBuilder();
        address _communityLocation = _communityBuilder
            .aCommunity()
            .asPoolCommunity()
            .withVoter(_VOTER1)
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        _class = CommunityClass(_communityLocation);
    }

    function testWithSupervisor() public {
        (address payable _governance, address _storage, ) = _builder.aGovernance().withCommunityClass(_class).build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        _gov.propose();
        assertTrue(Storage(_storage).isSupervisor(1, _SUPERVISOR));
    }

    function testWithMinimumVoteDelay() public {
        address _communityLocation = _communityBuilder
            .aCommunity()
            .asPoolCommunity()
            .withVoter(_VOTER1)
            .withMinimumVoteDelay(1 hours)
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        _class = CommunityClass(_communityLocation);
        (address payable _governance, , ) = _builder.aGovernance().withCommunityClass(_class).build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        uint256 proposalId = _gov.propose();
        assertEq(_class.minimumVoteDelay(), 1 hours);
        vm.expectRevert(
            abi.encodeWithSelector(
                Storage.DelayNotPermitted.selector,
                proposalId,
                Constant.MINIMUM_VOTE_DURATION - 1,
                Constant.MINIMUM_VOTE_DURATION
            )
        );
        vm.prank(_VOTER1, _VOTER1);
        _gov.configure(proposalId, 100, 1 hours - 1, Constant.MINIMUM_VOTE_DURATION);
    }

    function testWithMaximumVoteDelay() public {
        address _communityLocation = _communityBuilder
            .aCommunity()
            .asPoolCommunity()
            .withVoter(_VOTER1)
            .withMaximumVoteDelay(1 hours)
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        _class = CommunityClass(_communityLocation);
        (address payable _governance, , ) = _builder.aGovernance().withCommunityClass(_class).build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        uint256 proposalId = _gov.propose();
        assertEq(_class.maximumVoteDelay(), Constant.MINIMUM_VOTE_DURATION);
        vm.expectRevert(
            abi.encodeWithSelector(
                Storage.DelayNotPermitted.selector,
                proposalId,
                Constant.MINIMUM_VOTE_DURATION + 1,
                Constant.MINIMUM_VOTE_DURATION
            )
        );
        vm.prank(_VOTER1, _VOTER1);
        _gov.configure(proposalId, 100, Constant.MINIMUM_VOTE_DURATION + 1, Constant.MINIMUM_VOTE_DURATION);
    }

    function testWithMinimumVoteDuration() public {
        address _communityLocation = _communityBuilder
            .aCommunity()
            .asPoolCommunity()
            .withVoter(_VOTER1)
            .withMinimumVoteDuration(2 * Constant.MINIMUM_VOTE_DURATION)
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        _class = CommunityClass(_communityLocation);
        (address payable _governance, , ) = _builder.aGovernance().withCommunityClass(_class).build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        uint256 proposalId = _gov.propose();
        assertEq(_class.minimumVoteDuration(), 2 * Constant.MINIMUM_VOTE_DURATION);
        vm.expectRevert(
            abi.encodeWithSelector(
                Storage.DurationNotPermitted.selector,
                proposalId,
                Constant.MINIMUM_VOTE_DURATION + 1,
                Constant.MINIMUM_VOTE_DURATION * 2
            )
        );
        vm.prank(_VOTER1, _VOTER1);
        _gov.configure(proposalId, 100, Constant.MINIMUM_VOTE_DELAY, Constant.MINIMUM_VOTE_DURATION + 1);
    }

    function testWithMaximumVoteDuration() public {
        address _communityLocation = _communityBuilder
            .aCommunity()
            .asPoolCommunity()
            .withVoter(_VOTER1)
            .withMaximumVoteDuration(2 * Constant.MINIMUM_VOTE_DURATION)
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        _class = CommunityClass(_communityLocation);
        (address payable _governance, , ) = _builder.aGovernance().withCommunityClass(_class).build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        uint256 proposalId = _gov.propose();
        assertEq(_class.maximumVoteDuration(), 2 * Constant.MINIMUM_VOTE_DURATION);
        vm.expectRevert(
            abi.encodeWithSelector(
                Storage.DurationNotPermitted.selector,
                proposalId,
                Constant.MINIMUM_VOTE_DURATION * 2 + 1,
                Constant.MINIMUM_VOTE_DURATION * 2
            )
        );
        vm.prank(_VOTER1, _VOTER1);
        _gov.configure(proposalId, 100, Constant.MINIMUM_VOTE_DELAY, Constant.MINIMUM_VOTE_DURATION * 2 + 1);
    }

    function testWithOpenVote() public {
        (address payable _governance, address _storage, ) = _builder.aGovernance().withCommunityClass(_class).build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1);
        _gov.propose();
        assertTrue(Storage(_storage).isVoter(1, _VOTER1));
    }

    function testWithVoterPool() public {
        (address payable _governance, address _storage, ) = _builder.aGovernance().withCommunityClass(_class).build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        _gov.propose();
        assertTrue(Storage(_storage).isVoter(1, _VOTER1));
    }

    function testWithERC721() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_VOTER1, 0x10);
        address _communityLocation = _communityBuilder
            .aCommunity()
            .asErc721Community(address(merc721))
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        _class = CommunityClass(_communityLocation);
        (address payable _governance, address _storage, ) = _builder.aGovernance().withCommunityClass(_class).build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        uint256 pid = _gov.propose();
        assertTrue(Storage(_storage).isVoter(pid, _VOTER1));
    }

    function testMetaStoreIsReturned() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_VOTER1, 0x10);
        address _communityLocation = _communityBuilder
            .aCommunity()
            .asErc721Community(address(merc721))
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        _class = CommunityClass(_communityLocation);
        (, , address _metaStore) = _builder.aGovernance().withCommunityClass(_class).build();
        assertTrue(_metaStore != address(0x0));
    }

    function testFailVoterClassIsRequired() public {
        _builder.aGovernance().build();
    }

    function testFailAfterResetBuilder() public {
        _builder.aGovernance().withCommunityClass(_class).build();
        _builder.reset();
        _builder.build();
    }

    function testWithName() public {
        (, , address _meta) = _builder.aGovernance().withCommunityClass(_class).withName("acme inc").build();
        MetaStorage meta = MetaStorage(_meta);
        assertEq(meta.community(), "acme inc");
    }

    function testWithUrl() public {
        (, , address _meta) = _builder.aGovernance().withCommunityClass(_class).withUrl("https://collective.xyz").build();
        MetaStorage meta = MetaStorage(_meta);
        assertEq(meta.url(), "https://collective.xyz");
    }

    function testWithDescription() public {
        string memory desc = "A unique project to build on chain governance for all web3 communities";
        (, , address _meta) = _builder.aGovernance().withCommunityClass(_class).withDescription(desc).build();
        MetaStorage meta = MetaStorage(_meta);
        assertEq(meta.description(), desc);
    }

    function testWithCommmunityDescription() public {
        string memory desc = "A unique project to build on chain governance for all web3 communities";
        (, , address _meta) = _builder
            .aGovernance()
            .withCommunityClass(_class)
            .withDescription("acme inc", "https://collective.xyz", desc)
            .build();
        MetaStorage meta = MetaStorage(_meta);
        assertEq(meta.community(), "acme inc");
        assertEq(meta.url(), "https://collective.xyz");
        assertEq(meta.description(), desc);
    }

    function testSupportsInterfaceOwnable() public {
        bytes4 ifId = type(OwnableInitializable).interfaceId;
        assertTrue(_builder.supportsInterface(ifId));
    }

    function testSupportsIERC165() public {
        bytes4 ifId = type(IERC165).interfaceId;
        assertTrue(_builder.supportsInterface(ifId));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_builder.supportsInterface(ifId));
    }

    function testFailVoterClassAddressMustSupportVoterClassInterface() public {
        address classMock = address(0x0);
        vm.mockCall(classMock, abi.encodeWithSelector(IERC165.supportsInterface.selector), abi.encode(false));
        _builder.withCommunityClassAddress(classMock);
    }

    function testUpgradeRequiresOwner() public {
        GovernanceFactory _governanceFactory = new GovernanceFactory();
        StorageFactory _storageFactory = new StorageFactory();
        MetaStorageFactory _metaStorageFactory = new MetaStorageFactory();
        vm.expectRevert(abi.encodeWithSelector(OwnableInitializable.NotOwner.selector, _OTHER));
        vm.prank(_OTHER, _OTHER);
        _builder.upgrade(
            address(_governanceFactory),
            address(_storageFactory),
            address(_metaStorageFactory),
            uint8(Constant.CURRENT_VERSION)
        );
    }
}

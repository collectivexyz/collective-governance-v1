// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "../contracts/storage/MetaFactoryCreator.sol";
import "../contracts/storage/MetaStorageFactory.sol";
import "../contracts/storage/StorageFactoryCreator.sol";
import "../contracts/storage/StorageFactory.sol";
import "../contracts/GovernanceFactoryCreator.sol";
import "../contracts/GovernanceFactory.sol";

import "../contracts/GovernanceBuilder.sol";
import "../contracts/Governance.sol";
import "../contracts/CollectiveGovernance.sol";
import "../contracts/community/VoterClass.sol";
import "../contracts/community/CommunityClassVoterPool.sol";
import "../contracts/community/CommunityClassERC721.sol";
import "../contracts/community/CommunityClassOpenVote.sol";
import "../contracts/access/Versioned.sol";

import "./MockERC721.sol";

contract GovernanceBuilderTest is Test {
    address private constant _OWNER = address(0x1);
    address private constant _SUPERVISOR = address(0x123);
    address private constant _VOTER1 = address(0xfff1);

    GovernanceBuilder private _builder;

    CommunityClass private _class;

    function setUp() public {
        vm.clearMockedCalls();
        vm.prank(_OWNER, _OWNER);
        _builder = new GovernanceBuilder();
        CommunityClassVoterPool _poolClass = new CommunityClassVoterPool(
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );
        _poolClass.addVoter(_VOTER1);
        _poolClass.makeFinal();
        _class = _poolClass;
    }

    function testWithSupervisor() public {
        (address payable _governance, address _storage, ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withCommunityClass(_class)
            .build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        _gov.propose();
        assertTrue(Storage(_storage).isSupervisor(1, _SUPERVISOR));
    }

    function testWithMinimumVoteDelay() public {
        CommunityClassVoterPool _poolClass = new CommunityClassVoterPool(
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            1 hours,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );
        _poolClass.addVoter(_VOTER1);
        _poolClass.makeFinal();
        _class = _poolClass;
        (address payable _governance, , ) = _builder.aGovernance().withSupervisor(_SUPERVISOR).withCommunityClass(_class).build();
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
        CommunityClassVoterPool _poolClass = new CommunityClassVoterPool(
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            1 hours,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );
        _poolClass.addVoter(_VOTER1);
        _poolClass.makeFinal();
        _class = _poolClass;
        (address payable _governance, , ) = _builder.aGovernance().withSupervisor(_SUPERVISOR).withCommunityClass(_class).build();
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
        CommunityClassVoterPool _poolClass = new CommunityClassVoterPool(
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            2 * Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );
        _poolClass.addVoter(_VOTER1);
        _poolClass.makeFinal();
        _class = _poolClass;
        (address payable _governance, , ) = _builder.aGovernance().withSupervisor(_SUPERVISOR).withCommunityClass(_class).build();
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
        CommunityClassVoterPool _poolClass = new CommunityClassVoterPool(
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            2 * Constant.MINIMUM_VOTE_DURATION
        );
        _poolClass.addVoter(_VOTER1);
        _poolClass.makeFinal();
        _class = _poolClass;
        (address payable _governance, , ) = _builder.aGovernance().withSupervisor(_SUPERVISOR).withCommunityClass(_class).build();
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
        (address payable _governance, address _storage, ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withCommunityClass(_class)
            .build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1);
        _gov.propose();
        assertTrue(Storage(_storage).isVoter(1, _VOTER1));
    }

    function testWithVoterPool() public {
        (address payable _governance, address _storage, ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withCommunityClass(_class)
            .build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        _gov.propose();
        assertTrue(Storage(_storage).isVoter(1, _VOTER1));
    }

    function testWithERC721() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_VOTER1, 0x10);
        _class = new CommunityClassERC721(
            address(merc721),
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );
        (address payable _governance, address _storage, ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withCommunityClass(_class)
            .build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        uint256 pid = _gov.propose();
        assertTrue(Storage(_storage).isVoter(pid, _VOTER1));
    }

    function testMetaStoreIsReturned() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_VOTER1, 0x10);
        _class = new CommunityClassERC721(
            address(merc721),
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );
        (, , address _metaStore) = _builder.aGovernance().withSupervisor(_SUPERVISOR).withCommunityClass(_class).build();
        assertTrue(_metaStore != address(0x0));
    }

    function testFailSupervisorIsRequired() public {
        _builder.aGovernance().withCommunityClass(_class).build();
    }

    function testFailVoterClassIsRequired() public {
        _builder.aGovernance().withSupervisor(_SUPERVISOR).build();
    }

    function testFailAfterResetBuilder() public {
        _builder.aGovernance().withSupervisor(_SUPERVISOR).withCommunityClass(_class).build();
        _builder.reset();
        _builder.build();
    }

    function testWithName() public {
        (address payable _governance, , ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withCommunityClass(_class)
            .withName("acme inc")
            .build();
        Governance gov = Governance(_governance);
        assertEq(gov.community(), "acme inc");
    }

    function testWithUrl() public {
        (address payable _governance, , ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withCommunityClass(_class)
            .withUrl("https://collective.xyz")
            .build();
        Governance gov = Governance(_governance);
        assertEq(gov.url(), "https://collective.xyz");
    }

    function testWithDescription() public {
        string memory desc = "A unique project to build on chain governance for all web3 communities";
        (address payable _governance, , ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withCommunityClass(_class)
            .withDescription(desc)
            .build();
        Governance gov = Governance(_governance);
        assertEq(gov.description(), desc);
    }

    function testWithCommmunityDescription() public {
        string memory desc = "A unique project to build on chain governance for all web3 communities";
        (address payable _governance, , ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withCommunityClass(_class)
            .withDescription("acme inc", "https://collective.xyz", desc)
            .build();
        Governance gov = Governance(_governance);
        assertEq(gov.community(), "acme inc");
        assertEq(gov.url(), "https://collective.xyz");
        assertEq(gov.description(), desc);
    }

    function testWithGasRebate() public {
        (address payable _governance, , ) = _builder
            .aGovernance()
            .withGasRebate(Constant.MAXIMUM_REBATE_GAS_USED + 0x7, Constant.MAXIMUM_REBATE_BASE_FEE + 0x13)
            .withSupervisor(_SUPERVISOR)
            .withCommunityClass(_class)
            .build();
        CollectiveGovernance _gov = CollectiveGovernance(payable(_governance));
        assertEq(_gov._maximumGasUsedRebate(), Constant.MAXIMUM_REBATE_GAS_USED + 0x7);
        assertEq(_gov._maximumBaseFeeRebate(), Constant.MAXIMUM_REBATE_BASE_FEE + 0x13);
    }

    function testFailWithGasRebateGasUsedBelowMinimumRequired() public {
        _builder
            .aGovernance()
            .withGasRebate(Constant.MAXIMUM_REBATE_GAS_USED - 0x1, Constant.MAXIMUM_REBATE_BASE_FEE)
            .withSupervisor(_SUPERVISOR)
            .withCommunityClass(_class)
            .build();
    }

    function testFailWithGasRebateBaseFeeBelowMinimumRequired() public {
        _builder
            .aGovernance()
            .withGasRebate(Constant.MAXIMUM_REBATE_GAS_USED, Constant.MAXIMUM_REBATE_BASE_FEE - 0x1)
            .withSupervisor(_SUPERVISOR)
            .withCommunityClass(_class)
            .build();
    }

    function testSupportsInterfaceGovernanceCreator() public {
        bytes4 govId = type(GovernanceCreator).interfaceId;
        assertTrue(_builder.supportsInterface(govId));
    }

    function testSupportsInterfaceOwnable() public {
        bytes4 ifId = type(Ownable).interfaceId;
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

    function testUpgradeRequiresOwner() public {
        MetaFactoryCreator _meta = new MetaStorageFactory();
        StorageFactoryCreator _storage = new StorageFactory();
        GovernanceFactoryCreator _creator = new GovernanceFactory();
        vm.expectRevert("Ownable: caller is not the owner");
        _builder.upgrade(address(_creator), address(_storage), address(_meta));
    }

    function testUpgradeRequiresMeta() public {
        address _metaAddress = address(0x1);
        vm.mockCall(_metaAddress, abi.encodeWithSelector(IERC165.supportsInterface.selector), abi.encode(false));
        StorageFactoryCreator _storage = new StorageFactory();
        GovernanceFactoryCreator _creator = new GovernanceFactory();
        vm.expectRevert(abi.encodeWithSelector(GovernanceCreator.MetaStorageFactoryRequired.selector, _metaAddress));
        vm.prank(_OWNER, _OWNER);
        _builder.upgrade(address(_creator), address(_storage), _metaAddress);
    }

    function testUpgradeRequiresStorage() public {
        MetaFactoryCreator _meta = new MetaStorageFactory();
        address _storageAddress = address(0x1);
        vm.mockCall(_storageAddress, abi.encodeWithSelector(IERC165.supportsInterface.selector), abi.encode(false));
        GovernanceFactoryCreator _creator = new GovernanceFactory();
        vm.expectRevert(abi.encodeWithSelector(GovernanceCreator.StorageFactoryRequired.selector, _storageAddress));
        vm.prank(_OWNER, _OWNER);
        _builder.upgrade(address(_creator), _storageAddress, address(_meta));
    }

    function testUpgradeRequiresGovernance() public {
        MetaFactoryCreator _meta = new MetaStorageFactory();
        StorageFactoryCreator _storage = new StorageFactory();
        address _governanceAddress = address(0x1);
        vm.mockCall(_governanceAddress, abi.encodeWithSelector(IERC165.supportsInterface.selector), abi.encode(false));
        vm.expectRevert(abi.encodeWithSelector(GovernanceCreator.GovernanceFactoryRequired.selector, _governanceAddress));
        vm.prank(_OWNER, _OWNER);
        _builder.upgrade(_governanceAddress, address(_storage), address(_meta));
    }

    function testFailUpgradeStorageRequiresHigherVersion() public {
        MetaFactoryCreator _meta = new MetaStorageFactory();
        StorageFactoryCreator _storage = new StorageFactory();
        GovernanceFactoryCreator _creator = new GovernanceFactory();
        address creatorMock = address(_creator);
        bytes memory code = creatorMock.code;
        vm.etch(creatorMock, code);
        vm.mockCall(creatorMock, abi.encodeWithSelector(Versioned.version.selector), abi.encode(Constant.VERSION_3 + 1));
        address metaMock = address(_meta);
        bytes memory metacode = metaMock.code;
        vm.etch(metaMock, metacode);
        vm.mockCall(metaMock, abi.encodeWithSelector(Versioned.version.selector), abi.encode(Constant.VERSION_3 + 1));
        vm.prank(_OWNER, _OWNER);
        _builder.upgrade(creatorMock, address(_storage), metaMock);
    }

    function testFailUpgradeMetaRequiresHigherVersion() public {
        MetaFactoryCreator _meta = new MetaStorageFactory();
        StorageFactoryCreator _storage = new StorageFactory();
        GovernanceFactoryCreator _creator = new GovernanceFactory();
        address creatorMock = address(_creator);
        bytes memory code = creatorMock.code;
        vm.etch(creatorMock, code);
        vm.mockCall(creatorMock, abi.encodeWithSelector(Versioned.version.selector), abi.encode(Constant.VERSION_3 + 1));
        address storageMock = address(_storage);
        bytes memory storagecode = storageMock.code;
        vm.etch(storageMock, storagecode);
        vm.mockCall(storageMock, abi.encodeWithSelector(Versioned.version.selector), abi.encode(Constant.VERSION_3 + 1));
        vm.prank(_OWNER, _OWNER);
        _builder.upgrade(creatorMock, storageMock, address(_meta));
    }

    function testFailVoterClassAddressMustSupportVoterClassInterface() public {
        address classMock = address(0x0);
        vm.mockCall(classMock, abi.encodeWithSelector(IERC165.supportsInterface.selector), abi.encode(false));
        _builder.withCommunityClassAddress(classMock);
    }
}

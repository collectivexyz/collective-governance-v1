// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "../contracts/MetaProxyCreator.sol";
import "../contracts/MetaStorageFactory.sol";
import "../contracts/StorageProxyCreator.sol";
import "../contracts/StorageFactory.sol";
import "../contracts/GovernanceProxyCreator.sol";
import "../contracts/GovernanceFactory.sol";

import "../contracts/GovernanceBuilder.sol";
import "../contracts/Governance.sol";
import "../contracts/CollectiveGovernance.sol";
import "../contracts/VoterClass.sol";
import "../contracts/VoterClassVoterPool.sol";
import "../contracts/VoterClassERC721.sol";
import "../contracts/VoterClassOpenVote.sol";
import "../contracts/access/Upgradeable.sol";

import "./MockERC721.sol";

contract GovernanceBuilderTest is Test {
    address private constant _OWNER = address(0x1);
    address private constant _SUPERVISOR = address(0x123);
    address private constant _VOTER1 = address(0xfff1);

    GovernanceBuilder private _builder;

    function setUp() public {
        vm.clearMockedCalls();
        vm.prank(_OWNER, _OWNER);
        _builder = new GovernanceBuilder();
    }

    function testWithSupervisor() public {
        VoterClassVoterPool _class = new VoterClassVoterPool(1);
        _class.addVoter(_VOTER1);
        _class.makeFinal();

        (address payable _governance, address _storage, ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        _gov.propose();
        assertTrue(Storage(_storage).isSupervisor(1, _SUPERVISOR));
    }

    function testWithVoteDuration() public {
        VoterClassVoterPool _class = new VoterClassVoterPool(1);
        _class.addVoter(_VOTER1);
        _class.makeFinal();
        (address payable _governance, address _storage, ) = _builder
            .aGovernance()
            .withMinimumDuration(2 * Constant.MINIMUM_VOTE_DURATION)
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        _gov.propose();
        assertEq(Storage(_storage).minimumVoteDuration(), 2 * Constant.MINIMUM_VOTE_DURATION);
    }

    function testWithoutVoteDurationOrQuorum() public {
        VoterClassVoterPool _class = new VoterClassVoterPool(1);
        _class.addVoter(_VOTER1);
        _class.makeFinal();
        (address payable _governance, address _storage, ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        _gov.propose();
        assertEq(Storage(_storage).minimumVoteDuration(), Constant.MINIMUM_VOTE_DURATION);
        assertEq(Storage(_storage).minimumProjectQuorum(), Constant.MINIMUM_PROJECT_QUORUM);
    }

    function testFailWithVoteDurationNotPermitted() public {
        VoterClass _class = new VoterClassNullObject();
        _builder
            .aGovernance()
            .withMinimumDuration(Constant.MINIMUM_VOTE_DURATION - 1)
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .build();
    }

    function testFailWithQuorumNotPermitted() public {
        VoterClass _class = new VoterClassNullObject();
        _builder
            .aGovernance()
            .withProjectQuorum(Constant.MINIMUM_PROJECT_QUORUM - 1)
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .build();
    }

    function testWithProjectQuorum() public {
        VoterClassVoterPool _class = new VoterClassVoterPool(1);
        _class.addVoter(_VOTER1);
        _class.makeFinal();
        (address payable _governance, address _storage, ) = _builder
            .aGovernance()
            .withProjectQuorum(10000)
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        _gov.propose();
        assertEq(Storage(_storage).minimumProjectQuorum(), 10000);
    }

    function testWithOpenVote() public {
        VoterClass _class = new VoterClassOpenVote(1);
        (address payable _governance, address _storage, ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .build();
        Governance _gov = Governance(_governance);
        _gov.propose();
        assertTrue(Storage(_storage).isVoter(1, _VOTER1));
    }

    function testWithVoterPool() public {
        VoterClassVoterPool _class = new VoterClassVoterPool(1);
        _class.addVoter(_VOTER1);
        _class.makeFinal();
        (address payable _governance, address _storage, ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        _gov.propose();
        assertTrue(Storage(_storage).isVoter(1, _VOTER1));
    }

    function testWithERC721() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_VOTER1, 0x10);
        VoterClass _class = new VoterClassERC721(address(merc721), 1);
        (address payable _governance, address _storage, ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .build();
        Governance _gov = Governance(_governance);
        vm.prank(_VOTER1, _VOTER1);
        uint256 pid = _gov.propose();
        assertTrue(Storage(_storage).isVoter(pid, _VOTER1));
    }

    function testMetaStoreIsReturned() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_VOTER1, 0x10);
        VoterClass _class = new VoterClassERC721(address(merc721), 1);
        (, , address _metaStore) = _builder.aGovernance().withSupervisor(_SUPERVISOR).withVoterClass(_class).build();
        assertTrue(_metaStore != address(0x0));
    }

    function testFailSupervisorIsRequired() public {
        VoterClass _class = new VoterClassNullObject();
        _builder.aGovernance().withVoterClass(_class).build();
    }

    function testFailVoterClassIsRequired() public {
        _builder.aGovernance().withSupervisor(_SUPERVISOR).build();
    }

    function testFailAfterResetBuilder() public {
        VoterClass _class = new VoterClassNullObject();
        _builder.aGovernance().withSupervisor(_SUPERVISOR).withVoterClass(_class).build();
        _builder.reset();
        _builder.build();
    }

    function testWithName() public {
        VoterClass _class = new VoterClassNullObject();
        (address payable _governance, , ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .withName("acme inc")
            .build();
        Governance gov = Governance(_governance);
        assertEq(gov.community(), "acme inc");
    }

    function testWithUrl() public {
        VoterClass _class = new VoterClassNullObject();
        (address payable _governance, , ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .withUrl("https://collective.xyz")
            .build();
        Governance gov = Governance(_governance);
        assertEq(gov.url(), "https://collective.xyz");
    }

    function testWithDescription() public {
        string memory desc = "A unique project to build on chain governance for all web3 communities";
        VoterClass _class = new VoterClassNullObject();
        (address payable _governance, , ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .withDescription(desc)
            .build();
        Governance gov = Governance(_governance);
        assertEq(gov.description(), desc);
    }

    function testWithCommmunityDescription() public {
        string memory desc = "A unique project to build on chain governance for all web3 communities";
        VoterClass _class = new VoterClassNullObject();
        (address payable _governance, , ) = _builder
            .aGovernance()
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .withDescription("acme inc", "https://collective.xyz", desc)
            .build();
        Governance gov = Governance(_governance);
        assertEq(gov.community(), "acme inc");
        assertEq(gov.url(), "https://collective.xyz");
        assertEq(gov.description(), desc);
    }

    function testWithGasRebate() public {
        VoterClass _class = new VoterClassNullObject();
        (address payable _governance, , ) = _builder
            .aGovernance()
            .withGasRebate(Constant.MAXIMUM_REBATE_GAS_USED + 0x7, Constant.MAXIMUM_REBATE_BASE_FEE + 0x13)
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .build();
        CollectiveGovernance _gov = CollectiveGovernance(payable(_governance));
        assertEq(_gov._maximumGasUsedRebate(), Constant.MAXIMUM_REBATE_GAS_USED + 0x7);
        assertEq(_gov._maximumBaseFeeRebate(), Constant.MAXIMUM_REBATE_BASE_FEE + 0x13);
    }

    function testFailWithGasRebateGasUsedBelowMinimumRequired() public {
        VoterClass _class = new VoterClassNullObject();
        _builder
            .aGovernance()
            .withGasRebate(Constant.MAXIMUM_REBATE_GAS_USED - 0x1, Constant.MAXIMUM_REBATE_BASE_FEE)
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .build();
    }

    function testFailWithGasRebateBaseFeeBelowMinimumRequired() public {
        VoterClass _class = new VoterClassNullObject();
        _builder
            .aGovernance()
            .withGasRebate(Constant.MAXIMUM_REBATE_GAS_USED, Constant.MAXIMUM_REBATE_BASE_FEE - 0x1)
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
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

    function testSupportsInterfaceUpgradeable() public {
        bytes4 ifId = type(Upgradeable).interfaceId;
        assertTrue(_builder.supportsInterface(ifId));
    }

    function testUpgradeRequiresOwner() public {
        MetaProxyCreator _meta = new MetaStorageFactory();
        StorageProxyCreator _storage = new StorageFactory();
        GovernanceProxyCreator _creator = new GovernanceFactory();
        vm.expectRevert("Ownable: caller is not the owner");
        _builder.upgrade(address(_creator), address(_storage), address(_meta));
    }

    function testUpgradeRequiresMeta() public {
        address _metaAddress = address(0x1);
        vm.mockCall(_metaAddress, abi.encodeWithSelector(IERC165.supportsInterface.selector), abi.encode(false));
        StorageProxyCreator _storage = new StorageFactory();
        GovernanceProxyCreator _creator = new GovernanceFactory();
        vm.expectRevert(abi.encodeWithSelector(GovernanceCreator.MetaStorageFactoryRequired.selector, _metaAddress));
        vm.prank(_OWNER, _OWNER);
        _builder.upgrade(address(_creator), address(_storage), _metaAddress);
    }

    function testUpgradeRequiresStorage() public {
        MetaProxyCreator _meta = new MetaStorageFactory();
        address _storageAddress = address(0x1);
        vm.mockCall(_storageAddress, abi.encodeWithSelector(IERC165.supportsInterface.selector), abi.encode(false));
        GovernanceProxyCreator _creator = new GovernanceFactory();
        vm.expectRevert(abi.encodeWithSelector(GovernanceCreator.StorageFactoryRequired.selector, _storageAddress));
        vm.prank(_OWNER, _OWNER);
        _builder.upgrade(address(_creator), _storageAddress, address(_meta));
    }

    function testUpgradeRequiresGovernance() public {
        MetaProxyCreator _meta = new MetaStorageFactory();
        StorageProxyCreator _storage = new StorageFactory();
        address _governanceAddress = address(0x1);
        vm.mockCall(_governanceAddress, abi.encodeWithSelector(IERC165.supportsInterface.selector), abi.encode(false));
        vm.expectRevert(abi.encodeWithSelector(GovernanceCreator.GovernanceFactoryRequired.selector, _governanceAddress));
        vm.prank(_OWNER, _OWNER);
        _builder.upgrade(_governanceAddress, address(_storage), address(_meta));
    }

    function testFailUpgradeStorageRequiresHigherVersion() public {
        MetaProxyCreator _meta = new MetaStorageFactory();
        StorageProxyCreator _storage = new StorageFactory();
        GovernanceProxyCreator _creator = new GovernanceFactory();
        address creatorMock = address(_creator);
        bytes memory code = creatorMock.code;
        vm.etch(creatorMock, code);
        vm.mockCall(creatorMock, abi.encodeWithSelector(Upgradeable.version.selector), abi.encode(Constant.VERSION_2 + 1));
        address metaMock = address(_meta);
        bytes memory metacode = metaMock.code;
        vm.etch(metaMock, metacode);
        vm.mockCall(metaMock, abi.encodeWithSelector(Upgradeable.version.selector), abi.encode(Constant.VERSION_2 + 1));
        vm.prank(_OWNER, _OWNER);
        _builder.upgrade(creatorMock, address(_storage), metaMock);
    }

    function testFailUpgradeMetaRequiresHigherVersion() public {
        MetaProxyCreator _meta = new MetaStorageFactory();
        StorageProxyCreator _storage = new StorageFactory();
        GovernanceProxyCreator _creator = new GovernanceFactory();
        address creatorMock = address(_creator);
        bytes memory code = creatorMock.code;
        vm.etch(creatorMock, code);
        vm.mockCall(creatorMock, abi.encodeWithSelector(Upgradeable.version.selector), abi.encode(Constant.VERSION_2 + 1));
        address storageMock = address(_storage);
        bytes memory storagecode = storageMock.code;
        vm.etch(storageMock, storagecode);
        vm.mockCall(storageMock, abi.encodeWithSelector(Upgradeable.version.selector), abi.encode(Constant.VERSION_2 + 1));
        vm.prank(_OWNER, _OWNER);
        _builder.upgrade(creatorMock, storageMock, address(_meta));
    }

    function testFailVoterClassAddressMustSupportVoterClassInterface() public {
        address classMock = address(0x0);
        vm.mockCall(classMock, abi.encodeWithSelector(IERC165.supportsInterface.selector), abi.encode(false));
        _builder.withVoterClassAddress(classMock);
    }
}

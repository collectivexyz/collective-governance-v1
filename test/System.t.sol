// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import { Test } from "forge-std/Test.sol";

import { Constant } from "../contracts/Constant.sol";
import { Governance } from "../contracts/governance/Governance.sol";
import { GovernanceBuilder } from "../contracts/governance/GovernanceBuilder.sol";
import { CommunityBuilder } from "../contracts/community/CommunityBuilder.sol";
import { Storage } from "../contracts/storage/Storage.sol";
import { MetaStorage } from "../contracts/storage/MetaStorage.sol";
import { System } from "../contracts/System.sol";
import { Versioned } from "../contracts/access/Versioned.sol";
import { StorageFactory } from "../contracts/storage/StorageFactory.sol";
import { MetaStorageFactory } from "../contracts/storage/MetaStorageFactory.sol";
import { GovernanceFactory } from "../contracts/governance/GovernanceFactory.sol";

import { MockERC721 } from "./mock/MockERC721.sol";

contract SystemTest is Test {
    address private constant _OWNER = address(0x1);
    address private constant _CREATOR = address(0x2);
    address private constant _VOTER1 = address(0xfff1);

    GovernanceBuilder private _builder;
    CommunityBuilder private _classCreator;

    function setUp() public {
        vm.clearMockedCalls();
        StorageFactory _storageFactory = new StorageFactory();
        MetaStorageFactory _metaStorageFactory = new MetaStorageFactory();
        GovernanceFactory _governanceFactory = new GovernanceFactory();
        _builder = new GovernanceBuilder(address(_storageFactory), address(_metaStorageFactory), address(_governanceFactory));
        _classCreator = new CommunityBuilder();
    }

    function testFailGovernanceBuilderRequired() public {
        address mc = mockNotCompliant();
        address mcc = mockClassCreator();
        new System(mc, mcc);
    }

    function testBuildOutFullProject() public {
        address _builderAddress = address(_builder);
        emit log_address(_builderAddress);
        address _classCreatorAddress = address(_classCreator);
        emit log_address(_classCreatorAddress);
        System _system = new System(_builderAddress, _classCreatorAddress);

        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_VOTER1, 0x10);
        merc721.mintTo(_CREATOR, 0x11);
        vm.prank(_OWNER, _OWNER);
        (address payable _g, address _s, address _m) = _system.create(
            "clxtv",
            "https://github.com/collectivexyz/collective-governance-v1",
            "clxtv governance contract",
            address(merc721),
            1
        );

        Governance _governance = Governance(_g);
        Storage _storage = Storage(_s);
        MetaStorage _meta = MetaStorage(_m);

        assertEq(_meta.community(), "clxtv");
        assertEq(_meta.url(), "https://github.com/collectivexyz/collective-governance-v1");
        assertEq(_meta.description(), "clxtv governance contract");
        vm.prank(_CREATOR, _CREATOR);
        uint256 pid = _governance.propose();
        vm.prank(_CREATOR, _CREATOR);
        _governance.configure(pid, 1, 1 hours, 1 days);
        assertTrue(_storage.isSupervisor(pid, _CREATOR));
        assertTrue(_storage.isSupervisor(pid, _OWNER));
        assertTrue(_storage.isVoter(pid, _VOTER1));
        // 🎉 👯‍♀️ 🎊
    }

    function testBuildWithDuration() public {
        address _builderAddress = address(_builder);
        emit log_address(_builderAddress);
        address _classCreatorAddress = address(_classCreator);
        emit log_address(_classCreatorAddress);
        System _system = new System(_builderAddress, _classCreatorAddress);

        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_VOTER1, 0x10);
        merc721.mintTo(_CREATOR, 0x11);
        vm.prank(_OWNER, _OWNER);
        (address payable _g, address _s, ) = _system.create(
            "clxtv",
            "https://github.com/collectivexyz/collective-governance-v1",
            "clxtv governance contract",
            address(merc721),
            1,
            1,
            true
        );

        Governance _governance = Governance(_g);
        Storage _storage = Storage(_s);
        vm.prank(_CREATOR, _CREATOR);
        uint256 pid = _governance.propose();
        vm.prank(_CREATOR, _CREATOR);
        _governance.configure(pid, 1, 300, 3600);
        assertTrue(_storage.isFinal(pid));
    }

    function testFailBadVersion() public {
        address mc = mockCreator(Constant.CURRENT_VERSION - 1);
        address mcc = mockClassCreator();
        new System(mc, mcc);
    }

    function testFailVersionMismatch() public {
        address mc = mockCreator(Constant.CURRENT_VERSION);
        address mcc = mockClassCreator(Constant.CURRENT_VERSION + 1);
        new System(mc, mcc);
    }

    function testUpgradeOnlyOnwer() public {
        address mc = mockCreator();
        address mcc = mockClassCreator();
        vm.prank(_OWNER, _OWNER);
        System system = new System(mc, mcc);
        vm.expectRevert("Ownable: caller is not the owner");
        system.upgrade(mc, mcc);
    }

    function testUpgradeBadVersion() public {
        address mc = mockCreator(Constant.CURRENT_VERSION);
        address mcc = mockClassCreator();
        System system = new System(mc, mcc);
        address downrevCreator = mockCreator(Constant.CURRENT_VERSION - 1);
        vm.expectRevert(
            abi.encodeWithSelector(System.VersionMismatch.selector, Constant.CURRENT_VERSION, Constant.CURRENT_VERSION - 1)
        );
        system.upgrade(downrevCreator, mcc);
    }

    function testForwardUpgradeAllowed() public {
        address mc = mockCreator();
        address mcc = mockClassCreator();
        System system = new System(mc, mcc);
        system.upgrade(mc, mcc);
    }

    function mockCreator() private returns (address) {
        return mockCreator(Constant.CURRENT_VERSION);
    }

    function mockCreator(uint256 version) private returns (address) {
        address mock = address(0x100);
        vm.mockCall(mock, abi.encodeWithSelector(IERC165.supportsInterface.selector), abi.encode(true));
        vm.mockCall(mock, abi.encodeWithSelector(Versioned.version.selector), abi.encode(version));
        GovernanceBuilder eMock = GovernanceBuilder(mock);
        assertTrue(eMock.supportsInterface(type(Versioned).interfaceId));
        return mock;
    }

    function mockClassCreator() private returns (address) {
        return mockClassCreator(Constant.CURRENT_VERSION);
    }

    function mockClassCreator(uint256 version) private returns (address) {
        address mock = address(0x200);
        vm.mockCall(mock, abi.encodeWithSelector(IERC165.supportsInterface.selector), abi.encode(true));
        vm.mockCall(mock, abi.encodeWithSelector(Versioned.version.selector), abi.encode(version));
        CommunityBuilder eMock = CommunityBuilder(mock);
        assertTrue(eMock.supportsInterface(type(Versioned).interfaceId));
        return mock;
    }

    function mockNotCompliant() private returns (address) {
        address mock = address(0x300);
        vm.mockCall(mock, abi.encodeWithSelector(IERC165.supportsInterface.selector), abi.encode(false));
        vm.mockCall(mock, abi.encodeWithSelector(Versioned.version.selector), abi.encode(0));
        return mock;
    }
}

// solhint-disable-next-line no-empty-blocks
contract Mock165 is ERC165 {

}

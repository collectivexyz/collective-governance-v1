// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "forge-std/Test.sol";

import "../contracts/GovernanceCreator.sol";
import "../contracts/GovernanceBuilder.sol";
import "../contracts/community/CommunityBuilder.sol";
import "../contracts/storage/Storage.sol";
import "../contracts/System.sol";
import "../contracts/access/Versioned.sol";

import "./MockERC721.sol";

contract SystemTest is Test {
    address private constant _OWNER = address(0x1);
    address private constant _CREATOR = address(0x2);
    address private constant _VOTER1 = address(0xfff1);

    GovernanceCreator private _creator;
    CommunityBuilder private _classCreator;

    function setUp() public {
        vm.clearMockedCalls();
        _creator = new GovernanceBuilder();
        _classCreator = new CommunityBuilder();
    }

    function testFailGovernanceCreatorRequired() public {
        address mc = mockNotCompliant();
        address mcc = mockClassCreator();
        new System(mc, mcc);
    }

    function testBuildOutFullProject() public {
        address _creatorAddress = address(_creator);
        emit log_address(_creatorAddress);
        address _classCreatorAddress = address(_classCreator);
        emit log_address(_classCreatorAddress);
        System _system = new System(_creatorAddress, _classCreatorAddress);

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
        address _creatorAddress = address(_creator);
        emit log_address(_creatorAddress);
        address _classCreatorAddress = address(_classCreator);
        emit log_address(_classCreatorAddress);
        System _system = new System(_creatorAddress, _classCreatorAddress);

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
        address mc = mockCreator(Constant.VERSION_3 - 1);
        address mcc = mockClassCreator();
        new System(mc, mcc);
    }

    function testFailVersionMismatch() public {
        address mc = mockCreator(Constant.VERSION_3);
        address mcc = mockClassCreator(Constant.VERSION_3 + 1);
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
        address mc = mockCreator(Constant.VERSION_3);
        address mcc = mockClassCreator();
        System system = new System(mc, mcc);
        address downrevCreator = mockCreator(Constant.VERSION_3 - 1);
        vm.expectRevert(abi.encodeWithSelector(System.VersionMismatch.selector, Constant.VERSION_3, Constant.VERSION_3 - 1));
        system.upgrade(downrevCreator, mcc);
    }

    function testForwardUpgradeAllowed() public {
        address mc = mockCreator();
        address mcc = mockClassCreator();
        System system = new System(mc, mcc);
        system.upgrade(mc, mcc);
    }

    function mockCreator() private returns (address) {
        return mockCreator(Constant.VERSION_3);
    }

    function mockCreator(uint256 version) private returns (address) {
        address mock = address(0x100);
        bytes4 ifId = type(GovernanceCreator).interfaceId;
        vm.mockCall(mock, abi.encodeWithSelector(IERC165.supportsInterface.selector, ifId), abi.encode(true));
        vm.mockCall(mock, abi.encodeWithSelector(Versioned.version.selector), abi.encode(version));
        GovernanceCreator eMock = GovernanceCreator(mock);
        assertTrue(eMock.supportsInterface(ifId));
        return mock;
    }

    function mockClassCreator() private returns (address) {
        return mockClassCreator(Constant.VERSION_3);
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

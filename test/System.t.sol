// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "forge-std/Test.sol";

import "../contracts/GovernanceCreator.sol";
import "../contracts/GovernanceBuilder.sol";
import "../contracts/VoterClassCreator.sol";
import "../contracts/VoterClassFactory.sol";
import "../contracts/Storage.sol";
import "../contracts/System.sol";

import "./MockERC721.sol";

contract SystemTest is Test {
    address private constant _VOTER1 = address(0xfff1);

    GovernanceCreator private _creator;
    VoterClassCreator private _classCreator;

    function setUp() public {
        vm.clearMockedCalls();
        _creator = new GovernanceBuilder();
        _classCreator = new VoterClassFactory();
    }

    function testFailGovernanceCreatorRequired() public {
        address mc = mockNotCompliant();
        address mcc = mockClassCreator();
        new System(mc, mcc);
    }

    function testFailVoterClassCreatorRequired() public {
        address mc = mockCreator();
        address mcc = mockNotCompliant();
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
        uint256 pid = _governance.propose();
        assertTrue(_storage.isVoter(pid, _VOTER1));
        // 🎉 👯‍♀️ 🎊
    }

    function mockCreator() private returns (address) {
        address mock = address(0);
        bytes4 ifId = type(GovernanceCreator).interfaceId;
        vm.mockCall(mock, abi.encodeWithSelector(IERC165.supportsInterface.selector, ifId), abi.encode(true));
        GovernanceCreator eMock = GovernanceCreator(mock);
        assertTrue(eMock.supportsInterface(ifId));
        return mock;
    }

    function mockClassCreator() private returns (address) {
        address mock = address(1);
        bytes4 ifId = type(VoterClassCreator).interfaceId;
        vm.mockCall(mock, abi.encodeWithSelector(IERC165.supportsInterface.selector, ifId), abi.encode(true));
        VoterClassCreator eMock = VoterClassCreator(mock);
        assertTrue(eMock.supportsInterface(ifId));
        return mock;
    }

    function mockNotCompliant() private returns (address) {
        address mock = address(3);
        vm.mockCall(mock, abi.encodeWithSelector(IERC165.supportsInterface.selector), abi.encode(false));
        return mock;
    }
}

// solhint-disable-next-line no-empty-blocks
contract Mock165 is ERC165 {

}

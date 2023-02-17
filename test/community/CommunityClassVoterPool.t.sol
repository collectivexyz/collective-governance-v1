// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable var-name-mixedcase
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../../contracts/community/CommunityBuilder.sol";
import "../../contracts/access/Versioned.sol";

contract CommunityClassVoterPoolTest is Test {
    address private immutable _VOTER = address(0xffeeeeff);
    address private immutable _NOTVOTER = address(0x55);
    address private immutable _NOBODY = address(0x0);

    CommunityClass private _class;

    function setUp() public {
        CommunityBuilder _builder = new CommunityBuilder();
        address _classLocation = _builder.asPoolCommunity().withVoter(_VOTER).build();
        _class = CommunityClass(_classLocation);
    }

    function testOpenToMemberPropose() public {
        assertTrue(_class.canPropose(_VOTER));
    }

    function testClosedToPropose() public {
        assertFalse(_class.canPropose(_NOTVOTER));
    }

    function testFailEmptyCommunity() public {
        CommunityClassVoterPool _emptyClass = new CommunityClassVoterPool();
        _emptyClass.makeFinal();
    }

    function testDiscoverVoter() public {
        uint256[] memory shareList = _class.discover(_VOTER);
        assertEq(shareList.length, 1);
        assertEq(uint160(_VOTER), shareList[0]);
    }

    function testRemoveVoter() public {
        CommunityClassVoterPool _editClass = new CommunityClassVoterPool();
        assertTrue(_editClass.isVoter(_VOTER));
        _editClass.removeVoter(_VOTER);
        assertFalse(_editClass.isVoter(_VOTER));
        assertEq(_editClass.confirm(_VOTER, uint160(_VOTER)), 0);
    }

    function testFailRemoveVoter() public {
        CommunityClassVoterPool _pool = CommunityClassVoterPool(address(_class));
        _pool.removeVoter(_VOTER);
    }

    function testFailDiscoverNonVoter() public view {
        _class.discover(_NOTVOTER);
    }

    function testConfirmVoter() public {
        uint256 shareCount = _class.confirm(_VOTER, uint160(_VOTER));
        assertEq(shareCount, 1);
    }

    function testConfirmVoterIfNotAdded() public {
        vm.expectRevert(abi.encodeWithSelector(VoterClass.NotVoter.selector, _NOTVOTER));
        vm.prank(_NOTVOTER);
        _class.confirm(_NOTVOTER, uint160(_NOTVOTER));
    }

    function testFailMakeFinalNotOwner() public {
        CommunityClassVoterPool _editClass = new CommunityClassVoterPool();
        _editClass.addVoter(_VOTER);
        vm.prank(_VOTER);
        _editClass.makeFinal();
    }

    function testFailConfirmNotFinal() public {
        _class.confirm(_VOTER, uint160(_VOTER));
    }

    function testFailAddVoterByVoter() public {
        CommunityClassVoterPool _editClass = new CommunityClassVoterPool();
        vm.prank(_VOTER);
        _editClass.addVoter(_VOTER);
    }

    function testFailAddVoterByNobody() public {
        CommunityClassVoterPool _editClass = new CommunityClassVoterPool();
        vm.prank(_NOBODY);
        _editClass.addVoter(_NOBODY);
    }

    function testFailDuplicateVoter() public {
        CommunityClassVoterPool _editClass = new CommunityClassVoterPool();
        _editClass.addVoter(_VOTER);
        _editClass.addVoter(_VOTER);
    }

    function testFailAddIfFinal() public {
        CommunityClassVoterPool _pool = CommunityClassVoterPool(address(_class));
        _pool.addVoter(_NOTVOTER);
    }

    function testMakeFinal() public {
        assertTrue(_class.isFinal());
    }

    function testFailRemoveIfFinal() public {
        CommunityClassVoterPool _pool = CommunityClassVoterPool(address(_class));
        _pool.removeVoter(_VOTER);
    }

    function testSupportsInterface() public {
        IERC165 _erc165 = IERC165(address(_class));
        assertTrue(_erc165.supportsInterface(type(VoterPool).interfaceId));
        assertTrue(_erc165.supportsInterface(type(VoterClass).interfaceId));
        assertTrue(_erc165.supportsInterface(type(CommunityClass).interfaceId));
        assertTrue(_erc165.supportsInterface(type(Mutable).interfaceId));
        assertTrue(_erc165.supportsInterface(type(Ownable).interfaceId));
        assertTrue(_erc165.supportsInterface(type(IERC165).interfaceId));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_class.supportsInterface(ifId));
    }

    function testName() public {
        assertEq("CommunityClassVoterPool", _class.name());
    }
}

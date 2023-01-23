// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable var-name-mixedcase
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../../contracts/community/CommunityClassVoterPool.sol";
import "../../contracts/access/Versioned.sol";

contract CommunityClassVoterPoolTest is Test {
    address private immutable _VOTER = address(0xffeeeeff);
    address private immutable _NOTVOTER = address(0x55);
    address private immutable _NOBODY = address(0x0);

    CommunityClassVoterPool private _class;

    function setUp() public {
        _class = new CommunityClassVoterPool(
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );
    }

    function testOpenToMemberPropose() public {
        _class.addVoter(_VOTER);
        _class.makeFinal();
        assertTrue(_class.canPropose(_VOTER));
    }

    function testClosedToPropose() public {
        _class.addVoter(_VOTER);
        _class.makeFinal();
        assertFalse(_class.canPropose(_NOTVOTER));
    }

    function testFailEmptyClass() public {
        _class.makeFinal();
    }

    function testDiscoverVoter() public {
        _class.addVoter(_VOTER);
        _class.makeFinal();
        uint256[] memory shareList = _class.discover(_VOTER);
        assertEq(shareList.length, 1);
        assertEq(uint160(_VOTER), shareList[0]);
    }

    function testRemoveVoter() public {
        _class.addVoter(_VOTER);
        assertTrue(_class.isVoter(_VOTER));
        _class.removeVoter(_VOTER);
        assertFalse(_class.isVoter(_VOTER));
    }

    function testFailRemoveVoter() public {
        _class.addVoter(_VOTER);
        assertTrue(_class.isVoter(_VOTER));
        _class.removeVoter(_VOTER);
        _class.makeFinal();
        assertEq(_class.confirm(_VOTER, uint160(_VOTER)), 0);
    }

    function testFailDiscoverNonVoter() public {
        _class.addVoter(_VOTER);
        _class.makeFinal();
        _class.discover(_NOTVOTER);
    }

    function testConfirmVoter() public {
        _class.addVoter(_VOTER);
        _class.makeFinal();
        uint256 shareCount = _class.confirm(_VOTER, uint160(_VOTER));
        assertEq(shareCount, 1);
    }

    function testFailConfirmVoter() public {
        _class.makeFinal();
        vm.prank(_VOTER);
        _class.confirm(_VOTER, uint160(_VOTER));
    }

    function testFailConfirmNotVoter() public {
        _class.makeFinal();
        _class.confirm(_NOTVOTER, uint160(_NOTVOTER));
    }

    function testFailMakeFinalNotOwner() public {
        vm.prank(_VOTER);
        _class.makeFinal();
    }

    function testFailConfirmNotFinal() public view {
        _class.confirm(_VOTER, uint160(_VOTER));
    }

    function testFailAddVoterByVoter() public {
        vm.prank(_VOTER);
        _class.addVoter(_VOTER);
    }

    function testFailAddVoterByNobody() public {
        vm.prank(_NOBODY);
        _class.addVoter(_NOBODY);
    }

    function testFailAddIfFinal() public {
        _class.makeFinal();
        _class.addVoter(_VOTER);
    }

    function testFailRemoveIfFinal() public {
        _class.addVoter(_VOTER);
        _class.makeFinal();
        _class.removeVoter(_VOTER);
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

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/VoterClassVoterPool.sol";
import "../contracts/access/Upgradeable.sol";

contract VoterClassVoterPoolTest is Test {
    address private immutable _voter = address(0xffeeeeff);
    address private immutable _notvoter = address(0x55);
    address private immutable _nobody = address(0x0);

    VoterClassVoterPool private _class;

    function setUp() public {
        _class = new VoterClassVoterPool(1);
    }

    function testFailEmptyClass() public {
        _class.makeFinal();
    }

    function testDiscoverVoter() public {
        _class.addVoter(_voter);
        _class.makeFinal();
        uint256[] memory shareList = _class.discover(_voter);
        assertEq(shareList.length, 1);
        assertEq(uint160(_voter), shareList[0]);
    }

    function testRemoveVoter() public {
        _class.addVoter(_voter);
        assertTrue(_class.isVoter(_voter));
        _class.removeVoter(_voter);
        assertFalse(_class.isVoter(_voter));
    }

    function testFailRemoveVoter() public {
        _class.addVoter(_voter);
        assertTrue(_class.isVoter(_voter));
        _class.removeVoter(_voter);
        _class.makeFinal();
        assertEq(_class.confirm(_voter, uint160(_voter)), 0);
    }

    function testFailDiscoverNonVoter() public {
        _class.addVoter(_voter);
        _class.makeFinal();
        _class.discover(_notvoter);
    }

    function testConfirmVoter() public {
        _class.addVoter(_voter);
        _class.makeFinal();
        uint256 shareCount = _class.confirm(_voter, uint160(_voter));
        assertEq(shareCount, 1);
    }

    function testFailConfirmVoter() public {
        _class.makeFinal();
        vm.prank(_voter);
        _class.confirm(_voter, uint160(_voter));
    }

    function testFailConfirmNotVoter() public {
        _class.makeFinal();
        _class.confirm(_notvoter, uint160(_notvoter));
    }

    function testFailMakeFinalNotOwner() public {
        vm.prank(_voter);
        _class.makeFinal();
    }

    function testFailConfirmNotFinal() public view {
        _class.confirm(_voter, uint160(_voter));
    }

    function testFailAddVoterByVoter() public {
        vm.prank(_voter);
        _class.addVoter(_voter);
    }

    function testFailAddVoterByNobody() public {
        vm.prank(_nobody);
        _class.addVoter(_nobody);
    }

    function testFailAddIfFinal() public {
        _class.makeFinal();
        _class.addVoter(_voter);
    }

    function testFailRemoveIfFinal() public {
        _class.addVoter(_voter);
        _class.makeFinal();
        _class.removeVoter(_voter);
    }

    function testSupportsInterface() public {
        IERC165 _erc165 = IERC165(address(_class));
        assertTrue(_erc165.supportsInterface(type(VoterPool).interfaceId));
        assertTrue(_erc165.supportsInterface(type(VoterClass).interfaceId));
        assertTrue(_erc165.supportsInterface(type(Mutable).interfaceId));
        assertTrue(_erc165.supportsInterface(type(Ownable).interfaceId));
        assertTrue(_erc165.supportsInterface(type(IERC165).interfaceId));
    }

    function testSupportsInterfaceUpgradeable() public {
        bytes4 ifId = type(Upgradeable).interfaceId;
        assertTrue(_class.supportsInterface(ifId));
    }
}

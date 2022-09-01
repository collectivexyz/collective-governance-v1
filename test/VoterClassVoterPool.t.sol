// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/VoterClassVoterPool.sol";

contract VoterClassVoterPoolTest is Test {
    address immutable _voter = address(0xffeeeeff);
    address immutable _notvoter = address(0x55);
    address immutable _nobody = address(0x0);

    VoterClassVoterPool _class;

    function setUp() public {
        _class = new VoterClassVoterPool(1);
    }

    function testDiscoverVoter() public {
        _class.addVoter(_voter);
        uint256[] memory shareList = _class.discover(_voter);
        assertEq(shareList.length, 1);
        assertEq(uint160(_voter), shareList[0]);
    }

    function testFailDiscoverNonVoter() public {
        _class.addVoter(_voter);
        _class.discover(_notvoter);
    }

    function testConfirmVoter() public {
        _class.addVoter(_voter);
        uint256 shareCount = _class.confirm(_voter, uint160(_voter));
        assertEq(shareCount, 1);
    }

    function testFailConfirmVoter() public {
        vm.prank(_voter);
        _class.confirm(_voter, uint160(_voter));
    }

    function testFailVoterDoubleVote() public {
        _class.confirm(_voter, uint160(_voter));
        _class.confirm(_voter, uint160(_voter));
    }

    function testFailConfirmNotVoter() public {
        _class.confirm(_notvoter, uint160(_notvoter));
    }

    function testFailAddVoterByVoter() public {
        vm.prank(_voter);
        _class.addVoter(_voter);
    }

    function testFailAddVoterByNobody() public {
        vm.prank(_nobody);
        _class.addVoter(_nobody);
    }
}

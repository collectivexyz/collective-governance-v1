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

    function testIsVoter() public {
        _class.addVoter(_voter);
        assertTrue(_class.isVoter(_voter));
        assertFalse(_class.isVoter(_notvoter));
    }

    function testVotesAvailable() public {
        _class.addVoter(_voter);
        assertEq(_class.votesAvailable(_voter), 1);
        assertEq(_class.votesAvailable(_notvoter), 0);
    }

    function testFailIsVoterValidAddressRequired() public view {
        _class.isVoter(_nobody);
    }

    function testFailVotesAvailableValidAddressRequired() public view {
        _class.votesAvailable(_nobody);
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

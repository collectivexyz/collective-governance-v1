// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable var-name-mixedcase
pragma solidity ^0.8.15;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

import { Test } from "forge-std/Test.sol";

import { Mutable } from "../../contracts/access/Mutable.sol";
import { VoterClass } from "../../contracts/community/VoterClass.sol";
import { CommunityClass } from "../../contracts/community/CommunityClass.sol";
import { WeightedCommunityClass } from "../../contracts/community/CommunityClass.sol";
import { CommunityBuilder } from "../../contracts/community/CommunityBuilder.sol";
import { createCommunityBuilder } from "../../contracts/community/CommunityBuilderProxy.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";

contract CommunityClassOpenVoteTest is Test {
    address private immutable _OWNER = address(0xffeeeeff);
    address private immutable _NOTOWNER = address(0x55);
    address private immutable _SUPERVISOR = address(0x1234);

    WeightedCommunityClass private _class;

    function setUp() public {
        CommunityBuilder _builder = createCommunityBuilder();
        address _classAddress = _builder
            .aCommunity()
            .asOpenCommunity()
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        _class = WeightedCommunityClass(_classAddress);
    }

    function testOpenToPropose() public {
        assertTrue(_class.canPropose(_OWNER));
        assertTrue(_class.canPropose(_NOTOWNER));
    }

    function testDiscoverVoteOwner() public {
        uint256[] memory shareList = _class.discover(_OWNER);
        assertEq(shareList.length, 1);
        assertEq(uint160(_OWNER), shareList[0]);
    }

    function testDiscoverVoteNotOwner() public {
        uint256[] memory shareList = _class.discover(_NOTOWNER);
        assertEq(shareList.length, 1);
        assertEq(uint160(_NOTOWNER), shareList[0]);
    }

    function testConfirmOwner() public {
        uint256 shareCount = _class.confirm(_OWNER, uint160(_OWNER));
        assertEq(shareCount, 1);
    }

    function testFailConfirmWrongId() public {
        _class.confirm(_OWNER, uint160(_NOTOWNER));
    }

    function testConfirmNotOwner() public {
        uint256 shareCount = _class.confirm(_NOTOWNER, uint160(_NOTOWNER));
        assertEq(shareCount, 1);
    }

    function testWeight() public {
        assertEq(1, _class.weight());
    }

    function testFinal() public {
        assertTrue(_class.isFinal());
    }

    function testSupportsInterface() public {
        IERC165 _erc165 = IERC165(address(_class));
        assertTrue(_erc165.supportsInterface(type(CommunityClass).interfaceId));
        assertTrue(_erc165.supportsInterface(type(VoterClass).interfaceId));
        assertTrue(_erc165.supportsInterface(type(Mutable).interfaceId));
        assertTrue(_erc165.supportsInterface(type(IERC165).interfaceId));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_class.supportsInterface(ifId));
    }

    function testName() public {
        assertEq("CommunityClassOpenVote", _class.name());
    }
}

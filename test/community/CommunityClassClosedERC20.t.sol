// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20PresetFixedSupply } from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

import { Test } from "forge-std/Test.sol";

import { Mutable } from "../../contracts/access/Mutable.sol";
import { VoterClass } from "../../contracts/community/VoterClass.sol";
import { WeightedCommunityClass } from "../../contracts/community/CommunityClass.sol";
import { CommunityBuilder } from "../../contracts/community/CommunityBuilder.sol";
import { createCommunityBuilder } from "../../contracts/community/CommunityBuilderProxy.sol";
import { CommunityClassClosedERC20 } from "../../contracts/community/CommunityClassClosedERC20.sol";

import { Versioned } from "../../contracts/access/Versioned.sol";

contract CommunityClassClosedERC20Test is Test {
    address private constant _OWNER = address(0xffeeeeff);
    address private constant _NOTOWNER = address(0x55);
    address private constant _PARTOWNER = address(0x56);
    address private constant _SUPERVISOR = address(0x1234);
    uint256 private constant _NTOKEN = 10000;

    ERC20PresetFixedSupply private _tokenContract;
    WeightedCommunityClass private _class;
    CommunityBuilder private _builder;

    function setUp() public {
        _tokenContract = new ERC20PresetFixedSupply("TestToken", "TT20", _NTOKEN, _OWNER);
        _builder = createCommunityBuilder();
        address _classAddress = _builder
            .aCommunity()
            .asClosedErc20Community(address(_tokenContract), _NTOKEN / 2)
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        _class = WeightedCommunityClass(_classAddress);
    }

    function testOpenToMemberPropose() public {
        assertTrue(_class.canPropose(_OWNER));
    }

    function testClosedToPartOwner() public {
        vm.prank(_OWNER);
        _tokenContract.transfer(_PARTOWNER, _NTOKEN / 2 - 1);
        assertFalse(_class.canPropose(_PARTOWNER));
    }

    function testClosedToPropose() public {
        assertFalse(_class.canPropose(_NOTOWNER));
    }

    function testFinal() public {
        assertTrue(_class.isFinal());
    }

    function testName() public {
        assertEq("CommunityClassERC20", _class.name());
    }
}

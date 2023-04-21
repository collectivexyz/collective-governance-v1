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
import { CommunityClassERC20 } from "../../contracts/community/CommunityClassERC20.sol";

import { Versioned } from "../../contracts/access/Versioned.sol";

contract CommunityClassERC20Test is Test {
    address private constant _OWNER = address(0xffeeeeff);
    address private constant _NOTOWNER = address(0x55);
    address private constant _SUPERVISOR = address(0x1234);
    uint256 private constant _NTOKEN = 10000;

    IERC20 private _tokenContract;
    WeightedCommunityClass private _class;
    CommunityBuilder private _builder;

    function setUp() public {
        _tokenContract = new ERC20PresetFixedSupply("TestToken", "TT20", _NTOKEN, _OWNER);
        _builder = createCommunityBuilder();
        address _classAddress = _builder
            .aCommunity()
            .asErc20Community(address(_tokenContract))
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        _class = WeightedCommunityClass(_classAddress);
    }

    function testDiscoveryNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(VoterClass.NotVoter.selector, _NOTOWNER));
        _class.discover(_NOTOWNER);
    }

    function testDiscoveryOwner() public {
        uint256[] memory tokens = _class.discover(_OWNER);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], _NTOKEN);
    }

    function testConfirmOwner() public {
        uint256 _count = _class.confirm(_OWNER, _NTOKEN);
        assertEq(_count, _NTOKEN);
    }

    function testConfirmNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(VoterClass.NotVoter.selector, _NOTOWNER));
        _class.confirm(_NOTOWNER, _NTOKEN);
    }

    function testOpenToPropose() public {
        assertTrue(_class.canPropose(_NOTOWNER));
    }

    function testWeight() public {
        assertEq(1, _class.weight());
    }

    function testFinal() public {
        assertTrue(_class.isFinal());
    }

    function testSupportsInterface() public {
        IERC165 _erc165 = IERC165(address(_class));
        assertTrue(_erc165.supportsInterface(type(VoterClass).interfaceId));
        assertTrue(_erc165.supportsInterface(type(Mutable).interfaceId));
        assertTrue(_erc165.supportsInterface(type(IERC165).interfaceId));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_class.supportsInterface(ifId));
    }

    function testName() public {
        assertEq("CommunityClassERC20", _class.name());
    }
}

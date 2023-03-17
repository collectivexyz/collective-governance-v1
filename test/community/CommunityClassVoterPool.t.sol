// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable var-name-mixedcase
pragma solidity ^0.8.15;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

import { Test } from "forge-std/Test.sol";

import { Constant } from "../../contracts/Constant.sol";
import { Mutable } from "../../contracts/access/Mutable.sol";
import { AddressCollection, AddressSet } from "../../contracts/collection/AddressSet.sol";
import { VoterClass } from "../../contracts/community/VoterClass.sol";
import { CommunityClass } from "../../contracts/community/CommunityClass.sol";
import { VoterPool, CommunityClassVoterPool } from "../../contracts/community/CommunityClassVoterPool.sol";
import { WeightedClassFactory } from "../../contracts/community/CommunityFactory.sol";
import { CommunityBuilder } from "../../contracts/community/CommunityBuilder.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";

contract CommunityClassVoterPoolTest is Test {
    address private immutable _VOTER = address(0xffeeeeff);
    address private immutable _VOTER1 = address(0xffeeeeee);
    address private immutable _NOTVOTER = address(0x55);
    address private immutable _NOBODY = address(0x0);
    address private immutable _SUPERVISOR = address(0x1234);

    CommunityClass private _class;
    AddressCollection private _supervisorSet;

    function setUp() public {
        CommunityBuilder _builder = new CommunityBuilder();
        address _classLocation = _builder
            .aCommunity()
            .asPoolCommunity()
            .withCommunitySupervisor(_SUPERVISOR)
            .withVoter(_VOTER)
            .withQuorum(1)
            .build();
        _class = CommunityClass(_classLocation);
        _supervisorSet = new AddressSet();
        _supervisorSet.add(_SUPERVISOR);
    }

    function testOpenToMemberPropose() public {
        assertTrue(_class.canPropose(_VOTER));
    }

    function testClosedToPropose() public {
        assertFalse(_class.canPropose(_NOTVOTER));
    }

    function testEmptyCommunity() public {
        WeightedClassFactory _factory = new WeightedClassFactory();
        CommunityClassVoterPool _pool = _factory.createVoterPool(
            1,
            1,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        vm.expectRevert(abi.encodeWithSelector(VoterClass.EmptyCommunity.selector));
        _pool.makeFinal();
    }

    function testDiscoverVoter() public {
        uint256[] memory shareList = _class.discover(_VOTER);
        assertEq(shareList.length, 1);
        assertEq(uint160(_VOTER), shareList[0]);
    }

    function testRemoveVoter() public {
        WeightedClassFactory _factory = new WeightedClassFactory();
        CommunityClassVoterPool _pool = _factory.createVoterPool(
            1,
            1,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        _pool.addVoter(_VOTER);
        _pool.addVoter(_VOTER1);
        assertTrue(_pool.isVoter(_VOTER));
        _pool.removeVoter(_VOTER);
        _pool.makeFinal();
        assertFalse(_pool.isVoter(_VOTER));
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
        WeightedClassFactory _factory = new WeightedClassFactory();
        CommunityClassVoterPool _pool = _factory.createVoterPool(
            1,
            1,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        _pool.addVoter(_VOTER);
        vm.prank(_VOTER);
        _pool.makeFinal();
    }

    function testFailConfirmNotFinal() public {
        WeightedClassFactory _factory = new WeightedClassFactory();
        CommunityClassVoterPool _pool = _factory.createVoterPool(
            1,
            1,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        _pool.addVoter(_VOTER);
        _pool.confirm(_VOTER, uint160(_VOTER));
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
        WeightedClassFactory _factory = new WeightedClassFactory();
        CommunityClassVoterPool _pool = _factory.createVoterPool(
            1,
            1,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        _pool.addVoter(_VOTER);
        _pool.makeFinal();
        assertTrue(_pool.isFinal());
    }

    function testFailRemoveIfFinal() public {
        CommunityClassVoterPool _pool = CommunityClassVoterPool(address(_class));
        _pool.removeVoter(_VOTER);
    }

    function testSupervisor() public {
        AddressCollection _supervisor = _class.communitySupervisorSet();
        assertTrue(_supervisor.contains(_SUPERVISOR));
    }

    function testSupportsInterface() public {
        IERC165 _erc165 = IERC165(address(_class));
        assertTrue(_erc165.supportsInterface(type(VoterPool).interfaceId));
        assertTrue(_erc165.supportsInterface(type(VoterClass).interfaceId));
        assertTrue(_erc165.supportsInterface(type(CommunityClass).interfaceId));
        assertTrue(_erc165.supportsInterface(type(Mutable).interfaceId));
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

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

import { Test } from "forge-std/Test.sol";

import { Constant } from "../../contracts/Constant.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";
import { Mutable } from "../../contracts/access/Mutable.sol";
import { OwnableInitializable } from "../../contracts/access/OwnableInitializable.sol";
import { AddressCollection } from "../../contracts/collection/AddressSet.sol";
import { CommunityBuilder } from "../../contracts/community/CommunityBuilder.sol";
import { createCommunityBuilder, CommunityBuilderProxy } from "../../contracts/community/CommunityBuilderProxy.sol";
import { VoterClass } from "../../contracts/community/VoterClass.sol";
import { CommunityClass, WeightedCommunityClass } from "../../contracts/community/CommunityClass.sol";
import { WeightedClassFactory, ProjectClassFactory } from "../../contracts/community/CommunityFactory.sol";

import { MockERC721 } from "../mock/MockERC721.sol";

contract CommunityBuilderTest is Test {
    address private constant _SUPERVISOR = address(0x1234);
    address private constant _OTHER = address(0x0001);

    CommunityBuilder private _builder;

    function setUp() public {
        _builder = createCommunityBuilder();
        _builder.aCommunity().withCommunitySupervisor(_SUPERVISOR);
    }

    function testVersion() public {
        assertEq(_builder.version(), Constant.CURRENT_VERSION);
    }

    function testName() public {
        assertEq(_builder.name(), "community builder");
    }

    function testCommunityTypeChangeForbidden() public {
        _builder.asOpenCommunity();
        vm.expectRevert(abi.encodeWithSelector(CommunityBuilder.CommunityTypeChange.selector));
        _builder.asPoolCommunity();
        vm.expectRevert(abi.encodeWithSelector(CommunityBuilder.CommunityTypeChange.selector));
        _builder.asOpenCommunity();
        vm.expectRevert(abi.encodeWithSelector(CommunityBuilder.CommunityTypeChange.selector));
        _builder.asErc721Community(address(0x1234));
        vm.expectRevert(abi.encodeWithSelector(CommunityBuilder.CommunityTypeChange.selector));
        _builder.asClosedErc721Community(address(0x1234), 10);
    }

    function testRequiresWeight() public {
        _builder.asOpenCommunity().withQuorum(1).withWeight(0);
        vm.expectRevert(abi.encodeWithSelector(CommunityBuilder.NonZeroWeightRequired.selector, 0));
        _builder.build();
    }

    function testRequiresQuorum() public {
        _builder.asOpenCommunity();
        vm.expectRevert(abi.encodeWithSelector(CommunityBuilder.NonZeroQuorumRequired.selector, 0));
        _builder.build();
    }

    function testRequiresCommunityType() public {
        _builder.withQuorum(1);
        vm.expectRevert(abi.encodeWithSelector(CommunityBuilder.CommunityTypeRequired.selector));
        _builder.build();
    }

    function testSuitableDefaultWeight() public {
        _builder.asOpenCommunity().withQuorum(1);
        address _classAddress = _builder.build();
        WeightedCommunityClass _class = WeightedCommunityClass(_classAddress);
        assertEq(_class.weight(), 1);
    }

    function testSuitableDefaultMinimumVoteDelay() public {
        _builder.asOpenCommunity().withQuorum(1);
        address _classAddress = _builder.build();
        CommunityClass _class = CommunityClass(_classAddress);
        assertEq(_class.minimumVoteDelay(), Constant.MINIMUM_VOTE_DELAY);
    }

    function testSuitableDefaultMaximumVoteDelay() public {
        _builder.asOpenCommunity().withQuorum(1);
        address _classAddress = _builder.build();
        CommunityClass _class = CommunityClass(_classAddress);
        assertEq(_class.maximumVoteDelay(), Constant.MAXIMUM_VOTE_DELAY);
    }

    function testSuitableDefaultMinimumVoteDuration() public {
        _builder.asOpenCommunity().withQuorum(1);
        address _classAddress = _builder.build();
        CommunityClass _class = CommunityClass(_classAddress);
        assertEq(_class.minimumVoteDuration(), Constant.MINIMUM_VOTE_DURATION);
    }

    function testSuitableDefaultMaximumVoteDuration() public {
        _builder.asOpenCommunity().withQuorum(1);
        address _classAddress = _builder.build();
        CommunityClass _class = CommunityClass(_classAddress);
        assertEq(_class.maximumVoteDuration(), Constant.MAXIMUM_VOTE_DURATION);
    }

    function testSetWeight() public {
        _builder.asOpenCommunity().withQuorum(1).withWeight(75);
        address _classAddress = _builder.build();
        WeightedCommunityClass _class = WeightedCommunityClass(_classAddress);
        assertEq(_class.weight(), 75);
    }

    function testMinimumVoteDelay() public {
        _builder.asOpenCommunity().withQuorum(1).withMinimumVoteDelay(Constant.MINIMUM_VOTE_DELAY + 1);
        address _classAddress = _builder.build();
        CommunityClass _class = CommunityClass(_classAddress);
        assertEq(_class.minimumVoteDelay(), Constant.MINIMUM_VOTE_DELAY + 1);
    }

    function testMaximumVoteDelay() public {
        _builder.asOpenCommunity().withQuorum(1).withMaximumVoteDelay(Constant.MAXIMUM_VOTE_DELAY - 1);
        address _classAddress = _builder.build();
        CommunityClass _class = CommunityClass(_classAddress);
        assertEq(_class.maximumVoteDelay(), Constant.MAXIMUM_VOTE_DELAY - 1);
    }

    function testRequiresMinimumDuration() public {
        _builder.asOpenCommunity().withQuorum(1).withMinimumVoteDuration(Constant.MINIMUM_VOTE_DURATION - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                CommunityClass.MinimumDurationExceedsMaximum.selector,
                Constant.MINIMUM_VOTE_DURATION - 1,
                Constant.MINIMUM_VOTE_DURATION
            )
        );
        _builder.build();
    }

    function testMinimumVoteDuration() public {
        _builder.asOpenCommunity().withQuorum(1).withMinimumVoteDuration(Constant.MINIMUM_VOTE_DURATION + 1);
        address _classAddress = _builder.build();
        CommunityClass _class = CommunityClass(_classAddress);
        assertEq(_class.minimumVoteDuration(), Constant.MINIMUM_VOTE_DURATION + 1);
    }

    function testMaximumVoteDuration() public {
        _builder.asOpenCommunity().withQuorum(1).withMaximumVoteDuration(Constant.MAXIMUM_VOTE_DURATION - 1);
        address _classAddress = _builder.build();
        CommunityClass _class = CommunityClass(_classAddress);
        assertEq(_class.maximumVoteDuration(), Constant.MAXIMUM_VOTE_DURATION - 1);
    }

    function testBuildReturnsAddress() public {
        _builder.asOpenCommunity().withQuorum(1);
        assertFalse(_builder.build() == address(0x0));
    }

    function testPoolCommunityRequiresAddress() public {
        _builder.asPoolCommunity().withQuorum(1);
        vm.expectRevert(abi.encodeWithSelector(CommunityBuilder.VoterRequired.selector));
        _builder.build();
    }

    function testPoolVoterIsEnabled() public {
        address _poolAddress = _builder.asPoolCommunity().withQuorum(1).withVoter(address(0x11)).build();
        CommunityClass _class = CommunityClass(_poolAddress);
        assertTrue(_class.isVoter(address(0x11)));
    }

    function testPoolIsFinal() public {
        address _poolAddress = _builder.asPoolCommunity().withQuorum(1).withVoter(address(0x11)).build();
        CommunityClass _class = CommunityClass(_poolAddress);
        assertTrue(_class.isFinal());
    }

    function testPoolRequiredForVoter() public {
        vm.expectRevert(abi.encodeWithSelector(CommunityBuilder.VoterPoolRequired.selector));
        _builder.withVoter(address(0x1));
    }

    function testOpenVoterIsEnabled() public {
        address _classAddress = _builder.asOpenCommunity().withQuorum(1).build();
        CommunityClass _class = CommunityClass(_classAddress);
        assertTrue(_class.isVoter(address(0x13)));
    }

    function testErc721Project() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(address(0x1), 0x100);
        address _classAddress = _builder
            .aCommunity()
            .asErc721Community(address(merc721))
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        VoterClass _class = VoterClass(_classAddress);
        assertTrue(_class.isVoter(address(0x1)));
    }

    function testClosedErc721Project() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(address(0x1), 0x100);
        address _classAddress = _builder
            .aCommunity()
            .asClosedErc721Community(address(merc721), 1)
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        VoterClass _class = VoterClass(_classAddress);
        assertTrue(_class.supportsInterface(type(VoterClass).interfaceId));
        assertTrue(_class.supportsInterface(type(CommunityClass).interfaceId));
        assertTrue(_class.isVoter(address(0x1)));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_builder.supportsInterface(ifId));
    }

    function testWithGasRebate() public {
        address _classAddress = _builder
            .asOpenCommunity()
            .withQuorum(1)
            .withMaximumGasUsedRebate(Constant.MAXIMUM_REBATE_GAS_USED + 0x7)
            .build();
        CommunityClass _class = CommunityClass(_classAddress);
        assertEq(_class.maximumGasUsedRebate(), Constant.MAXIMUM_REBATE_GAS_USED + 0x7);
    }

    function testWithBaseFeeRebate() public {
        address _classAddress = _builder
            .asOpenCommunity()
            .withQuorum(1)
            .withMaximumBaseFeeRebate(Constant.MAXIMUM_REBATE_BASE_FEE + 0x13)
            .build();
        CommunityClass _class = CommunityClass(_classAddress);
        assertEq(_class.maximumBaseFeeRebate(), Constant.MAXIMUM_REBATE_BASE_FEE + 0x13);
    }

    function testFailWithGasRebateGasUsedBelowMinimumRequired() public {
        _builder.asOpenCommunity().withQuorum(1).withMaximumGasUsedRebate(Constant.MAXIMUM_REBATE_GAS_USED - 0x1).build();
    }

    function testFailWithBaseFeeBelowMinimumRequired() public {
        _builder.asOpenCommunity().withQuorum(1).withMaximumBaseFeeRebate(Constant.MAXIMUM_REBATE_BASE_FEE - 0x1).build();
    }

    function testWithSupervisor() public {
        address _classAddress = _builder
            .asOpenCommunity()
            .withQuorum(1)
            .withCommunitySupervisor(address(0x1235))
            .withCommunitySupervisor(address(0x1236))
            .build();
        CommunityClass _class = CommunityClass(_classAddress);
        AddressCollection _supervisorSet = _class.communitySupervisorSet();
        assertTrue(_supervisorSet.contains(address(0x1234)));
        assertTrue(_supervisorSet.contains(address(0x1235)));
        assertTrue(_supervisorSet.contains(address(0x1236)));
    }

    function testFailWithNoSupervisor() public {
        _builder.aCommunity().asOpenCommunity().withQuorum(1).build();
    }

    function testOpenCommunityOwner() public {
        address _classAddress = _builder.asOpenCommunity().withQuorum(1).build();
        OwnableInitializable _ownable = OwnableInitializable(_classAddress);
        assertEq(_ownable.owner(), address(this));
    }

    function testPoolCommunityOwner() public {
        address _classAddress = _builder.asPoolCommunity().withVoter(address(0x1234)).withQuorum(1).build();
        OwnableInitializable _ownable = OwnableInitializable(_classAddress);
        assertEq(_ownable.owner(), address(this));
    }

    function testErc721CommunityOwner() public {
        address _classAddress = _builder.asErc721Community(address(0x1234)).withQuorum(1).build();
        OwnableInitializable _ownable = OwnableInitializable(_classAddress);
        assertEq(_ownable.owner(), address(this));
    }

    function testClosedErc721CommunityOwner() public {
        address _classAddress = _builder.asClosedErc721Community(address(0x1234), 1).withQuorum(1).build();
        OwnableInitializable _ownable = OwnableInitializable(_classAddress);
        assertEq(_ownable.owner(), address(this));
    }

    function testUpgradeRequiresOwner() public {
        WeightedClassFactory _wFactory = new WeightedClassFactory();
        ProjectClassFactory _pFactory = new ProjectClassFactory();
        CommunityBuilder _cBuilder = new CommunityBuilder();
        CommunityBuilderProxy _proxy = CommunityBuilderProxy(payable(address(_builder)));
        vm.expectRevert(abi.encodeWithSelector(OwnableInitializable.NotOwner.selector, _OTHER));
        vm.prank(_OTHER, _OTHER);
        _proxy.upgrade(address(_cBuilder), address(_wFactory), address(_pFactory));
    }
}

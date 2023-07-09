// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20PresetFixedSupply } from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

import { Test } from "forge-std/Test.sol";

import { Constant } from "../../contracts/Constant.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";
import { Mutable } from "../../contracts/access/Mutable.sol";
import { OwnableInitializable } from "../../contracts/access/OwnableInitializable.sol";
import { AddressCollection } from "../../contracts/collection/AddressSet.sol";
import { CommunityBuilder } from "../../contracts/community/CommunityBuilder.sol";
import { createCommunityBuilder, CommunityBuilderProxy } from "../../contracts/community/CommunityBuilderProxy.sol";
import { CommunityClass, WeightedCommunityClass } from "../../contracts/community/CommunityClass.sol";
import { WeightedClassFactory, ProjectClassFactory, TokenClassFactory } from "../../contracts/community/CommunityFactory.sol";

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

    function testMinimumVoteDelay(uint voteDelay) public {
        vm.assume(voteDelay >= Constant.MINIMUM_VOTE_DELAY && voteDelay < Constant.MAXIMUM_VOTE_DELAY);
        _builder.asOpenCommunity().withQuorum(1).withMinimumVoteDelay(voteDelay);
        address _classAddress = _builder.build();
        CommunityClass _class = CommunityClass(_classAddress);
        assertEq(_class.minimumVoteDelay(), voteDelay);
    }

    function testMaximumVoteDelay(uint voteDelay) public {
        vm.assume(voteDelay < Constant.MAXIMUM_VOTE_DELAY);
        _builder.asOpenCommunity().withQuorum(1).withMaximumVoteDelay(voteDelay);
        address _classAddress = _builder.build();
        CommunityClass _class = CommunityClass(_classAddress);
        assertEq(_class.maximumVoteDelay(), voteDelay);
    }

    function testMaximumVoteDelayExceedsPermitted(uint voteDelay) public {
        vm.assume(voteDelay > Constant.MAXIMUM_VOTE_DELAY);
        _builder.asOpenCommunity().withQuorum(1).withMaximumVoteDelay(voteDelay);
        vm.expectRevert(abi.encodeWithSelector(CommunityClass.MaximumDelayNotPermitted.selector, voteDelay, Constant.MAXIMUM_VOTE_DELAY));
        _builder.build();
    }

    function testMinimumVoteDelayExceedsMaximum(uint voteDelay) public {
        vm.assume(voteDelay >= Constant.MINIMUM_VOTE_DELAY && voteDelay < Constant.MAXIMUM_VOTE_DELAY);
        _builder.asOpenCommunity().withQuorum(1).withMinimumVoteDelay(voteDelay + 1).withMaximumVoteDelay(voteDelay);
        vm.expectRevert(abi.encodeWithSelector(CommunityClass.MinimumDelayExceedsMaximum.selector, voteDelay + 1, voteDelay));
        _builder.build();
    }

    function testRequiresMinimumDuration(uint voteDuration) public {
        vm.assume(voteDuration < Constant.MINIMUM_VOTE_DURATION);
        _builder.asOpenCommunity().withQuorum(1).withMinimumVoteDuration(voteDuration);
        vm.expectRevert(
            abi.encodeWithSelector(
                CommunityClass.MinimumDurationNotPermitted.selector,
                voteDuration,
                Constant.MINIMUM_VOTE_DURATION
            )
        );
        _builder.build();
    }

    function testRequiresMinimumDurationNotPermitted(uint voteDuration) public {
        vm.assume(voteDuration < Constant.MINIMUM_VOTE_DURATION);
        _builder.asOpenCommunity().withQuorum(1).withMinimumVoteDuration(voteDuration);
        vm.expectRevert(
            abi.encodeWithSelector(
                CommunityClass.MinimumDurationNotPermitted.selector,
                voteDuration,
                Constant.MINIMUM_VOTE_DURATION
            )
        );
        _builder.build();
    }

    function testRequiresMinimumDurationBelowMaximum(uint voteDuration) public {
        vm.assume(voteDuration > Constant.MINIMUM_VOTE_DURATION && voteDuration <= Constant.MAXIMUM_VOTE_DURATION);
        _builder.asOpenCommunity().withQuorum(1).withMinimumVoteDuration(voteDuration).withMaximumVoteDuration(Constant.MINIMUM_VOTE_DURATION);
        vm.expectRevert(
            abi.encodeWithSelector(
                CommunityClass.MinimumDurationExceedsMaximum.selector,
                voteDuration,
                Constant.MINIMUM_VOTE_DURATION
            )
        );
        _builder.build();
    }


    function testRequiresMinimumDurationMaxed(uint voteDuration) public {
        vm.assume(voteDuration > Constant.MAXIMUM_VOTE_DURATION);
        _builder.asOpenCommunity().withQuorum(1).withMinimumVoteDuration(voteDuration);
        vm.expectRevert(
            abi.encodeWithSelector(
                CommunityClass.MinimumDurationExceedsMaximum.selector,
                voteDuration,
                Constant.MAXIMUM_VOTE_DURATION
            )
        );
        _builder.build();
    }

    function testRequiresMaximumDuration(uint voteDuration) public {
        vm.assume(voteDuration > Constant.MAXIMUM_VOTE_DURATION);
        _builder.asOpenCommunity().withQuorum(1).withMaximumVoteDuration(voteDuration);
        vm.expectRevert(
            abi.encodeWithSelector(
                CommunityClass.MaximumDurationNotPermitted.selector,
                voteDuration,
                Constant.MAXIMUM_VOTE_DURATION
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
        CommunityClass _class = CommunityClass(_classAddress);
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
        CommunityClass _class = CommunityClass(_classAddress);
        assertTrue(_class.supportsInterface(type(CommunityClass).interfaceId));
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

    function testWithGasRebateBelowRequired(uint gasRebate) public {
        vm.assume(gasRebate < Constant.MAXIMUM_REBATE_GAS_USED);
        _builder.asOpenCommunity().withQuorum(1).withMaximumGasUsedRebate(gasRebate);
        vm.expectRevert(abi.encodeWithSelector(CommunityClass.GasUsedRebateMustBeLarger.selector, gasRebate, Constant.MAXIMUM_REBATE_GAS_USED));
        _builder.build();
    }

    function testWithBaseFeeBelowMinimumRequired(uint baseFee) public {
        vm.assume(baseFee < Constant.MAXIMUM_REBATE_BASE_FEE);
        _builder.asOpenCommunity().withQuorum(1).withMaximumBaseFeeRebate(baseFee);
        vm.expectRevert(abi.encodeWithSelector(CommunityClass.BaseFeeRebateMustBeLarger.selector, baseFee, Constant.MAXIMUM_REBATE_BASE_FEE));
        _builder.build();                
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

    function testWithNoSupervisor() public {
        _builder.aCommunity().asOpenCommunity().withQuorum(1);
        vm.expectRevert(abi.encodeWithSelector(CommunityClass.SupervisorListEmpty.selector));
        _builder.build();
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
        TokenClassFactory _tFactory = new TokenClassFactory();
        CommunityBuilder _cBuilder = new CommunityBuilder();
        CommunityBuilderProxy _proxy = CommunityBuilderProxy(payable(address(_builder)));
        uint8 version = uint8(_cBuilder.version());
        vm.expectRevert(abi.encodeWithSelector(OwnableInitializable.NotOwner.selector, _OTHER));
        vm.prank(_OTHER, _OTHER);
        _proxy.upgrade(address(_cBuilder), address(_wFactory), address(_pFactory), address(_tFactory), version);
    }

    function testErc20Community() public {
        uint256 tokenCount = 75;
        IERC20 _token = new ERC20PresetFixedSupply("TestToken", "TT20", tokenCount, address(0x1234));
        address _classAddress = _builder
            .aCommunity()
            .asErc20Community(address(_token))
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        CommunityClass _class = CommunityClass(_classAddress);
        assertTrue(_class.isVoter(address(0x1234)));
    }

    function testClosedErc20Community() public {
        uint256 tokenCount = 75;
        IERC20 _token = new ERC20PresetFixedSupply("TestToken", "TT20", tokenCount, address(0x1234));
        address _classAddress = _builder
            .aCommunity()
            .asClosedErc20Community(address(_token), 25)
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        CommunityClass _class = CommunityClass(_classAddress);
        assertTrue(_class.isVoter(address(0x1234)));
        assertFalse(_class.isVoter(address(0x1)));
        assertTrue(_class.canPropose(address(0x1234)));
        assertFalse(_class.canPropose(address(0x1)));
    }
}

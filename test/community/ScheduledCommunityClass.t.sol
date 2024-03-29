// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { Test } from "forge-std/Test.sol";

import { Constant } from "../../contracts/Constant.sol";
import { AddressCollection, AddressSet } from "../../contracts/collection/AddressSet.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";
import { OwnableInitializable } from "../../contracts/access/OwnableInitializable.sol";
import { ScheduledCommunityClass } from "../../contracts/community/ScheduledCommunityClass.sol";
import { CommunityBuilder } from "../../contracts/community/CommunityBuilder.sol";
import { createCommunityBuilder } from "../../contracts/community/CommunityBuilderProxy.sol";
import { VoterClass } from "../../contracts/community/VoterClass.sol";
import { WeightedCommunityClass, CommunityClass } from "../../contracts/community/CommunityClass.sol";

contract ScheduledCommunityClassTest is Test {
    address private constant _OTHER = address(0x1234);

    ScheduledCommunityClass private _class;

    function setUp() public {
        CommunityBuilder _builder = createCommunityBuilder();
        address _classLocation = _builder
            .aCommunity()
            .asOpenCommunity()
            .withWeight(75)
            .withQuorum(Constant.MINIMUM_PROJECT_QUORUM + 100)
            .withMinimumVoteDelay(Constant.MINIMUM_VOTE_DELAY + 1 days)
            .withMaximumVoteDelay(Constant.MAXIMUM_VOTE_DELAY - 2 seconds)
            .withMinimumVoteDuration(Constant.MINIMUM_VOTE_DURATION + 1 days)
            .withMaximumVoteDuration(Constant.MAXIMUM_VOTE_DURATION - 10 seconds)
            .withMaximumGasUsedRebate(Constant.MAXIMUM_REBATE_GAS_USED + 1)
            .withMaximumBaseFeeRebate(Constant.MAXIMUM_REBATE_BASE_FEE + 2)
            .withCommunitySupervisor(address(0x1234))
            .build();
        _class = ScheduledCommunityClass(_classLocation);
    }

    function testWeight() public {
        assertEq(75, _class.weight());
    }

    function testMinimumVoteDelay() public {
        assertEq(Constant.MINIMUM_VOTE_DELAY + 1 days, _class.minimumVoteDelay());
    }

    function testMaximumVoteDelay() public {
        assertEq(Constant.MAXIMUM_VOTE_DELAY - 2 seconds, _class.maximumVoteDelay());
    }

    function testMinimumVoteDuration() public {
        assertEq(Constant.MINIMUM_VOTE_DURATION + 1 days, _class.minimumVoteDuration());
    }

    function testMaximumVoteDuration() public {
        assertEq(Constant.MAXIMUM_VOTE_DURATION - 10 seconds, _class.maximumVoteDuration());
    }

    function testIsWeightedCommunityClass() public {
        IERC165 _erc165 = IERC165(address(_class));
        assertTrue(_erc165.supportsInterface(type(WeightedCommunityClass).interfaceId));
    }

    function testIsCommunityClass() public {
        IERC165 _erc165 = IERC165(address(_class));
        assertTrue(_erc165.supportsInterface(type(CommunityClass).interfaceId));
    }

    function testIsVoterClass() public {
        IERC165 _erc165 = IERC165(address(_class));
        assertTrue(_erc165.supportsInterface(type(VoterClass).interfaceId));
    }

    function testIsVersioned() public {
        IERC165 _erc165 = IERC165(address(_class));
        assertTrue(_erc165.supportsInterface(type(Versioned).interfaceId));
    }

    function testIsInitializable() public {
        IERC165 _erc165 = IERC165(address(_class));
        assertTrue(_erc165.supportsInterface(type(Initializable).interfaceId));
    }

    function testIsIERC165() public {
        IERC165 _erc165 = IERC165(address(_class));
        assertTrue(_erc165.supportsInterface(type(IERC165).interfaceId));
    }

    function testGasUsedRebate() public {
        assertEq(_class.maximumGasUsedRebate(), Constant.MAXIMUM_REBATE_GAS_USED + 1);
    }

    function testBaseFeeRebate() public {
        assertEq(_class.maximumBaseFeeRebate(), Constant.MAXIMUM_REBATE_BASE_FEE + 2);
    }

    function testSupervisor() public {
        assertTrue(_class.communitySupervisorSet().contains(address(0x1234)));
    }

    function testSupervisorSetHackFails() public {
        AddressCollection communitySups = _class.communitySupervisorSet();
        vm.expectRevert("Ownable: caller is not the owner");
        communitySups.add(address(0x1111));
    }

    function testUpgradeRequiresOwner() public {
        AddressCollection _supervisorSet = new AddressSet();
        _supervisorSet.add(address(0x1235));
        vm.expectRevert(abi.encodeWithSelector(OwnableInitializable.NotOwner.selector, _OTHER));
        vm.prank(_OTHER, _OTHER);
        _class.upgrade(
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet,
            uint8(Constant.CURRENT_VERSION)
        );
    }
}

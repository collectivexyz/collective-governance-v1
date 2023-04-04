// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { Constant } from "../../contracts/Constant.sol";
import { Mutable } from "../../contracts/access/Mutable.sol";
import { AddressCollection, AddressSet } from "../../contracts/collection/AddressSet.sol";
import { upgradeOpenVote, upgradeVoterPool, upgradeErc721, upgradeClosedErc721, WeightedClassFactory, ProjectClassFactory } from "../../contracts/community/CommunityFactory.sol";
import { WeightedCommunityClass, ProjectCommunityClass } from "../../contracts/community/CommunityClass.sol";

import { MockERC721 } from "../../test/mock/MockERC721.sol";

contract WeightedCommunityFactoryTest is Test {
    address private constant _OTHER = address(0x10);
    WeightedClassFactory private _weightedFactory;
    AddressCollection private _supervisorSet;

    function setUp() public {
        _weightedFactory = new WeightedClassFactory();
        _supervisorSet = new AddressSet();
        _supervisorSet.add(address(0x1234));
    }

    function testOpenVote() public {
        WeightedCommunityClass _class = _weightedFactory.createOpenVote(
            19,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        assertEq(_class.weight(), 19);
        assertTrue(_class.communitySupervisorSet().contains(address(0x1234)));
    }

    function testOpenVoteUpgrade() public {
        WeightedCommunityClass _class = _weightedFactory.createOpenVote(
            19,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        _supervisorSet.erase(address(0x1234));
        _supervisorSet.add(address(0x1235));
        upgradeOpenVote(
            payable(address(_class)),
            20,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        assertEq(_class.weight(), 20);
        assertFalse(_class.communitySupervisorSet().contains(address(0x1234)));
        assertTrue(_class.communitySupervisorSet().contains(address(0x1235)));
    }

    function testOpenVoteUpgradeNotOwner() public {
        WeightedCommunityClass _class = _weightedFactory.createOpenVote(
            19,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        upgradeOpenVote(
            payable(address(_class)),
            19,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
    }

    function testPoolComunity() public {
        WeightedCommunityClass _class = _weightedFactory.createVoterPool(
            10,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        assertEq(_class.weight(), 10);
        Mutable _mutable = Mutable(address(_class));
        assertFalse(_mutable.isFinal());
        assertTrue(_class.communitySupervisorSet().contains(address(0x1234)));
    }

    function testPoolComunityUpgrade() public {
        WeightedCommunityClass _class = _weightedFactory.createVoterPool(
            10,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        _supervisorSet.erase(address(0x1234));
        _supervisorSet.add(address(0x1235));
        upgradeVoterPool(
            payable(address(_class)),
            11,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        assertEq(_class.weight(), 11);
        Mutable _mutable = Mutable(address(_class));
        assertFalse(_mutable.isFinal());
        assertFalse(_class.communitySupervisorSet().contains(address(0x1234)));
        assertTrue(_class.communitySupervisorSet().contains(address(0x1235)));
    }
}

contract ProjectFactoryTest is Test {
    ProjectClassFactory private _projectFactory;
    AddressSet private _supervisorSet;

    function setUp() public {
        _projectFactory = new ProjectClassFactory();
        _supervisorSet = new AddressSet();
        _supervisorSet.add(address(0x1234));
    }

    function testErc721() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(address(0x1), 0x100);
        ProjectCommunityClass _class = _projectFactory.createErc721(
            address(merc721),
            2,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        assertEq(_class.weight(), 2);
        assertTrue(_class.canPropose(address(0x1)));
        assertTrue(_class.canPropose(address(0x2)));
        assertTrue(_class.communitySupervisorSet().contains(address(0x1234)));
    }

    function testUpgradeErc721() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(address(0x1), 0x100);
        ProjectCommunityClass _class = _projectFactory.createErc721(
            address(merc721),
            2,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        _supervisorSet.erase(address(0x1234));
        _supervisorSet.add(address(0x1235));
        upgradeErc721(
            payable(address(_class)),
            3,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        assertEq(_class.weight(), 3);
        assertTrue(_class.canPropose(address(0x1)));
        assertTrue(_class.canPropose(address(0x2)));
        assertFalse(_class.communitySupervisorSet().contains(address(0x1234)));
        assertTrue(_class.communitySupervisorSet().contains(address(0x1235)));
    }

    function testClosedErc721() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(address(0x1), 0x100);
        ProjectCommunityClass _class = _projectFactory.createClosedErc721(
            address(merc721),
            1,
            2,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        assertEq(_class.weight(), 2);
        assertTrue(_class.canPropose(address(0x1)));
        assertFalse(_class.canPropose(address(0x2)));
        assertTrue(_class.communitySupervisorSet().contains(address(0x1234)));
    }

    function testUpgradeClosedErc721() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(address(0x1), 0x100);
        ProjectCommunityClass _class = _projectFactory.createClosedErc721(
            address(merc721),
            1,
            2,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        _supervisorSet.erase(address(0x1234));
        _supervisorSet.add(address(0x1235));
        upgradeClosedErc721(
            payable(address(_class)),
            7,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            _supervisorSet
        );
        assertEq(_class.weight(), 7);
        assertTrue(_class.canPropose(address(0x1)));
        assertFalse(_class.canPropose(address(0x2)));
        assertFalse(_class.communitySupervisorSet().contains(address(0x1234)));
        assertTrue(_class.communitySupervisorSet().contains(address(0x1235)));
    }
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../../contracts/Constant.sol";
import "../../contracts/community/CommunityFactory.sol";
import "../../contracts/community/CommunityClass.sol";

import "../../test/mock/MockERC721.sol";

contract WeightedCommunityFactoryTest is Test {
    WeightedClassFactory private _weightedFactory;

    function setUp() public {
        _weightedFactory = new WeightedClassFactory();
    }

    function testOpenVote() public {
        WeightedCommunityClass _class = _weightedFactory.createOpenVote(
            19,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );
        assertEq(_class.weight(), 19);
    }

    function testPoolComunity() public {
        WeightedCommunityClass _class = _weightedFactory.createVoterPool(
            10,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );
        assertEq(_class.weight(), 10);
        Mutable _mutable = Mutable(address(_class));
        assertFalse(_mutable.isFinal());
    }
}

contract ProjectFactoryTest is Test {
    ProjectClassFactory private _projectFactory;

    function setUp() public {
        _projectFactory = new ProjectClassFactory();
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
            Constant.MAXIMUM_VOTE_DURATION
        );
        assertEq(_class.weight(), 2);
        assertTrue(_class.canPropose(address(0x1)));
        assertTrue(_class.canPropose(address(0x2)));
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
            Constant.MAXIMUM_VOTE_DURATION
        );
        assertEq(_class.weight(), 2);
        assertTrue(_class.canPropose(address(0x1)));
        assertFalse(_class.canPropose(address(0x2)));
    }
}

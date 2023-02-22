// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "forge-std/Test.sol";

import "../../contracts/community/ScheduledCommunityClass.sol";
import "../../contracts/community/CommunityBuilder.sol";

contract ScheduledCommunityClassTest is Test {
    address private constant _OTHER = address(0x1234);

    ScheduledCommunityClass private _class;

    function setUp() public {
        address _classLocation = new CommunityBuilder()
            .aCommunity()
            .asOpenCommunity()
            .withWeight(75)
            .withQuorum(Constant.MINIMUM_PROJECT_QUORUM + 100)
            .withMinimumVoteDelay(Constant.MINIMUM_VOTE_DELAY + 1 days)
            .withMaximumVoteDelay(Constant.MAXIMUM_VOTE_DELAY - 2 seconds)
            .withMinimumVoteDuration(Constant.MINIMUM_VOTE_DURATION + 1 days)
            .withMaximumVoteDuration(Constant.MAXIMUM_VOTE_DURATION - 10 seconds)
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

    function testUpgradeRequiresOwner() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableInitializable.NotOwner.selector, _OTHER));
        vm.prank(_OTHER, _OTHER);
        _class.upgrade(
            1,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MAXIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION,
            Constant.MAXIMUM_VOTE_DURATION
        );
    }
}

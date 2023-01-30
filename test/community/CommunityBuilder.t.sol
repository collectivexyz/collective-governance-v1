// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "forge-std/Test.sol";

import "../../contracts/Constant.sol";
import "../../test/MockERC721.sol";
import "../../contracts/community/CommunityBuilder.sol";
import "../../contracts/community/CommunityClass.sol";

contract CommunityBuilderTest is Test {
    CommunityBuilder private _builder;

    function setUp() public {
        _builder = new CommunityBuilder();
        _builder.aCommunity();
    }

    function testVersion() public {
        assertEq(_builder.version(), Constant.VERSION_3);
    }

    function testName() public {
        assertEq(_builder.name(), "community builder");
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
        CommunityClass _class = CommunityClass(_classAddress);
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
        CommunityClass _class = CommunityClass(_classAddress);
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
                CommunityClass.MinimumDurationNotPermitted.selector,
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
        address _classAddress = _builder.aCommunity().asErc721Community(address(merc721)).withQuorum(1).build();
        VoterClass _class = VoterClass(_classAddress);
        assertTrue(_class.isVoter(address(0x1)));
    }

    function testClosedErc721Project() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(address(0x1), 0x100);
        address _classAddress = _builder.aCommunity().asClosedErc721Community(address(merc721), 1).withQuorum(1).build();
        VoterClass _class = VoterClass(_classAddress);
        assertTrue(_class.isVoter(address(0x1)));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_builder.supportsInterface(ifId));
    }
}

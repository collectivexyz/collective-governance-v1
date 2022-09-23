// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../contracts/GovernanceBuilder.sol";
import "../contracts/Governance.sol";
import "../contracts/VoterClass.sol";
import "../contracts/VoterClassVoterPool.sol";
import "../contracts/VoterClassERC721.sol";

import "./MockERC721.sol";

contract GovernanceBuilderTest is Test {
    address private constant _OWNER = address(0x1);
    address private constant _SUPERVISOR = address(0x123);
    address private constant _VOTER1 = address(0xfff1);

    GovernanceBuilder private _builder;

    function setUp() public {
        vm.clearMockedCalls();
        _builder = new GovernanceBuilder();
    }

    function testWithSupervisor() public {
        VoterClass _class = new VoterClassNullObject();
        address _governance = _builder.aGovernance().withSupervisor(_SUPERVISOR).withVoterClass(_class).build();
        Governance _gov = Governance(_governance);
        _gov.propose();
        address _storage = _gov.getStorageAddress();
        assertTrue(Storage(_storage).isSupervisor(1, _SUPERVISOR));
    }

    function testWithVoteDuration() public {
        VoterClass _class = new VoterClassNullObject();
        address _governance = _builder
            .aGovernance()
            .withMinimumDuration(2 * Constant.MINIMUM_VOTE_DURATION)
            .withSupervisor(_SUPERVISOR)
            .withVoterClass(_class)
            .build();
        Governance _gov = Governance(_governance);
        _gov.propose();
        address _storage = _gov.getStorageAddress();
        assertEq(Storage(_storage).minimumVoteDuration(), 2 * Constant.MINIMUM_VOTE_DURATION);
    }

    function testWithoutVoteDuration() public {
        VoterClass _class = new VoterClassNullObject();
        address _governance = _builder.aGovernance().withSupervisor(_SUPERVISOR).withVoterClass(_class).build();
        Governance _gov = Governance(_governance);
        _gov.propose();
        address _storage = _gov.getStorageAddress();
        assertEq(Storage(_storage).minimumVoteDuration(), 86400);
    }

    function testFailWithVoteDurationThatIsTooShort() public {
        VoterClass _class = new VoterClassNullObject();
        _builder.aGovernance().withMinimumDuration(86399).withSupervisor(_SUPERVISOR).withVoterClass(_class).build();
    }

    function testWithOpenVote() public {
        VoterClass _class = new VoterClassOpenVote(1);
        address _governance = _builder.aGovernance().withSupervisor(_SUPERVISOR).withVoterClass(_class).build();
        Governance _gov = Governance(_governance);
        _gov.propose();
        address _storage = _gov.getStorageAddress();
        assertTrue(Storage(_storage).isVoter(1, _VOTER1));
    }

    function testWithVoterPool() public {
        VoterClassVoterPool _class = new VoterClassVoterPool(1);
        _class.addVoter(_VOTER1);
        _class.makeFinal();
        address _governance = _builder.aGovernance().withSupervisor(_SUPERVISOR).withVoterClass(_class).build();
        Governance _gov = Governance(_governance);
        _gov.propose();
        address _storage = _gov.getStorageAddress();
        assertTrue(Storage(_storage).isVoter(1, _VOTER1));
    }

    function testWithERC721() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(_VOTER1, 0x10);
        VoterClass _class = new VoterClassERC721(address(merc721), 1);
        address _governance = _builder.aGovernance().withSupervisor(_SUPERVISOR).withVoterClass(_class).build();
        Governance _gov = Governance(_governance);
        uint256 pid = _gov.propose();
        address _storage = _gov.getStorageAddress();
        assertTrue(Storage(_storage).isVoter(pid, _VOTER1));
    }

    function testFailSupervisorIsRequired() public {
        VoterClass _class = new VoterClassNullObject();
        _builder.aGovernance().withVoterClass(_class).build();
    }

    function testFailVoterClassIsRequired() public {
        _builder.aGovernance().withSupervisor(_SUPERVISOR).build();
    }

    function testFailResetBuilder() public {
        VoterClass _class = new VoterClassNullObject();
        _builder.aGovernance().withSupervisor(_SUPERVISOR).withVoterClass(_class).build();
        _builder.reset();
        _builder.build();
    }
}

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
    GovernanceBuilder private _builder;

    address public immutable owner = address(0x1);
    address public immutable supervisor = address(0x123);
    address public immutable voter1 = address(0xfff1);

    function setUp() public {
        vm.clearMockedCalls();
        _builder = new GovernanceBuilder();
    }

    function testWithSupervisor() public {
        VoterClass _class = new VoterClassNullObject();
        address _governance = _builder.aGovernance().withSupervisor(supervisor).withVoterClass(_class).build();
        Governance _gov = Governance(_governance);
        _gov.propose();
        address _storage = _gov.getStorageAddress();
        assertTrue(Storage(_storage).isSupervisor(1, supervisor));
    }

    function testWithOpenVote() public {
        VoterClass _class = new VoterClassOpenVote(1);
        address _governance = _builder.aGovernance().withSupervisor(supervisor).withVoterClass(_class).build();
        Governance _gov = Governance(_governance);
        _gov.propose();
        address _storage = _gov.getStorageAddress();
        assertTrue(Storage(_storage).isVoter(1, voter1));
    }

    function testWithVoterPool() public {
        VoterClassVoterPool _class = new VoterClassVoterPool(1);
        _class.addVoter(voter1);
        _class.makeFinal();
        address _governance = _builder.aGovernance().withSupervisor(supervisor).withVoterClass(_class).build();
        Governance _gov = Governance(_governance);
        _gov.propose();
        address _storage = _gov.getStorageAddress();
        assertTrue(Storage(_storage).isVoter(1, voter1));
    }

    function testWithERC721() public {
        MockERC721 merc721 = new MockERC721();
        merc721.mintTo(voter1, 0x10);
        VoterClass _class = new VoterClassERC721(address(merc721), 1);
        address _governance = _builder.aGovernance().withSupervisor(supervisor).withVoterClass(_class).build();
        Governance _gov = Governance(_governance);
        uint256 pid = _gov.propose();
        address _storage = _gov.getStorageAddress();
        assertTrue(Storage(_storage).isVoter(pid, voter1));
    }

    function testFailSupervisorIsRequired() public {
        VoterClass _class = new VoterClassNullObject();
        _builder.aGovernance().withVoterClass(_class).build();
    }

    function testFailVoterClassIsRequired() public {
        _builder.aGovernance().withSupervisor(supervisor).build();
    }
}

// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable not-rely-on-time
pragma solidity ^0.8.15;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";

import { Test } from "forge-std/Test.sol";

import { Constant } from "../../contracts/Constant.sol";
import { Transaction, TransactionCollection, getHash } from "../../contracts/collection/TransactionSet.sol";
import { Choice, getHash } from "../../contracts/collection/ChoiceSet.sol";
import { CollectiveGovernance } from "../../contracts/governance/CollectiveGovernance.sol";
import { VoteStrategy } from "../../contracts/governance/VoteStrategy.sol";
import { createCommunityBuilder } from "../../contracts/community/CommunityBuilderProxy.sol";
import { CommunityBuilder } from "../../contracts/community/CommunityBuilder.sol";
import { CommunityClass } from "../../contracts/community/CommunityClass.sol";
import { VoterClass } from "../../contracts/community/VoterClass.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";
import { Storage } from "../../contracts/storage/Storage.sol";
import { GovernanceStorage } from "../../contracts/storage/GovernanceStorage.sol";
import { StorageFactory } from "../../contracts/storage/StorageFactory.sol";

import { TestData } from "../mock/TestData.sol";
import { MockERC721 } from "../mock/MockERC721.sol";

contract GovernanceStorageChoiceVoteTest is Test {
    address private constant _OWNER = address(0x155);
    address private constant _SUPERVISOR = address(0x123);
    address private constant _VOTER1 = address(0xfff1);
    address private constant _VOTER2 = address(0xfff2);
    address private constant _VOTER3 = address(0xfff3);

    uint256 public constant _NCHOICE = 5;

    Storage private _storage;
    VoteStrategy private _strategy;
    uint256 private _proposalId;

    function setUp() public {
        vm.clearMockedCalls();
        CommunityBuilder _builder = createCommunityBuilder();
        address _communityLocation = _builder
            .aCommunity()
            .asPoolCommunity()
            .withVoter(_VOTER1)
            .withVoter(_VOTER2)
            .withVoter(_VOTER3)
            .withQuorum(1)
            .withCommunitySupervisor(_SUPERVISOR)
            .build();
        CommunityClass _voterClass = CommunityClass(_communityLocation);
        _storage = new StorageFactory().create(_voterClass);
        _proposalId = _storage.initializeProposal(_OWNER);
    }

    function testAddChoiceProposal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.addChoice(_proposalId, Choice(keccak256(abi.encode(i)), "description", 0, "", 0), _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        assertEq(_storage.choiceCount(_proposalId), 5);
    }

    function testAddChoiceProposalReqOwner() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_SUPERVISOR);
        _storage.addChoice(_proposalId, Choice("name", "description", 0, "", 0), _SUPERVISOR);
    }

    function testAddChoiceProposalReqValidProposal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidProposal.selector, _proposalId + 1));
        _storage.addChoice(_proposalId + 1, Choice("name", "description", 0, "", 0), _SUPERVISOR);
    }

    function testAddChoiceNotFinal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.addChoice(_proposalId, Choice(keccak256(abi.encode(i)), "description", 0, "", 0), _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.VoteIsFinal.selector, _proposalId));
        _storage.addChoice(_proposalId, Choice("name", "description", 0, "", 0), _SUPERVISOR);
    }

    function testAddChoiceNotSupervisor() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.NotSupervisor.selector, _proposalId, _OWNER));
        _storage.addChoice(_proposalId, Choice("name", "description", 0, "", 0), _OWNER);
    }

    function testAddChoiceWithNonZeroVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.ChoiceVoteCountInvalid.selector, _proposalId));
        _storage.addChoice(_proposalId, Choice("name", "description", 0, "", 1), _SUPERVISOR);
    }

    function testAddChoiceRequiresName() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        vm.expectRevert(abi.encodeWithSelector(Storage.ChoiceNameRequired.selector, _proposalId));
        _storage.addChoice(_proposalId, Choice(0x0, "description", 0, "", 0), _SUPERVISOR);
    }

    function testAddChoiceDescriptionExceedsLimit() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        string memory limitedString = TestData.pi1kplus();
        uint256 descLen = Constant.len(limitedString);
        vm.expectRevert(abi.encodeWithSelector(Storage.StringSizeLimit.selector, descLen));
        _storage.addChoice(_proposalId, Choice("NAME", limitedString, 0, "", 0), _SUPERVISOR);
    }

    function testGetChoice() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.addChoice(_proposalId, Choice(keccak256(abi.encode(i)), "description", 0, "", 0), _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            Choice memory choice = _storage.getChoice(_proposalId, i + 1);
            assertEq(choice.name, keccak256(abi.encode(i)));
            assertEq(choice.description, "description");
            assertEq(choice.transactionId, 0);
            assertEq(choice.voteCount, 0);
        }
    }

    function testChoiceWithValidTransaction() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);

        for (uint256 i = 0; i < _NCHOICE; i++) {
            (address target, uint256 value, string memory _signature, bytes memory _calldata, uint256 scheduleTime) = (
                address(0x113e),
                i + 1,
                "",
                "",
                block.timestamp
            );
            Transaction memory t = Transaction(target, value, _signature, _calldata, scheduleTime);
            uint256 tid = _storage.addTransaction(_proposalId, t, _OWNER);
            assertEq(tid, i + 1);
            _storage.addChoice(_proposalId, Choice(keccak256(abi.encode(i)), "description", tid, getHash(t), 0), _SUPERVISOR);
            vm.warp(block.timestamp + 1);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            Choice memory choice = _storage.getChoice(_proposalId, i + 1);
            assertEq(choice.name, keccak256(abi.encode(i)));
            assertEq(choice.description, "description");
            assertEq(choice.transactionId, i + 1);
            assertEq(choice.voteCount, 0);
            Transaction memory t = _storage.getTransaction(_proposalId, choice.transactionId);
            bytes32 _txHash = getHash(t);
            assertEq(choice.txHash, _txHash);
        }
    }

    function testChoiceWithInvalidTransaction() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);

        for (uint256 i = 0; i < _NCHOICE; i++) {
            (address target, uint256 value, string memory _signature, bytes memory _calldata, uint256 scheduleTime) = (
                address(0x113e),
                i + 1,
                "",
                "",
                block.timestamp
            );
            Transaction memory t = Transaction(target, value, _signature, _calldata, scheduleTime);
            _storage.addTransaction(_proposalId, t, _OWNER);
            vm.warp(block.timestamp + 1);
        }
        vm.expectRevert(abi.encodeWithSelector(TransactionCollection.InvalidTransaction.selector, _NCHOICE + 1));
        _storage.addChoice(_proposalId, Choice("name", "description", _NCHOICE + 1, "", 0), _SUPERVISOR);
    }

    function testChoiceProposalVoteRequiresChoiceId() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.addChoice(_proposalId, Choice(keccak256(abi.encode(i)), "description", 0, "", 0), _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.ChoiceRequired.selector, _proposalId));
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1));
    }

    function testChoiceProposalAgainstNotAllowed() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.addChoice(_proposalId, Choice(keccak256(abi.encode(i)), "description", 0, "", 0), _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.ChoiceRequired.selector, _proposalId));
        _storage.voteAgainstByShare(_proposalId, _VOTER1, uint160(_VOTER1));
    }

    function testCastOneVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.addChoice(_proposalId, Choice(keccak256(abi.encode(i)), "description", 0, "", 0), _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1), 1);
        assertEq(_storage.voteCount(_proposalId, 1), 1);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            if (i != 0) {
                assertEq(_storage.voteCount(_proposalId, i + 1), 0);
            }
        }
        assertEq(_storage.quorum(_proposalId), 1);
    }

    function testCastVoteWithoutChoice() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.addChoice(_proposalId, Choice(keccak256(abi.encode(i)), "description", 0, "", 0), _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.ChoiceRequired.selector, _proposalId));
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1));
    }

    function testCastMultiVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.addChoice(_proposalId, Choice(keccak256(abi.encode(i)), "description", 0, "", 0), _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        for (uint256 i = 0; i < 3; i++) {
            _storage.voteForByShare(_proposalId, address(uint160(_VOTER1) + uint160(i)), uint160(_VOTER1) + i, i + 1);
        }
        assertEq(_storage.voteCount(_proposalId, 1), 1);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(_storage.voteCount(_proposalId, i + 1), 1);
        }
        for (uint256 i = 3; i < _NCHOICE; i++) {
            assertEq(_storage.voteCount(_proposalId, i + 1), 0);
        }
        assertEq(_storage.quorum(_proposalId), 3);
    }

    function testAbstainVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.addChoice(_proposalId, Choice(keccak256(abi.encode(i)), "description", 0, "", 0), _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.abstainForShare(_proposalId, _VOTER1, uint160(_VOTER1));
        for (uint256 i = 0; i < _NCHOICE; i++) {
            assertEq(_storage.voteCount(_proposalId, i + 1), 0);
        }
        assertEq(_storage.quorum(_proposalId), 1);
    }

    function testCastVoteWrongShare() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.addChoice(_proposalId, Choice(keccak256(abi.encode(i)), "description", 0, "", 0), _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(VoterClass.UnknownToken.selector, uint160(_VOTER2)));
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER2), 1);
    }

    function testCastVoteBadProposal() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.addChoice(_proposalId, Choice(keccak256(abi.encode(i)), "description", 0, "", 0), _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        vm.expectRevert(abi.encodeWithSelector(Storage.InvalidProposal.selector, _proposalId + 1));
        _storage.voteForByShare(_proposalId + 1, _VOTER1, uint160(_VOTER1), 1);
    }

    function testCastVoteEnded() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.addChoice(_proposalId, Choice(keccak256(abi.encode(i)), "description", 0, "", 0), _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        uint256 startTime = _storage.startTime(_proposalId);
        uint256 endTime = _storage.endTime(_proposalId);
        vm.warp(endTime + 1);
        vm.expectRevert(abi.encodeWithSelector(Storage.VoteNotActive.selector, _proposalId, startTime, endTime));
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1), 1);
    }

    function testReceiptForChoice() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        for (uint256 i = 0; i < _NCHOICE; i++) {
            _storage.addChoice(_proposalId, Choice(keccak256(abi.encode(i)), "description", 0, "", 0), _SUPERVISOR);
        }
        _storage.makeFinal(_proposalId, _SUPERVISOR);
        _storage.voteForByShare(_proposalId, _VOTER1, uint160(_VOTER1), 1);
        (uint256 shareId, uint256 shareFor, uint256 votesCast, uint256 choiceId, bool isAbstention) = _storage.getVoteReceipt(
            _proposalId,
            uint160(_VOTER1)
        );
        assertEq(shareId, uint160(_VOTER1));
        assertEq(shareFor, 1);
        assertEq(votesCast, 1);
        assertEq(choiceId, 1);
        assertFalse(isAbstention);
    }

    function testIsChoiceVote() public {
        _storage.registerSupervisor(_proposalId, _SUPERVISOR, _OWNER);
        _storage.addChoice(_proposalId, Choice("name", "description", 0, "", 0), _SUPERVISOR);
        assertTrue(_storage.isChoiceVote(_proposalId));
    }

    function testSupportsInterfaceStorage() public {
        bytes4 ifId = type(Storage).interfaceId;
        assertTrue(_storage.supportsInterface(ifId));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_storage.supportsInterface(ifId));
    }

    function testSupportsInterfaceOwnable() public {
        bytes4 ifId = type(Ownable).interfaceId;
        assertTrue(_storage.supportsInterface(ifId));
    }
}

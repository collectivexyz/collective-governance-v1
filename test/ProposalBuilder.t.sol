// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

import { Test } from "forge-std/Test.sol";

import { Constant } from "../contracts/Constant.sol";
import { ProposalBuilder } from "../contracts/ProposalBuilder.sol";
import { Governance } from "../contracts/governance/Governance.sol";
import { Storage } from "../contracts/storage/Storage.sol";
import { Meta } from "../contracts/collection/MetaSet.sol";
import { Choice } from "../contracts/collection/ChoiceSet.sol";
import { Transaction } from "../contracts/collection/TransactionSet.sol";
import { MetaStorage } from "../contracts/storage/MetaStorage.sol";
import { Versioned } from "../contracts/access/Versioned.sol";
import { GovernanceBuilder } from "../contracts/governance/GovernanceBuilder.sol";
import { CommunityClass } from "../contracts/community/CommunityClass.sol";
import { CommunityBuilder } from "../contracts/community/CommunityBuilder.sol";
import { StorageFactory } from "../contracts/storage/StorageFactory.sol";
import { MetaStorageFactory } from "../contracts/storage/MetaStorageFactory.sol";
import { GovernanceFactory } from "../contracts/governance/GovernanceFactory.sol";
import { GovernanceBuilder } from "../contracts/governance/GovernanceBuilder.sol";

import { TestData } from "./mock/TestData.sol";

contract ProposalBuilderTest is Test {
    address private constant _OWNER = address(0x1);
    address private constant _CREATOR = address(0x2);
    address private constant _VOTER1 = address(0xfff1);

    CommunityClass private _class;
    Storage private _storage;
    MetaStorage private _meta;
    ProposalBuilder private _builder;

    function setUp() public {
        address _classAddr = new CommunityBuilder()
            .aCommunity()
            .withCommunitySupervisor(_CREATOR)
            .asOpenCommunity()
            .withQuorum(1)
            .build();
        StorageFactory _storageFactory = new StorageFactory();
        MetaStorageFactory _metaStorageFactory = new MetaStorageFactory();
        GovernanceFactory _governanceFactory = new GovernanceFactory();
        GovernanceBuilder _gbuilder = new GovernanceBuilder(
            address(_storageFactory),
            address(_metaStorageFactory),
            address(_governanceFactory)
        );
        (address payable _govAddr, address _stoAddr, address _metaAddr) = _gbuilder
            .aGovernance()
            .withCommunityClassAddress(_classAddr)
            .build();
        _builder = new ProposalBuilder(_govAddr, _stoAddr, _metaAddr);
        transferOwnership(_metaAddr, address(_builder));
        _storage = Storage(_stoAddr);
        _meta = MetaStorage(_metaAddr);
        _class = CommunityClass(_classAddr);
    }

    function testRequiresGovernanceLessThanStorageVersion() public {
        address _govAddr = mockGovernance();
        address _storageAddr = mockConforming(address(0x10), Constant.CURRENT_VERSION - 1, true);
        address _metaAddr = mockMetaStorage();
        vm.expectRevert(
            abi.encodeWithSelector(
                ProposalBuilder.VersionMismatch.selector,
                Constant.CURRENT_VERSION,
                Constant.CURRENT_VERSION - 1
            )
        );
        new ProposalBuilder(_govAddr, _storageAddr, _metaAddr);
    }

    function testRequiresGovernanceLessThanMetaStorageVersion() public {
        address _gov = mockGovernance();
        address _mockStorage = mockStorage();
        address _mockMeta = mockConforming(address(0x10), Constant.CURRENT_VERSION - 1, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                ProposalBuilder.VersionMismatch.selector,
                Constant.CURRENT_VERSION,
                Constant.CURRENT_VERSION - 1
            )
        );
        new ProposalBuilder(_gov, _mockStorage, _mockMeta);
    }

    function testRequiresGovernance() public {
        address _gov = mockConforming(address(0x10), Constant.CURRENT_VERSION, false);
        address _mockStorage = mockStorage();
        address _mockMeta = mockMetaStorage();
        vm.expectRevert(abi.encodeWithSelector(ProposalBuilder.NotGovernance.selector, _gov));
        new ProposalBuilder(_gov, _mockStorage, _mockMeta);
    }

    function testRequiresStorage() public {
        address _gov = mockGovernance();
        address _mockStorage = mockConforming(address(0x11), Constant.CURRENT_VERSION, false);
        address _mockMeta = mockMetaStorage();
        vm.expectRevert(abi.encodeWithSelector(ProposalBuilder.NotStorage.selector, _mockStorage));
        new ProposalBuilder(_gov, _mockStorage, _mockMeta);
    }

    function testRequiresMeta() public {
        address _gov = mockGovernance();
        address _mockStorage = mockStorage();
        address _mockMeta = mockConforming(address(0x12), Constant.CURRENT_VERSION, false);
        vm.expectRevert(abi.encodeWithSelector(ProposalBuilder.NotMetaStorage.selector, _mockMeta));
        new ProposalBuilder(_gov, _mockStorage, _mockMeta);
    }

    function testFailChoiceDescriptionSizeChecked() public {
        string memory _excessiveString = TestData.pi1kplus();
        _builder.withChoice("abc", _excessiveString, 0);
    }

    function testInitializationRequired() public {
        vm.expectRevert(abi.encodeWithSelector(ProposalBuilder.ProposalNotInitialized.selector, address(this)));
        _builder.withQuorum(1);
        vm.expectRevert(abi.encodeWithSelector(ProposalBuilder.ProposalNotInitialized.selector, address(this)));
        _builder.withChoice("a", "first", 0);
        vm.expectRevert(abi.encodeWithSelector(ProposalBuilder.ProposalNotInitialized.selector, address(this)));
        _builder.withTransaction(address(0x123), 0, "", "", 0);
        vm.expectRevert(abi.encodeWithSelector(ProposalBuilder.ProposalNotInitialized.selector, address(this)));
        _builder.withDescription("desc", "url");
        vm.expectRevert(abi.encodeWithSelector(ProposalBuilder.ProposalNotInitialized.selector, address(this)));
        _builder.withMeta("name", "value");
        vm.expectRevert(abi.encodeWithSelector(ProposalBuilder.ProposalNotInitialized.selector, address(this)));
        _builder.withDelay(0);
        vm.expectRevert(abi.encodeWithSelector(ProposalBuilder.ProposalNotInitialized.selector, address(this)));
        _builder.withDuration(0);
        vm.expectRevert(abi.encodeWithSelector(ProposalBuilder.ProposalNotInitialized.selector, address(this)));
        _builder.build();
    }

    function testWithDuration(uint256 _duration) public {
        vm.assume(
            _duration >= _class.minimumVoteDuration() &&
                _duration <= _class.maximumVoteDuration() &&
                _duration < Constant.UINT_MAX - _class.minimumVoteDelay() - block.timestamp
        );
        uint256 pid = _builder.aProposal().withDuration(_duration).build();
        uint256 voteDuration = _storage.voteDuration(pid);
        assertEq(voteDuration, _duration);
    }

    function testWithDelay(uint256 _delay) public {
        vm.assume(
            _delay >= _class.minimumVoteDelay() &&
                _delay <= _class.maximumVoteDelay() &&
                _delay < Constant.UINT_MAX - _class.minimumVoteDuration() - block.timestamp
        );
        uint256 pid = _builder.aProposal().withDelay(_delay).build();
        uint256 voteDelay = _storage.voteDelay(pid);
        assertEq(voteDelay, _delay);
    }

    function testWithQuorum(uint256 _quorum) public {
        vm.assume(_quorum >= _class.minimumProjectQuorum());
        uint256 pid = _builder.aProposal().withQuorum(_quorum).build();
        uint256 quorum = _storage.quorumRequired(pid);
        assertEq(quorum, _quorum);
    }

    function testWithMeta() public {
        uint256 pid = _builder.aProposal().withMeta("bab", "zy").build();
        Meta memory meta = _meta.get(pid, _meta.size(pid));
        assertEq(meta.name, "bab");
        assertEq(meta.value, "zy");
    }

    function testMetaMustBeOwnedByBuilder() public {
        _builder.aProposal().withMeta("bab", "zy");
        vm.prank(address(_builder), address(_builder));
        Ownable mOwnable = Ownable(address(_meta));
        mOwnable.transferOwnership(address(this));
        vm.expectRevert(abi.encodeWithSelector(ProposalBuilder.MetaNotOwned.selector, address(_meta)));
        _builder.build();
    }

    function testWithDescription() public {
        uint256 pid = _builder.aProposal().withDescription("a fair proposal", "https://collective.xyz").build();
        assertEq(_meta.description(pid), "a fair proposal");
        assertEq(_meta.url(pid), "https://collective.xyz");
    }

    function testWithTransaction() public {
        uint256 scheduleTime = block.timestamp + Constant.TIMELOCK_MINIMUM_DELAY;
        Transaction memory t = Transaction(address(0x123), 4, "get()", "000000", scheduleTime);
        uint256 pid = _builder.aProposal().withTransaction(t.target, t.value, t.signature, t._calldata, t.scheduleTime).build();
        Transaction memory storedT = _storage.getTransaction(pid, _storage.transactionCount(pid));
        assertEq(storedT.target, t.target);
        assertEq(storedT.value, t.value);
        assertEq(storedT.signature, t.signature);
        assertEq(storedT._calldata, t._calldata);
        assertEq(storedT.scheduleTime, t.scheduleTime);
    }

    function testWithoutChoice() public {
        uint256 pid = _builder.aProposal().build();
        assertFalse(_storage.isChoiceVote(pid));
    }

    function testAddChoice() public {
        Choice memory choice = Choice("zz", "first choice", 0, 0x0, 0);
        uint256 pid = _builder.aProposal().withChoice(choice.name, choice.description, choice.transactionId).build();
        Choice memory storeChoice = _storage.getChoice(pid, _storage.choiceCount(pid));
        assertEq(storeChoice.name, choice.name);
        assertEq(storeChoice.description, choice.description);
        assertEq(storeChoice.transactionId, choice.transactionId);
        assertEq(storeChoice.txHash, choice.txHash);
        assertEq(storeChoice.voteCount, choice.voteCount);
        assertTrue(_storage.isChoiceVote(pid));
    }

    function mockGovernance() private returns (address) {
        address mock = address(0x100);
        return mockConforming(mock, Constant.CURRENT_VERSION, true);
    }

    function mockStorage() private returns (address) {
        address mock = address(0x200);
        return mockConforming(mock, Constant.CURRENT_VERSION, true);
    }

    function mockMetaStorage() private returns (address) {
        address mock = address(0x300);
        return mockConforming(mock, Constant.CURRENT_VERSION, true);
    }

    function mockConforming(address _mock, uint256 version, bool isConforming) private returns (address) {
        vm.mockCall(_mock, abi.encodeWithSelector(IERC165.supportsInterface.selector), abi.encode(isConforming));
        vm.mockCall(_mock, abi.encodeWithSelector(Versioned.version.selector), abi.encode(version));
        Versioned eMock = Versioned(_mock);
        assertEq(eMock.version(), version);
        return _mock;
    }

    function transferOwnership(address _ownedObject, address _targetOwner) private {
        Ownable _ownableStorage = Ownable(_ownedObject);
        _ownableStorage.transferOwnership(_targetOwner);
    }
}

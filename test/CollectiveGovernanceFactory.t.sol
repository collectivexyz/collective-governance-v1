// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "forge-std/Test.sol";

import "../contracts/Storage.sol";
import "../contracts/StorageFactory.sol";
import "../contracts/VoterClassFactory.sol";
import "../contracts/CollectiveGovernanceFactory.sol";

import "./TestData.sol";

contract CollectiveGovernanceFactoryTest is Test {
    address public constant _OWNER = address(0x1001);

    VoterClass private _class;
    Storage private _storage;
    TimeLocker private _timeLock;
    address[] private _supervisorList;
    CollectiveGovernanceFactory private _governanceFactory;

    function setUp() public {
        VoterClassCreator _vcCreator = new VoterClassFactory();
        address vcAddress = _vcCreator.createOpenVote(1);
        _class = VoterClass(vcAddress);
        _storage = new StorageFactory().create(
            _class,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION
        );
        _timeLock = new TimeLock(Constant.TIMELOCK_MINIMUM_DELAY);
        _supervisorList = new address[](1);
        _supervisorList[0] = _OWNER;
        _governanceFactory = new CollectiveGovernanceFactory();
    }

    function testFailUrlTooLarge() public {
        _governanceFactory.create(
            _supervisorList,
            _class,
            _storage,
            _timeLock,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            "",
            TestData.pi1kplus(),
            ""
        );
    }

    function testFailDescriptionTooLarge() public {
        _governanceFactory.create(
            _supervisorList,
            _class,
            _storage,
            _timeLock,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            "",
            "",
            TestData.pi1kplus()
        );
    }

    function testFailSupervisorListIsEmpty() public {
        _governanceFactory.create(
            new address[](0),
            _class,
            _storage,
            _timeLock,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            "",
            "",
            ""
        );
    }

    function testFailGasUsedTooLow() public {
        _governanceFactory.create(
            _supervisorList,
            _class,
            _storage,
            _timeLock,
            Constant.MAXIMUM_REBATE_GAS_USED - 1,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            "",
            "",
            ""
        );
    }

    function testFailBaseFeeTooLow() public {
        _governanceFactory.create(
            _supervisorList,
            _class,
            _storage,
            _timeLock,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE - 1,
            "",
            "",
            ""
        );
    }

    function testCreateNewGovernance() public {
        Governance governance = _governanceFactory.create(
            _supervisorList,
            _class,
            _storage,
            _timeLock,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE,
            "",
            "",
            ""
        );
        assertTrue(governance.supportsInterface(type(Governance).interfaceId));
    }

    function testCreateNewGovernanceGasRebate() public {
        Governance governance = _governanceFactory.create(
            _supervisorList,
            _class,
            _storage,
            _timeLock,
            Constant.MAXIMUM_REBATE_GAS_USED + 1,
            Constant.MAXIMUM_REBATE_BASE_FEE + 7,
            "",
            "",
            ""
        );
        CollectiveGovernance cGovernance = CollectiveGovernance(payable(address(governance)));
        assertEq(cGovernance._maximumGasUsedRebate(), Constant.MAXIMUM_REBATE_GAS_USED + 1);
        assertEq(cGovernance._maximumBaseFeeRebate(), Constant.MAXIMUM_REBATE_BASE_FEE + 7);
    }
}

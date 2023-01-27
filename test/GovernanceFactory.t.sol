// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "forge-std/Test.sol";

import "../contracts/storage/Storage.sol";
import "../contracts/storage/StorageFactory.sol";
import "../contracts/storage/MetaStorage.sol";
import "../contracts/storage/CollectiveMetaStorage.sol";
import "../contracts/community/VoterClassFactory.sol";
import "../contracts/GovernanceFactoryCreator.sol";
import "../contracts/GovernanceFactory.sol";
import "../contracts/GovernanceFactoryProxy.sol";
import "../contracts/access/Versioned.sol";

contract GovernanceFactoryTest is Test {
    address public constant _OWNER = address(0x1001);

    CommunityClass private _class;
    Storage private _storage;
    MetaStorage private _metaStorage;
    TimeLocker private _timeLock;
    address[] private _supervisorList;
    GovernanceFactory private _factoryInstance;
    GovernanceFactoryProxy private _factoryProxy;
    GovernanceFactoryCreator private _governanceFactory;

    function setUp() public {
        VoterClassCreator _vcCreator = new VoterClassFactory();
        address vcAddress = _vcCreator.createOpenVote(1);
        _class = CommunityClass(vcAddress);
        _metaStorage = new CollectiveMetaStorage(
            "collective",
            "https://github.com/collectivexyz/collective-governance-v1",
            "Collective Governance"
        );
        _storage = new StorageFactory().create(_class);
        _timeLock = new TimeLock(Constant.TIMELOCK_MINIMUM_DELAY);
        _supervisorList = new address[](1);
        _supervisorList[0] = _OWNER;
        _factoryInstance = new GovernanceFactory();
        _factoryProxy = new GovernanceFactoryProxy(address(_factoryInstance));
        _governanceFactory = GovernanceFactoryCreator(address(_factoryProxy));
    }

    function testFailSupervisorListIsEmpty() public {
        _governanceFactory.create(
            new address[](0),
            _class,
            _storage,
            _metaStorage,
            _timeLock,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE
        );
    }

    function testFailGasUsedTooLow() public {
        _governanceFactory.create(
            _supervisorList,
            _class,
            _storage,
            _metaStorage,
            _timeLock,
            Constant.MAXIMUM_REBATE_GAS_USED - 1,
            Constant.MAXIMUM_REBATE_BASE_FEE
        );
    }

    function testFailBaseFeeTooLow() public {
        _governanceFactory.create(
            _supervisorList,
            _class,
            _storage,
            _metaStorage,
            _timeLock,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE - 1
        );
    }

    function testCreateNewGovernance() public {
        Governance governance = _governanceFactory.create(
            _supervisorList,
            _class,
            _storage,
            _metaStorage,
            _timeLock,
            Constant.MAXIMUM_REBATE_GAS_USED,
            Constant.MAXIMUM_REBATE_BASE_FEE
        );
        assertTrue(governance.supportsInterface(type(Governance).interfaceId));
    }

    function testCreateNewGovernanceGasRebate() public {
        Governance governance = _governanceFactory.create(
            _supervisorList,
            _class,
            _storage,
            _metaStorage,
            _timeLock,
            Constant.MAXIMUM_REBATE_GAS_USED + 1,
            Constant.MAXIMUM_REBATE_BASE_FEE + 7
        );
        CollectiveGovernance cGovernance = CollectiveGovernance(payable(address(governance)));
        assertEq(cGovernance._maximumGasUsedRebate(), Constant.MAXIMUM_REBATE_GAS_USED + 1);
        assertEq(cGovernance._maximumBaseFeeRebate(), Constant.MAXIMUM_REBATE_BASE_FEE + 7);
    }

    function testSupportsIERC165() public {
        bytes4 ifId = type(IERC165).interfaceId;
        assertTrue(_governanceFactory.supportsInterface(ifId));
    }

    function testSupportsGovernanceFactoryCreator() public {
        bytes4 ifId = type(GovernanceFactoryCreator).interfaceId;
        assertTrue(_governanceFactory.supportsInterface(ifId));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_governanceFactory.supportsInterface(ifId));
    }

    function testProxyUpgrade() public {
        UUPSUpgradeable __uups = UUPSUpgradeable(address(_factoryProxy));
        ForwardGovernanceFactory fgFactory = new ForwardGovernanceFactory();
        __uups.upgradeTo(address(fgFactory));
        ForwardGovernanceFactory fgByProxy = ForwardGovernanceFactory(address(_factoryProxy));
        // check upgraded
        assertTrue(fgByProxy.isUpgraded());
    }
}

// for testing
contract ForwardGovernanceFactory is GovernanceFactory {
    function isUpgraded() public pure returns (bool) {
        return true;
    }
}
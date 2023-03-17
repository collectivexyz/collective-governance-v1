// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import { Test } from "forge-std/Test.sol";

import { Constant } from "../../contracts/Constant.sol";
import { Storage } from "../../contracts/storage/Storage.sol";
import { StorageFactory } from "../../contracts/storage/StorageFactory.sol";
import { MetaStorage } from "../../contracts/storage/MetaStorage.sol";
import { MappedMetaStorage } from "../../contracts/storage/MappedMetaStorage.sol";
import { CommunityClass } from "../../contracts/community/CommunityClass.sol";
import { CommunityBuilder } from "../../contracts/community/CommunityBuilder.sol";
import { Governance } from "../../contracts/governance/Governance.sol";
import { GovernanceFactory } from "../../contracts/governance/GovernanceFactory.sol";
import { TimeLocker } from "../../contracts/treasury/TimeLocker.sol";
import { TimeLock } from "../../contracts/treasury/TimeLock.sol";
import { Versioned } from "../../contracts/access/Versioned.sol";

contract GovernanceFactoryTest is Test {
    address public constant _OWNER = address(0x1001);

    CommunityClass private _class;
    Storage private _storage;
    MetaStorage private _metaStorage;
    TimeLocker private _timeLock;
    GovernanceFactory private _governanceFactory;

    function setUp() public {
        CommunityBuilder _vcCreator = new CommunityBuilder();
        address vcAddress = _vcCreator.aCommunity().asOpenCommunity().withQuorum(1).withCommunitySupervisor(_OWNER).build();
        _class = CommunityClass(vcAddress);
        _metaStorage = new MappedMetaStorage(
            "collective",
            "https://github.com/collectivexyz/collective-governance-v1",
            "Collective Governance"
        );
        _storage = new StorageFactory().create(_class);
        _timeLock = new TimeLock(Constant.TIMELOCK_MINIMUM_DELAY);
        _governanceFactory = new GovernanceFactory();
    }

    function testCreateNewGovernance() public {
        Governance governance = _governanceFactory.create(_class, _storage, _timeLock);
        assertTrue(governance.supportsInterface(type(Governance).interfaceId));
    }

    function testSupportsIERC165() public {
        bytes4 ifId = type(IERC165).interfaceId;
        assertTrue(_governanceFactory.supportsInterface(ifId));
    }

    function testSupportsInterfaceVersioned() public {
        bytes4 ifId = type(Versioned).interfaceId;
        assertTrue(_governanceFactory.supportsInterface(ifId));
    }
}

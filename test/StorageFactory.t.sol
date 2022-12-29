// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "forge-std/Test.sol";

import "../contracts/Storage.sol";
import "../contracts/StorageFactory.sol";
import "../contracts/VoterClassFactory.sol";
import "../contracts/access/Upgradeable.sol";

import "./TestData.sol";

contract StorageFactoryTest is Test {
    VoterClass private _class;
    StorageFactory private _storageFactory;

    function setUp() public {
        VoterClassCreator _vcCreator = new VoterClassFactory();
        address vcAddress = _vcCreator.createOpenVote(1);
        _class = VoterClass(vcAddress);
        _storageFactory = new StorageFactory();
    }

    function testSetupNewStorage() public {
        Storage _storage = _storageFactory.create(
            _class,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION
        );
        assertTrue(_storage.supportsInterface(type(Storage).interfaceId));
    }

    function testIsStorageOwner() public {
        Storage _storage = _storageFactory.create(
            _class,
            Constant.MINIMUM_PROJECT_QUORUM,
            Constant.MINIMUM_VOTE_DELAY,
            Constant.MINIMUM_VOTE_DURATION
        );
        Ownable _ownable = Ownable(address(_storage));
        assertEq(_ownable.owner(), address(this));
    }

    function testSupportsIERC165() public {
        bytes4 ifId = type(IERC165).interfaceId;
        assertTrue(_storageFactory.supportsInterface(ifId));
    }

    function testSupportsGovernanceFactoryCreator() public {
        bytes4 ifId = type(StorageFactoryCreator).interfaceId;
        assertTrue(_storageFactory.supportsInterface(ifId));
    }

    function testSupportsInterfaceUpgradeable() public {
        bytes4 ifId = type(Upgradeable).interfaceId;
        assertTrue(_storageFactory.supportsInterface(ifId));
    }
}

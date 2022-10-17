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
    address[] private _supervisorList;

    function setUp() public {
        VoterClassCreator _vcCreator = new VoterClassFactory();
        address vcAddress = _vcCreator.createOpenVote(1);
        _class = VoterClass(vcAddress);
        _storage = StorageFactory.create(_class, Constant.MINIMUM_VOTE_DURATION);
        _supervisorList = new address[](1);
        _supervisorList[0] = _OWNER;
    }

    function testFailUrlTooLarge() public {
        CollectiveGovernanceFactory.create(_supervisorList, _class, _storage, "", TestData.pi1kplus(), "");
    }

    function testFailDescriptionTooLarge() public {
        CollectiveGovernanceFactory.create(_supervisorList, _class, _storage, "", "", TestData.pi1kplus());
    }

    function testFailSupervisorListIsEmpty() public {
        CollectiveGovernanceFactory.create(new address[](0), _class, _storage, "", "", "");
    }

    function testCreateNewGovernance() public {
        Governance governance = CollectiveGovernanceFactory.create(_supervisorList, _class, _storage, "", "", "");
        assertTrue(governance.supportsInterface(type(Governance).interfaceId));
    }
}

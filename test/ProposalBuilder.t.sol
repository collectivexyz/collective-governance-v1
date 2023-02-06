// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "forge-std/Test.sol";

import "../contracts/Constant.sol";
import "../contracts/ProposalBuilder.sol";
import "../contracts/Governance.sol";
import "../contracts/storage/Storage.sol";
import "../contracts/storage/MetaStorage.sol";
import "../contracts/access/Versioned.sol";
import "../contracts/GovernanceBuilder.sol";
import "../contracts/community/CommunityBuilder.sol";

contract ProposalBuilderTest is Test {
    address private constant _OWNER = address(0x1);
    address private constant _CREATOR = address(0x2);
    address private constant _VOTER1 = address(0xfff1);

    ProposalBuilder private _proposalBuilder;

    function setUp() public {
        address _class = new CommunityBuilder().aCommunity().asOpenCommunity().withQuorum(1).build();
        (address payable _govAddr, address _stoAddr, address _metaAddr) = new GovernanceBuilder()
            .aGovernance()
            .withSupervisor(_CREATOR)
            .withCommunityClassAddress(_class)
            .build();
        transferOwnership(_metaAddr, address(this));
        _proposalBuilder = new ProposalBuilder(_govAddr, _stoAddr, _metaAddr);
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
        address _storage = mockStorage();
        address _meta = mockConforming(address(0x10), Constant.CURRENT_VERSION - 1, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                ProposalBuilder.VersionMismatch.selector,
                Constant.CURRENT_VERSION,
                Constant.CURRENT_VERSION - 1
            )
        );
        new ProposalBuilder(_gov, _storage, _meta);
    }

    function testRequiresGovernance() public {
        address _gov = mockConforming(address(0x10), Constant.CURRENT_VERSION, false);
        address _storage = mockStorage();
        address _meta = mockMetaStorage();
        vm.expectRevert(abi.encodeWithSelector(ProposalBuilder.NotGovernance.selector, _gov));
        new ProposalBuilder(_gov, _storage, _meta);
    }

    function testRequiresStorage() public {
        address _gov = mockGovernance();
        address _storage = mockConforming(address(0x11), Constant.CURRENT_VERSION, false);
        address _meta = mockMetaStorage();
        vm.expectRevert(abi.encodeWithSelector(ProposalBuilder.NotStorage.selector, _storage));
        new ProposalBuilder(_gov, _storage, _meta);
    }

    function testRequiresMeta() public {
        address _gov = mockGovernance();
        address _storage = mockStorage();
        address _meta = mockConforming(address(0x12), Constant.CURRENT_VERSION, false);
        vm.expectRevert(abi.encodeWithSelector(ProposalBuilder.NotMetaStorage.selector, _meta));
        new ProposalBuilder(_gov, _storage, _meta);
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

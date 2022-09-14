// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

import "forge-std/Test.sol";

import "../contracts/VoterClassFactory.sol";

contract VoterClassFactoryTest is Test {
    VoterClassFactory private _factory;

    address private constant _ERC721 = address(0x111f);
    address private constant NONE = address(0x0);

    function setUp() public {
        _factory = new VoterClassFactory();
    }

    function testOpenVote() public {
        address ovClass = _factory.createOpenVote(1);
        IERC165 erc165 = IERC165(ovClass);
        assertTrue(erc165.supportsInterface(type(VoterClass).interfaceId));
        assertTrue(ovClass != NONE);
    }

    function testERC721() public {
        address ercClass = _factory.createERC721(_ERC721, 1);
        IERC165 erc165 = IERC165(ercClass);
        assertTrue(erc165.supportsInterface(type(VoterClass).interfaceId));
        assertTrue(ercClass != NONE);
    }

    function testVoterPool() public {
        address voterPool = _factory.createVoterPool(1);
        IERC165 erc165 = IERC165(voterPool);
        assertTrue(erc165.supportsInterface(type(VoterClass).interfaceId));
        assertTrue(voterPool != NONE);
    }
}

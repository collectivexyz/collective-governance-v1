// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "forge-std/Test.sol";

import "../contracts/System.sol";

contract SystemTest is Test {
    function testFailSystemRequiresBuilder() public {
        IERC165 erc165 = new Mock165();
        new System(address(erc165));
    }
}

// solhint-disable-next-line no-empty-blocks
contract Mock165 is ERC165 {

}

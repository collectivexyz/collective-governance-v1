// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable not-rely-on-time
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";
import { Constant } from "../contracts/Constant.sol";

contract ConstantTest is Test {
    function testStringLength() public {
        string memory pi = "3.141592653589793238462643383279503";
        assertEq(Constant.len(pi), 35);
    }

    function testEmptyString() public {
        assertTrue(Constant.empty(""));
        assertFalse(Constant.empty("0"));
    }
}

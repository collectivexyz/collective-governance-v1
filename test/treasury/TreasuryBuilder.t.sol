// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { TreasuryBuilder } from "../../contracts/treasury/TreasuryBuilder.sol";

contract TreasuryBuilderTest is Test {

    TreasuryBuilder private _builder;

    function setUp() public {
        vm.clearMockedCalls();
        _builder = new TreasuryBuilder();
    }

}
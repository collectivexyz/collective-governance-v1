// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable not-rely-on-time
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";

import { calculateGasRebate } from "../../contracts/governance/CollectiveGovernance.sol";

contract GasRebateTest is Test {
    function testGasRebate() public {
        uint256 startGas = gasleft();
        (uint256 gasRebate, uint256 gasUsed) = calculateGasRebate(startGas, 1 ether, 200 gwei, 200000);
        assertApproxEqAbs(gasRebate, 72234 gwei, 5000 gwei);
        assertTrue(gasUsed > 0);
    }

    function testMaximumRebate(uint256 gasLimit) public {
        vm.assume(gasLimit >= 30 gwei && gasLimit <= 200 gwei);
        uint256 testNetGas = 251154;
        uint256 startGas = gasleft();
        uint i;
        do {
            i = 3 * 13 * startGas;
        } while (startGas - gasleft() < testNetGas);
        (uint256 gasRebate, uint256 gasUsed) = calculateGasRebate(startGas, gasLimit, 200 gwei, 200000);
        emit log_uint(gasRebate);
        assertEq(gasRebate, gasLimit);
        emit log_uint(gasUsed);
        assertTrue(gasUsed >= testNetGas);
    }

    function testRebateRealWorldTarget(uint256 gasUsedTarget) public {
        vm.assume(gasUsedTarget > 30000 && gasUsedTarget < 255000);
        uint256 startGas = gasleft();
        uint i;
        do {
            i = 3 * 13 * startGas;
        } while (startGas - gasleft() < gasUsedTarget);
        (uint256 gasRebate, uint256 gasUsed) = calculateGasRebate(startGas, 2000 gwei, 200 gwei, 200000);
        emit log_uint(gasRebate);
        assertEq(gasRebate, 2000 gwei);
        emit log_uint(gasUsed);
        assertTrue(gasUsed >= gasUsedTarget);
    }
}

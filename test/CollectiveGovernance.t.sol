// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/VoteStrategy.sol";
import "../contracts/ElectorVoterPoolStrategy.sol";
import "../contracts/UpgradeableGovernance.sol";
import "../contracts/CollectiveGovernance.sol";

contract CollectiveGovernanceTest is Test {
    UpgradeableGovernance private governance;

    address public immutable owner = msg.sender;
    address public immutable someoneElse = address(0x123);
    uint32 private version;

    function setUp() public {
        governance = new CollectiveGovernance();
        version = new ElectorVoterPoolStrategy().version();
    }

    function testGetVoteStrategy() public {
        uint32 strategyVersion = governance.getCurrentStrategyVersion();
        assertEq(version, strategyVersion);
    }

    function testFailSetStrategyAsSomeoneElse() public {
        VoteStrategy evp = new ElectorVoterPoolStrategy();
        vm.prank(someoneElse);
        governance.setVoteStrategy(address(evp));
    }

    function testAllowUpgradeOwner() public {
        VoteStrategy evp = new ElectorVoterPoolStrategy();
        governance.setVoteStrategy(address(evp));
        assertEq(version, governance.getCurrentStrategyVersion());
    }
}

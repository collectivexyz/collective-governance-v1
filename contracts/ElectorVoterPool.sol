// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "./VoterClass.sol";
import "./VoterClassNullObject.sol";

/// @title ElectorVoterPool

// GovernorBravoDelegate.sol source code Copyright 2020 Compound Labs, Inc. licensed under the BSD-3-Clause license.
// NounsDAOLogicV1.sol source code Copyright 2020 Nounders DAO. licensed under the BSD-3-Clause license.
// This source code developed by Collective.xyz, Copyright 2022.

// a proposal is subject to approval by an elector voter pool, a specific group of supervisors has the authority to add and remove voters, to open and close voting
// and to veto the result of the vote as in the case of a failure of the election design

// modification to the vote and supervisor pools is only allowed prior to the opening of voting
// 'affirmative' vote must be cast by calling voteFor
// 'abstention' or 'negative' vote incurs no gas fees and every registered voter is default negative

// measure is considered passed when the threshold voter count is achieved out of the current voting pool

contract ElectorVoterPool {
    // event section
    event AddSupervisor(address supervisor);
    event BurnSupervisor(address supervisor);
    event RegisterVoter(address voter);
    event BurnVoter(address voter);
    event RegisterVoterClass();
    event BurnVoterClass();
    event SetPassThreshold(uint256 passThreshold);
    event VotingOpen();
    event VotingClosed();
    event VoteCast(address voter, uint256 totalVotesCast);
    event UndoVoteEnabled();
    event VoteVeto();

    /// @notice contract name
    string public constant name = "collective.xyz Governance Delegate";
    uint256 public constant MAXIMUM_PASS_THRESHOLD = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    mapping(address => bool) public supervisorPool;
    mapping(address => bool) public voterPool;
    mapping(address => bool) public voteCast;

    uint256 public totalVoterPool;
    uint256 public totalSupervisorPool;
    uint256 public totalVotesCast;

    uint256 public requiredPassThreshold;

    address public owner;
    bool public isVotingOpen;
    bool public isVotingPrelim;
    bool public isSupervisorVeto;
    bool public isUndoEnabled;

    VoterClass private _voterClass;

    constructor() {
        owner = msg.sender;
        totalVoterPool = 0;
        totalVotesCast = 0;

        requiredPassThreshold = MAXIMUM_PASS_THRESHOLD;

        isVotingOpen = false;
        isVotingPrelim = true;
        isSupervisorVeto = false;
        isUndoEnabled = false;
        _voterClass = new VoterClassNullObject();
    }

    modifier requireContractOwner() {
        require(owner == msg.sender, "Not contract owner");
        _;
    }

    modifier requireElectorSupervisor() {
        require(supervisorPool[msg.sender] == true, "Operation requires elector supervisor");
        _;
    }

    modifier requireVoter() {
        require(voterPool[msg.sender] == true || _voterClass.isVoter(msg.sender), "Voter required");
        _;
    }

    modifier requireVotingOpen() {
        require(isVotingOpen, "Voting is closed.");
        _;
    }

    modifier requireVotingClosed() {
        require(!isVotingOpen && !isVotingPrelim && !isSupervisorVeto, "Voting is not closed.");
        _;
    }

    modifier requireVotingPrelim() {
        require(isVotingPrelim && !isVotingOpen, "Vote not modifiable.");
        _;
    }

    modifier requireUndo() {
        require(isUndoEnabled, "Undo not enabled for this vote");
        _;
    }

    /// @notice add a vote superviser to the supervisor pool with rights to add or remove voters prior to start of voting, also right to veto the outcome after voting is closed
    function registerSupervisor(address _supervisor) public requireContractOwner requireVotingPrelim {
        if (supervisorPool[_supervisor] == false) {
            supervisorPool[_supervisor] = true;
            totalSupervisorPool++;
            emit AddSupervisor(_supervisor);
        }
    }

    /// @notice remove the supervisor from the supervisor pool suspending their rights to modify the election
    function burnSupervisor(address _supervisor) public requireContractOwner requireVotingPrelim {
        if (supervisorPool[_supervisor] == true) {
            supervisorPool[_supervisor] = false;
            totalSupervisorPool--;
            emit AddSupervisor(_supervisor);
        }
    }

    /// @notice enable vote undo feature
    function enableUndoVote() public requireElectorSupervisor requireVotingPrelim {
        isUndoEnabled = true;
        emit UndoVoteEnabled();
    }

    /// @notice register a voter on this measure
    function registerVoter(address _voter) public requireElectorSupervisor requireVotingPrelim {
        if (voterPool[_voter] == false) {
            voterPool[_voter] = true;
            totalVoterPool++;
            emit RegisterVoter(_voter);
        }
    }

    /// @notice register a list of voters on this measure
    function registerVoters(address[] memory _voter) public requireElectorSupervisor requireVotingPrelim {
        uint256 addedCount = 0;
        for (uint256 i = 0; i < _voter.length; i++) {
            if (voterPool[_voter[i]] == false) {
                voterPool[_voter[i]] = true;
                emit RegisterVoter(_voter[i]);
            }
            addedCount++;
        }
        totalVoterPool += addedCount;
    }

    /// @notice burn the specified voter, removing their rights to participate in the election
    function burnVoter(address _voter) public requireElectorSupervisor requireVotingPrelim {
        if (voterPool[_voter] == true) {
            voterPool[_voter] = false;
            totalVoterPool--;
            emit BurnVoter(_voter);
        }
    }

    /// @notice register a voting class for this measure
    function registerVoterClass(VoterClass _class) public requireElectorSupervisor requireVotingPrelim {
        _voterClass = _class;
        emit RegisterVoterClass();
    }

    /// @notice burn voter class
    function burnVoterClass() public requireElectorSupervisor requireVotingPrelim {
        _voterClass = new VoterClassNullObject();
        emit BurnVoterClass();
    }

    /// @notice establish the pass threshold for this measure
    function setPassThreshold(uint256 _passThreshold) public requireElectorSupervisor requireVotingPrelim {
        requiredPassThreshold = _passThreshold;
        emit SetPassThreshold(_passThreshold);
    }

    /// @notice allow voting
    function openVoting() public requireElectorSupervisor requireVotingPrelim {
        require(requiredPassThreshold < MAXIMUM_PASS_THRESHOLD, "PassThreshold must be set prior to opening vote");
        isVotingOpen = true;
        isVotingPrelim = false;
        emit VotingOpen();
    }

    /// @notice forbid any further voting
    function endVoting() public requireElectorSupervisor requireVotingOpen {
        isVotingOpen = false;
        emit VotingClosed();
    }

    // @notice cast an affirmative vote for the measure
    function voteFor() public requireVoter requireVotingOpen {
        if (voteCast[msg.sender] == false) {
            voteCast[msg.sender] = true;
            uint256 votesAvailable = _voterClass.votesAvailable(msg.sender);
            totalVotesCast = add256(totalVotesCast, votesAvailable);
            emit VoteCast(msg.sender, votesAvailable);
        } else {
            revert("Vote cast previously on this measure");
        }
    }

    // @notice undo any previous vote
    function undoVote() public requireUndo requireVoter requireVotingOpen {
        if (voteCast[msg.sender] == true) {
            voteCast[msg.sender] = false;
            totalVotesCast--;
        } else {
            revert("Never voted");
        }
    }

    /// @notice veto the current measure
    function veto() public requireElectorSupervisor requireVotingOpen {
        if (!isSupervisorVeto) {
            isSupervisorVeto = true;
            emit VoteVeto();
        } else {
            revert("Double veto");
        }
    }

    /// @notice get the result of the measure pass or failed
    function getResult() public view requireVotingClosed returns (bool) {
        return totalVotesCast >= requiredPassThreshold;
    }

    function add256(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "add256 overflow");
        return c;
    }
}

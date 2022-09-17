===============
Getting Started
===============


:ref:`Collective Governance <collectivegovernance>` implements a flexible approach to voting to support a wide variety of communities.   Each community can define the individuals who may participate in governance decision making by defining a :ref:`VoterClass <VoterClass>`.   The VoterClass defines the characteristics of the voting population and determines if the wallet is in or out for a particular vote.


Types of VoterClass:

* Open Voting
* ERC-721 Token (including ERC-721 Enumerable)
* Pool Voting - based on a specific list of voters


Once the proper VoterClass has been established, an online community can build a new Governance Contract.  The :ref:`<GovernanceBuilder>` provides a convienient method to create a new Governance Contract.

To build a GovernanceBuilder a VoterClass must be provided, specified by the address as well as one or more :ref:`<Supervisors>` who may configure voting parameters as well as veto vote outcomes which are not in the best interest of the community.


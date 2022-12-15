===============
Getting Started
===============


:ref:`Collective Governance <collectivegovernance>` implements a flexible approach to voting to support a wide variety of communities.   Each community can define the individuals who may participate in governance decision making by defining a :ref:`VoterClass <VoterClass>`.   The VoterClass defines the characteristics of the voting population and determines if the wallet is in or out for a particular vote.   

Setting up a Governance contract is a two step process.


Build a VoterClass
___________________

VoterClass Implementations:

* Open voting - :ref:`VoterClassOpenVote <VoterClassOpenVote>`
* ERC-721 Token voting (including ERC-721 Enumerable) - :ref:`VoterClassERC721 <VoterClassERC721>`
* Pool voting - based on a specific list of voters - :ref:`VoterClassVoterPool <VoterClassVoterPool>`

Create the Governance contract
_______________________________

Once the :ref:`VoterClass <voterclass>` has been created for your community, proceed with building a :ref:`Governance <Governance` contract.   There are two ways to build a contract.

Builders
========
* :ref:`System <System>` to build a contract with the fewest number of transactions
* :ref:`GovernanceBuilder <GovernanceBuilder>` to build a contract with the fewest number of parameters

Contract Requirements
======================
* :ref:`VoterClass <VoterClass>` The project voter class.  Possibly based on an `ERC-721 <https://erc721.org>` token.
* :ref:`Supervisor <supervisor>` One or more project supervisors to act as a community steward

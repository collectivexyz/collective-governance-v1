.. Collective Governance documentation master file

.. _collectivegovernance:

=================================================
Collective Governance
=================================================

-------------------------------------------------
Open Source Community Governance Smart Contract
-------------------------------------------------

Governance smart contracts are a type of smart contract that allow a community to influence an on-chain governance system or treasury through voting. They can be used to define who participates in the decision-making process, how votes are weighted and counted, and what actions can be taken based on the outcomes. Governance smart contracts can also provide security and transparency for the participants, as well as enable innovation and flexibility for the group or collective.

However, governance smart contracts also face some challenges and limitations. For example, they may require a high level of technical expertise and trust from users, they may be vulnerable to attacks or bugs, and they may not be able to capture all the nuances and complexities of human interactions and agreements. Therefore, governance smart contracts need to be carefully designed, tested and audited before deployment.

Collective Governance attempts to address all of the above concerns by providing an on-chain voting system with flexible plug-and-play community definitions and easy building blocks for creating communities. Communities may each determine the rules for voting and interacting separately from one another without requiring code changes, reviews or deployments. Collective Governance also provides a pluggable mechanism for defining the community itself, possibly as membership in a pre-defined voting pool or as a collective who all hold a particular token.

Collective Governance has been designed from the ground up to be very easy to use. It uses an easily-understandable building block approach to creating a community and managing proposals and voting on that community. Therefore Collective Governance addresses many of the concerns and issues present in existing Governance contracts.

.. toctree::
   :maxdepth: 2
   :caption: Contents:

   gettingstarted
   javascript_example
   api
   supervisor
   license

.. _deployment:

Contract Deployment Details
===========================

Görli Testnet
_____________

=====================  ==========================================  =========== ===========================
Contract               Ethereum Address                            Version     Description
=====================  ==========================================  =========== ===========================
`Constant`_            0xE92C637eC797934574D31D319B4bD1eca182e7F1  0.9.7       Constant library
`CommunityBuilder`_    0x011b543b69236aca83406edc051e8a6dd3bcda1c  0.9.7       CommunityBuilder Factory
`GovernanceBuilder`_   0x2c57560BF19b7c088488104D02506D87f63e414C  0.9.7       Governance Contract Builder
=====================  ==========================================  =========== ===========================

Project Links
=============
* `GitHub`_
* `JavaScript API`_
* `JavaScript Reference`_ Implementation
  
.. _GitHub: https://github.com/collectivexyz/collective-governance-v1
.. _JavaScript API: https://github.com/collectivexyz/governance
.. _JavaScript Reference: https://github.com/collectivexyz/collective_governance_js
.. _Constant: https://goerli.etherscan.io/address/0xE92C637eC797934574D31D319B4bD1eca182e7F1 
.. _CommunityBuilder: https://goerli.etherscan.io/address/0x011b543b69236aca83406edc051e8a6dd3bcda1c  
.. _GovernanceBuilder: https://goerli.etherscan.io/address/0x2c57560BF19b7c088488104D02506D87f63e414C
.. _System: https://goerli.etherscan.io/address/0xDb6f31A20996e265FB59406675261F3fcC0bDe6f

Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`

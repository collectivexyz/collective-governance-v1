JavaScript Examples
===================

Examples based on `JavaScript Reference`_.   ABI files are available from `GitHub`_

.. _javascript:

VoterClass
----------

The first step is to build a VoterClass for your project.  This can be reused for all future projects and voting.

.. code-block:: javascript
                
      const voterClassFactory = new VoterClassFactory(...);
      const classAddress = await voterClassFactory.createERC721(config.tokenContract, 1);
      logger.info(`VoterClass created at ${classAddress}`);

Make a note of the Ethereum address for the class you created.  For example `0x6bAc373e27f844259F3B79A6E7dAFf3868eBDc13 <https://goerli.etherscan.io/address/0x6bAc373e27f844259F3B79A6E7dAFf3868eBDc13>`_

Governance
----------

The next step is to build the Governance Contract for your community.   This will take the VoterClass as an argument and reuse it for all future votes.

.. code-block:: javascript
                
      const governanceBuilder = new GovernanceBuilder(config.abiPath, config.builderAddress, web3, wallet, config.getGas());
      const name = await governanceBuilder.name();
      logger.info(name);
      await governanceBuilder.aGovernance();
      await governanceBuilder.withSupervisor(wallet.getAddress());
      await governanceBuilder.withVoterClassAddress(config.voterClass);
      const governanceAddress = await governanceBuilder.build();
      logger.info(`Governance contract created at ${governanceAddress}`);

Make a note of the address of the created contract as this will be used for all future governance calls.


Voting
______

Now you can create proposals using the governance contract.

.. code-block:: javascript

    const web3 = new Web3(config.rpcUrl);

    const wallet = new EthWallet(config.privateKey, web3);
    wallet.connect();
    logger.info(`Wallet connected: ${wallet.getAddress()}`);
    const governance = new CollectiveGovernance(config.abiPath, config.contractAddress, web3, wallet, config.getGas());
    logger.info(`Connected to contract: ${config.contractAddress}`);
    const name = await governance.name();
    const version = await governance.version();
    logger.info(`${name}: ${version}`);
    const storageAddress = await governance.getStorageAddress();
    const storage = new Storage(config.abiPath, storageAddress, web3);
    const storageName = await storage.name();
    const storageVersion = await storage.version();
    logger.info(`${storageName}: ${storageVersion}`);
    const proposalId = await governance.propose();


Next configure the proposal and open voting

.. code-block:: javascript    

    await governance.configure(proposalId, 1, 5);
    const quorum = await storage.quorumRequired(proposalId);
    const duration = await storage.voteDuration(proposalId);
    logger.info(`New Vote - ${proposalId}: quorum=${quorum}, duration=${duration}`);
    await governance.openVote(proposalId);
    logger.info('Voting is open...');


Finally just vote                

.. code-block:: javascript

    await governance.voteFor(proposalId);


.. _GitHub: https://github.com/momentranks/collective-governance-v1
.. _JavaScript Reference: https://github.com/momentranks/collective_governance_js


JavaScript Examples
===================

Examples based on `JavaScript Reference`_ and use `JavaScript API`_. ABI files are available from `GitHub`_

The first step is to install the latest `JavaScript API`_: see the instructions and `release <https://github.com/collectivexyz/governance/pkgs/npm/governance>` information.

.. _javascript:

Connect 
________

The following code block demonstrates how to connect to the Ethereum RPC client

.. code-block:: javascript
    import { EthWallet, Governance, GovernanceBuilder, CollectiveGovernance } from '@collectivexyz/governance';
    import Web3 from 'web3';

    export async function connect(): Promise<Governance> {
    try {
        const rpcUrl = 'wss://localhost:8545';
        const privateKey = 'XXXXXXXXXXXX';
        const abiPath = 'node_modules/@collectivexyz/governance/abi';
        const builderAddress = '0xd64f3Db037B263D54561a2cc9885Db370B51E354';
        const buildTransaction = '0x0f7f3e13055547b8b6ac5b28285abc960266c6297094ab451ca9de318cbf5906';
        const maximumGas = 600000;

        const web3 = new Web3(rpcUrl);

        const wallet = new EthWallet(privateKey, web3);
        wallet.connect();
        const builder = new GovernanceBuilder(abiPath, builderAddress, web3, wallet, maximumGas);
        const contractAddress = await builder.discoverContract(buildTransaction);
        const governance = new CollectiveGovernance(abiPath, contractAddress.governanceAddress, web3, wallet, maximumGas);
        const name = await governance.name();
        const version = await governance.version();

        return governance;
    } catch (error) {
        throw new Error('Run failed');
    }
    }


The next step is to create a VoterClass

VoterClass
----------

The first step to build a :ref:`VoterClass <voterclass>` for your project is to use the Factory.  This can be reused for all future projects.

.. code-block:: javascript
                
      const voterClassFactory = new VoterClassFactory(...);
      const classAddress = await voterClassFactory.createERC721(config.tokenContract, 1);
      logger.info(`VoterClass created at ${classAddress}`);

Make a note of the Ethereum address for the class you created.  For example `0x6bAc373e27f844259F3B79A6E7dAFf3868eBDc13 <https://goerli.etherscan.io/address/0x6bAc373e27f844259F3B79A6E7dAFf3868eBDc13>`_

Governance
----------

The next step is to build the Governance Contract for your community.   This will take the VoterClass as an argument.

.. code-block:: javascript
                
      const governanceBuilder = new GovernanceBuilder(config.abiPath, config.builderAddress, web3, wallet, config.getGas());
      const name = await governanceBuilder.name();
      logger.info(name);
      await governanceBuilder.aGovernance();
      await governanceBuilder.withSupervisor(wallet.getAddress());
      await governanceBuilder.withVoterClassAddress(config.voterClass);
      const governanceAddress = await governanceBuilder.build();
      logger.info(`Governance contract created at ${governanceAddress}`);

Make a note of the address of the created contract as this will be used for all future governance operations.


Voting
______

Now you can introduce a vote using the governance contract.

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
    const proposalId = await governance.propose();


Next configure the proposal and open voting

.. code-block:: javascript    

    await governance.configure(proposalId, 1, 5);
    const storage = new Storage(config.abiPath, storageAddress, web3);
    const storageName = await storage.name();
    const storageVersion = await storage.version();
    logger.info(`${storageName}: ${storageVersion}`);
    const quorum = await storage.quorumRequired(proposalId);
    const duration = await storage.voteDuration(proposalId);
    logger.info(`New Vote - ${proposalId}: quorum=${quorum}, duration=${duration}`);
    await governance.startVote(proposalId);
    logger.info('Voting is open...');

Finally just vote                

.. code-block:: javascript

    await governance.voteFor(proposalId);


.. _GitHub: https://github.com/collectivexyz/collective-governance-v1
.. _JavaScript API: https://github.com/collectivexyz/governance
.. _JavaScript Reference: https://github.com/collectivexyz/collective_governance_js


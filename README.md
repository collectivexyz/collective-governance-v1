# collective-governance-v1

## Open Smart Contract for Community Governance

Open communities exist to serve the common good and therefore should be given an opportunity to make collective decisions about how resources are used or allocated. Such decisions, referred to as 'measures' augment participation and enable communities to become benefactors on a broader scale.

This smart contract enables a measure to be proposed, voted upon and successfully fulfilled. It also provides safety measures to prevent tampering, invalid election design or unexpected system problems from nullifying the possible benefit of a given measure.

### Contract Deployment Details

| Contract          | Ethereum Address | Version |
| ----------------- | ------------------------------------------ | ----- | 
| VoterClassFactory | 0xF9eaeE9363d4C93bAe4b23c761705355f37fFfb0 | 0.8.2 | 
| GovernanceBuilder | 0xfFF82B3c94710305492E974cA56dAeeC74D0FC36 | 0.8.2 | 


### 0.8.2

```
Run forge create --contracts contracts/VoterClassFactory.sol --rpc-url ${DEVNET_RPC_URL} --private-key ${ETH_DEV_PRIVATE} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify VoterClassFactory        
Compiling 36 files with 0.8.17
Solc 0.8.17 finished in 205.79s
Compiler run successful
Deployer: 0x6CEbXXXXXXXXX
Deployed to: 0xF9eaeE9363d4C93bAe4b23c761705355f37fFfb0
Transaction hash: 0xa9adb7f91b31187875eb9c3caff744124bd5bf9affba2ce97821f8ae439a89d2
Starting contract verification...
Waiting for etherscan to detect contract deployment...

Submitting verification for [contracts/VoterClassFactory.sol:VoterClassFactory] "0xF9eaeE9363d4C93bAe4b23c761705355f37fFfb0".

Submitting verification for [contracts/VoterClassFactory.sol:VoterClassFactory] "0xF9eaeE9363d4C93bAe4b23c761705355f37fFfb0".

Submitting verification for [contracts/VoterClassFactory.sol:VoterClassFactory] "0xF9eaeE9363d4C93bAe4b23c761705355f37fFfb0".

Submitting verification for [contracts/VoterClassFactory.sol:VoterClassFactory] "0xF9eaeE9363d4C93bAe4b23c761705355f37fFfb0".

Submitting verification for [contracts/VoterClassFactory.sol:VoterClassFactory] "0xF9eaeE9363d4C93bAe4b23c761705355f37fFfb0".
Submitted contract for verification:
	Response: `OK`
	GUID: `ea54nmczs6e1e4yksxwztce4atevjpx2wvlfis1rj14ev8ng7v`
	URL:
        https://goerli.etherscan.io/address/0xf9eaee9363d4c93bae4b23c761705355f37fffb0
Waiting for verification result...
Contract successfully verified
Compiling 36 files with 0.8.17
Solc 0.8.17 finished in 209.98s
Compiler run successful
Deployer: 0x6CEbXXXXXXXXX
Deployed to: 0xfFF82B3c94710305492E974cA56dAeeC74D0FC36
Transaction hash: 0x765888e625ec0af0ab9a579059e6d6df95e6fe6ae84a7b7e9d8f2665e07eb4b4
Starting contract verification...
Waiting for etherscan to detect contract deployment...

Submitting verification for [contracts/GovernanceBuilder.sol:GovernanceBuilder] "0xfFF82B3c94710305492E974cA56dAeeC74D0FC36".

Submitting verification for [contracts/GovernanceBuilder.sol:GovernanceBuilder] "0xfFF82B3c94710305492E974cA56dAeeC74D0FC36".

Submitting verification for [contracts/GovernanceBuilder.sol:GovernanceBuilder] "0xfFF82B3c94710305492E974cA56dAeeC74D0FC36".
Submitted contract for verification:
	Response: `OK`
	GUID: `z9fldndqqqcwj368kmcp9wya9iqq5afeg5nyhzttm995yg4nxv`
	URL:
        https://goerli.etherscan.io/address/0xfff82b3c94710305492e974ca56daeec74d0fc36
Waiting for verification result...
Contract successfully verified
```

### Model

![Collective Governance](docs/images/CollectiveGovernance.png)

### Design Aims

    * Introduce a smart contract that enables on chain proposal of measures, along with conclusive determination of the community support for the measure and potential fulfillment of the aim of a measure.  For example execution of a transfer.
    * Require participation in measure outcome that is restricted to a pre-selected audience of participants
    * Support audiences specified by ownership of a particular token, list of wallets or general population
    * Voting works with the existing ERC-721 standard.  Existing NFTs can form a voting class and participation does not require any contract specialization.  ERC721Enumerable is also supported.
    * Provide safe, fair and verifiable measure outcomes
    * Contract is very literate, information is transparent without prior knowledge
    * Support for execution of a transaction on successful outcome
    * Each community has their own storage/contract address, which are isolated from one another, people can e.g. query the contract address for all the proposals, each communities proposal IDs start at index 1
    * Tokens can’t vote twice, even when transferred to another wallet
    * Allow veto at any time while voting is underway
    * Provide no special authority to the contract owner.   Once in motion a measure may not be tampered with

### Contract Requirements

Collective governance is implemented as a hierarchical set of tiered contracts. An initial function is implemented to create a contract which enables and supports the voting on a particular measure from election setup through conclusion or veto.

The creation stage uses addresses to specify a set of election supervisors who are responsible for establishing the characteristics and lifecycle of the proposed measure. The supervisor will determine the voting class, i.e. particular tokens or other characteristics that specify who is allowed to vote. They will specify the required number of votes to pass the measure and they will then open the voting and allow the measure to succeed or fail.

Negative votes are automatic and do not require gas. Any measure must reach the threshold specified by a supervisor in order to pass. Any supervisor may veto the measure at any time during voting thus nullifying the outcome of the measure. The vetoed measure is effectively void with no result.

Any voter is allowed to change their mind and cast a negative vote while the voting remains open.

### Functional Requirements

1. Contract owner is required to add an election supervisor, but has no other capabilities
2. Arbitrary number of election supervisors are supported
3. Supervisor may add voter by address or add voter class (by token address), but may not vote or undo votes
4. Supervisor may remove voter or voter class for measure prior to start of voting
5. Supervisor may begin and end the voting process
6. Supervisor may set the fixed threshold (number) at which the measure is considered successful
7. No changes are permitted once voting is open, the voter context is final and voter can be assured against manipulation of the rules during the voting process
8. Voter may cast an affirmative vote once voting has been opened. A negative or abstention vote is never required and therefore incurs no gas fees. Vote total is tallied according to Voter class membership, i.e. number of held tokens for ERC-712, or 1 for general public
9. A voter may undo their vote at any time while voting is open
10. No votes or vote changes (undo) are allowed after voting has ended
11. Supervisor may veto the measure prior to the end of voting to ensure the outcome of the measure aligns with the collective interest
12. A vetoed measure has no result and effectively is void
13. A token may only be used one time to verify membership in a voting class. A transferred token has no particular rights if another has already participated in this measure
14. All successful operations are verifiable on chain

### Terminology

Measure - A goal or aim initiated by the community
ElectorDelegate - A contract responsible for community participation in voting on a measure
Voter - A community member, who may be a member of a special subclass (ERC-721 token), participating in the outcome of the measure
Supervisor - A steward for the measure to enable the community to come to a valid conclusion
Owner - the initial contract creator who has no special authority over the outcome of any particular measure

#### Quick Start for Developers

    1. docker build . -t eth-community-v1:1

#### VS Code

    `Reopen in Container`

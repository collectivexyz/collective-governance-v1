```
                         88  88                                   88
                         88  88                            ,d     ""
                         88  88                            88
 ,adPPYba,   ,adPPYba,   88  88   ,adPPYba,   ,adPPYba,  MM88MMM  88  8b       d8   ,adPPYba,
a8"     ""  a8"     "8a  88  88  a8P_____88  a8"     ""    88     88  `8b     d8'  a8P_____88
8b          8b       d8  88  88  8PP"""""""  8b            88     88   `8b   d8'   8PP"""""""
"8a,   ,aa  "8a,   ,a8"  88  88  "8b,   ,aa  "8a,   ,aa    88,    88    `8b,d8'    "8b,   ,aa
 `"Ybbd8"'   `"YbbdP"'   88  88   `"Ybbd8"'   `"Ybbd8"'    "Y888  88      "8"       `"Ybbd8"'
```

# collective-governance-v1

Read the [Docs](https://collectivexyz.github.io/collective-governance-v1/)

## Quick Start

### Contract Deployment Details

| Contract          | Ethereum Address                           | Version |
| ----------------- | ------------------------------------------ | ------- |
| Constant          | 0x7291f9fc02a3B4AfD13d7BCAcc5833653DCf37DD | 0.9.4   |
| VoterClassFactory | 0x836CcF6E97A66AE92AA605DFe6869DDE64b2cC3D | 0.9.4   |
| GovernanceBuilder | 0x8eFCF74380F242c8f220808AA1763539D2DA6F21 | 0.9.4   |
| System            | 0xDb6f31A20996e265FB59406675261F3fcC0bDe6f | 0.9.4   |

### Command line build using docker

    1. docker build . -t collective-governance-v1:1

### VS Code

    Using the Remote module in VSCode simply reopen the project in it's container.

    `Reopen in Container`

## SECURITY

see [SECURITY.md](SECURITY.md)

## Open Smart Contract for Community Governance

Open communities exist to serve everyone and therefore should provide an opportunity to make collective decisions about how resources are used or allocated. Such decisions, referred to as votes or proposals, enhance enthusiasm, participation and enable communities to become benefactors on a broad scale.

This smart contract enables a vote to be proposed, voted upon and successfully fulfilled by executing on chain transactions. The contract also provides safety measures designed to prevent tampering, invalid election design or unexpected system problems from nullifying the possible benefit of a given vote.

### Example deployment

```
Run forge create --contracts contracts/VoterClassFactory.sol --rpc-url ${DEVNET_RPC_URL} --private-key ${ETH_DEV_PRIVATE} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify VoterClassFactory
Compiling 36 files with 0.8.17
Solc 0.8.17 finished in 169.43s
Compiler run successful
Deployer: 0xXXXXXXXXX
Deployed to: 0x8d93427F76250773A943eE500490280149cA6bb7
Transaction hash: 0xd5a76d8ad0ee30a780490aafba98a4294590498628b4477003a03934fb32da38
Starting contract verification...
Waiting for etherscan to detect contract deployment...

Submitting verification for [contracts/VoterClassFactory.sol:VoterClassFactory] "0x8d93427F76250773A943eE500490280149cA6bb7".
Submitted contract for verification:
	Response: `OK`
	GUID: `9lfxw6x2xrezsgft4tjriwg55tujxvlpp9l15tnpvcasqduiwe`
	URL:
        https://goerli.etherscan.io/address/0x8d93427f76250773a943ee500490280149ca6bb7
Waiting for verification result...
Contract successfully verified

Compiling 36 files with 0.8.17
Solc 0.8.17 finished in 169.10s
Compiler run successful
Deployer: 0xXXXXXXXX
Deployed to: 0x622d8f505bdcF4384efFD8EF9883aA37b9e358cf
Transaction hash: 0x11029914dbca1bf905f346014b38f604ebfc8eda8c4a287d70609e42c7b07f63
Starting contract verification...
Waiting for etherscan to detect contract deployment...

Submitting verification for [contracts/GovernanceBuilder.sol:GovernanceBuilder] "0x622d8f505bdcF4384efFD8EF9883aA37b9e358cf".
Submitted contract for verification:
	Response: `OK`
	GUID: `1zxkvrquwhjghdygsvjamxv9cwyw4v5qepnnalhfvwvfnxxnyy`
	URL:
        https://goerli.etherscan.io/address/0x622d8f505bdcf4384effd8ef9883aa37b9e358cf
Waiting for verification result...
Contract successfully verified
```

### Model

![Collective Governance](site/_static/images/CollectiveGovernance.png)

### Design Aims

    * Introduce a smart contract that enables on chain proposal of voting, along with conclusive determination of the community support for the outcome and potential fulfillment of the aims specified.  For example, a successful vote may enable execution of an on chain transfer of tokens or ETH.
    * Allow participation that is restricted to a pre-determined community of participants
    * Support audiences specified by ownership of a particular token, list of wallets or any population
    * Voting works with the existing ERC-721 standard.  Existing NFTs can form a voting class and participation does not require any contract specialization.  ERC721Enumerable is also supported.
    * Provide safe, fair and verifiable outcomes
    * Contract is very literate, information is transparent without prior knowledge
    * Support for execution of a transaction on successful outcome
    * Each community has their own storage and contract address, which are isolated from one another, people can query the contract address for all the proposals, each communities proposal Ids start at index 1
    * Tokens can’t vote twice, even when transferred to another wallet
    * Allow veto at any time while voting is underway
    * Provide no special authority to the contract owner.   Once in motion a measure may not be changed and nobody can predetermine the outcome.

### Contract Requirements

Collective governance is implemented as a hierarchical set of tiered contracts. An initial function is implemented to create a contract which enables and supports the voting on a particular measure from election setup through conclusion or veto.

The creation stage uses addresses to specify a set of election supervisors who are responsible for establishing the characteristics and lifecycle of the proposed vote. The supervisor will determine the voting class, i.e. particular tokens or other characteristics that specify who is allowed to vote. They will specify the required number of votes to pass the measure and they will then open the voting and allow the measure to succeed or fail.

Any measure must reach the quorum threshold specified by a supervisor in order to pass. Any supervisor may veto the measure at any time during voting thus nullifying the outcome of the measure. The vetoed void is effectively void with no result and it is never executable.

Optionally a voter is allowed to change their affirmative vote by undoing it while the voting remains open.

### Functional Requirements

1. Contract owner has no special capabilities
2. Arbitrary number of election supervisors are supported, project supervisors may not be deleted
3. Supervisor may add a voter class by token address or other characteristics, but may not vote or undo votes
4. Supervisor may remove voter or voter class prior to start of voting
5. Supervisor may begin and end the voting process
6. Supervisor may set the fixed quorum requirement at which the measure is considered to achieve quorum. If for votes outnumber the against votes then the vote is successful.
7. No changes are permitted once voting is open, the voter context is final and voter can be assured against manipulation of the rules during the voting process.
8. Voter may cast an affirmative vote once voting has been opened. Vote total is tallied according to voter class membership, i.e. number of held tokens for ERC-712, or 1 for general public
9. A voter may undo their vote at any time while voting is open
10. No votes or vote changes (undo) are allowed after voting has ended
11. Supervisor may veto the measure prior to the end of voting to ensure the outcome of the measure aligns with the community goals
12. A vetoed measure has no result and effectively is void
13. A token may only be used one time to verify membership in a voting class. A transferred token has no particular rights if another has already participated in this vote
14. All successful operations are verifiable on chain and executable by ending the vote

### Terminology

Vote - A goal or aim initiated by the community with the goal of observing the will of the community. Optionally, transactions may be attached to the vote which execute upon success.
CollectiveGovernance - A contract responsible for community participation in voting on a measure
Voter - A community member, who may be a member of a special subclass (ERC-721 token), participating in the outcome of the vote
Supervisor - A steward for the measure to enable the community to come to a valid conclusion
Owner - the initial contract creator who has no special authority over the outcome of any particular vote

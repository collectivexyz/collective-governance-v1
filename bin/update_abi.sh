#!/usr/bin/env bash

set -e

export PATH=${PATH}:~/.cargo/bin

if [ ! -d abi ]
then
    mkdir abi
fi

for contract in governance/VoteStrategy governance/Governance governance/GovernanceBuilder community/CommunityBuilder storage/Storage storage/MetaStorage treasury/Vault treasury/TreasuryBuilder System ProposalBuilder
do
    export BASE_NAME=$(basename ${contract})
    echo "inspect abi: ${contract} to abi/${BASE_NAME}.json"
    forge inspect contracts/${contract}.sol:${BASE_NAME} abi > abi/${BASE_NAME}.json
    bin/sha3sum abi/${BASE_NAME}.json
done

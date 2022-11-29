#!/usr/bin/env bash

set -e

export PATH=${PATH}:~/.cargo/bin

if [ ! -d abi ]
then
    mkdir abi
fi

for contract in VoteStrategy Storage Governance GovernanceBuilder VoterClassFactory MetaStorage System
do
    echo "inspect abi: ${contract} to abi/${contract}.json"
    forge inspect contracts/${contract}.sol:${contract} abi > abi/${contract}.json
    bin/sha3sum abi/${contract}.json
done
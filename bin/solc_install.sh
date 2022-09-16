#!/usr/bin/env /bin/bash

set -e

SOLC_VERSION=0.8.17
REQUIRED_SOLC_SHA3=5e21b6b69808fa62e6c50bcdd855288189e21b1fb7bd0293ec3280be129bfa63

SOLC_SHA3=$(/ethereum/sha3sum /ethereum/solc)
echo Found solc with ${SOLC_SHA3}
if [ ${SOLC_SHA3} == ${REQUIRED_SOLC_SHA3} ]
then
    echo confirmed solc ${SOLC_VERSION}
    cp -f /ethereum/solc /usr/local/bin/solc
    chmod 755 /usr/local/bin/solc
else
    echo Solc not confirmed
    exit 1
fi

#!/usr/bin/env bash

set -e

BUILD=site/_build
if [ ! -d ${BUILD} ]
then
  mkdir -p ${BUILD}
fi

if [ ! -x $(which solc) ]
then
  echo solc not found
else
  echo using $(which solc)
fi

DOCFILE=${BUILD}/solcdoc.log
GENERATED_DOCFILE=${BUILD}/solcdoc.json

echo generate natspec output ${DOCFILE} 
SRCS="contracts/**/*.sol contracts/*.sol"
REMAPPINGS=$(cat remappings.txt | xargs echo)
solc --devdoc --userdoc --base-path . ${REMAPPINGS} ${SRCS} > ${DOCFILE}
echo generate doc json ${GENERATED_DOCFILE}
bin/parse_solcdoc.py ${DOCFILE} ${GENERATED_DOCFILE}

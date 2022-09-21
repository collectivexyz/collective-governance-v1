#!/usr/bin/env bash

set -e

BUILD=site/build
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
solc --devdoc --userdoc --include-path node_modules/ --base-path . contracts/* > ${DOCFILE}
echo generate doc json ${GENERATED_DOCFILE}
bin/parse_solcdoc.py ${DOCFILE} ${GENERATED_DOCFILE}
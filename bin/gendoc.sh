#!/usr/bin/env bash

set -e

FILE=site/_build/solcdoc.log
GENERATED_FILE=site/_build/solcdoc.json
echo generate natspec output ${FILE}
solc --devdoc --userdoc --include-path node_modules/ --base-path . contracts/* > ${FILE}
echo generate doc json ${GENERATED_FILE}
bin/parse_solcdoc.py ${FILE} ${GENERATED_FILE}
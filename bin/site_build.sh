#!/usr/bin/env bash

set -e

cd site

VERSION=$(git rev-parse HEAD | cut -c 1-10)
PROJECT=eth-community-v1/$(basename ${PWD})

docker build . -t ${PROJECT}:${VERSION} && \
	docker run -v ${PWD}/../docs:/html -p 8000:8000 --rm -i -t ${PROJECT}:${VERSION}

#!/usr/bin/env bash

set -e

cd site

VERSION=$(git rev-parse HEAD | cut -c 1-10)
PROJECT=collective-governance-v1-doc/$(basename ${PWD})

docker build --progress plain . -t ${PROJECT}:${VERSION} && \
	docker run -v ${PWD}/../docs:/html -p 8000:8000 --rm -i -t ${PROJECT}:${VERSION}

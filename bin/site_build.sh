#!/usr/bin/env bash

set -e

VERSION=$(git rev-parse HEAD | cut -c 1-10)
PROJECT=collective-governance-v1-doc/$(basename ${PWD})

docker build --progress plain -f site/Dockerfile . -t ${PROJECT}:${VERSION} && \
    docker run -v ${PWD}/docs:/html --rm -i -t ${PROJECT}:${VERSION}

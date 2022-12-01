#!/usr/bin/env bash

VERSION=$(git rev-parse HEAD | cut -c 1-10)

PROJECT=collectivexyz/$(basename ${PWD})

docker build . -t ${PROJECT}:${VERSION} && \
    docker rmi ${PROJECT}:${VERSION}

#!/usr/bin/env bash

VERSION=$(git rev-parse HEAD | cut -c 1-10)

PROJECT=collective/collective_governance

docker build . -t ${PROJECT}:${VERSION}
#! /usr/bin/env bash

PWD_DIR=$(pwd)
GIT_DIR="${PWD_DIR}/test/bats-core"
BATS_DIR="${PWD_DIR}/test/bats"

# Cleanup bats-core no matter what
trap 'rc=$?; rm -rf $GIT_DIR; trap - EXIT; exit $rc' EXIT

rm -rf $GIT_DIR
git clone https://github.com/bats-core/bats-core.git $GIT_DIR --quiet
cd $GIT_DIR
./install.sh $BATS_DIR
export PATH="${PATH}:$BATS_DIR/bin/"

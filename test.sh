#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

TEST_DOES_NOT_BUILD=${TEST_DOES_NOT_BUILD:-}

if ! hadolint ./*Dockerfile*; then
  >&2 printf "Failed linting on Dockerfile\n"
  exit 1
fi

if ! shellcheck ./*.sh*; then
  >&2 printf "Failed shellchecking\n"
  exit 1
fi

if [ ! "$TEST_DOES_NOT_BUILD" ]; then
  ./build.sh --progress plain downloader
  ./build.sh --progress plain builder
  ./build.sh --progress plain builder-node
  ./build.sh --progress plain runtime
fi

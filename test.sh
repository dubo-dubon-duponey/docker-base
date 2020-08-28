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
  # XXX fix this please
  mkdir -p context/builder/cache
  ./build.sh --progress plain downloader
  ./build.sh --progress plain overlay
  ./build.sh --progress plain --set builder.platform=linux/arm64 builder
  ./build.sh --progress plain --set builder.platform=linux/arm64 builder-node
  ./build.sh --progress plain --set builder.platform=linux/arm64 runtime
fi

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

  if ! ./hack/cue-bake downloader --inject progress=plain --inject platforms=linux/arm64; then
    >&2 printf "Failed building downloader\n"
    exit 1
  fi

  if ! ./hack/cue-bake overlay --inject progress=plain --inject platforms=linux/arm64; then
    >&2 printf "Failed building overlay\n"
    exit 1
  fi

  if ! ./hack/cue-bake builder --inject progress=plain --inject platforms=linux/arm64; then
    >&2 printf "Failed building builder\n"
    exit 1
  fi

  if ! ./hack/cue-bake builder_node --inject progress=plain --inject platforms=linux/arm64; then
    >&2 printf "Failed building builder_node\n"
    exit 1
  fi

  if ! ./hack/cue-bake runtime --inject progress=plain --inject platforms=linux/arm64; then
    >&2 printf "Failed building runtime\n"
    exit 1
  fi
fi

#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# shellcheck source=/dev/null
root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/../"
readonly root

# XXX right now this is not testing much but the runtime image building
if ! "$root/hack/build.sh" \
    --inject registry="docker.io/dubodubonduponey" \
    --inject progress=plain \
	  --inject date=2024-03-01 \
	  --inject suite=bookworm \
    --inject platforms=linux/amd64,linux/arm64 \
  	overlay "$@"; then
  printf >&2 "Failed building overlay\n"
  exit 1
fi

if ! "$root/hack/build.sh" \
    --inject registry="docker.io/dubodubonduponey" \
    --inject progress=plain \
	  --inject date=2024-03-01 \
	  --inject suite=bookworm \
    --inject platforms=linux/amd64,linux/arm64 \
  	runtime "$@"; then
  printf >&2 "Failed building runtime image\n"
  exit 1
fi

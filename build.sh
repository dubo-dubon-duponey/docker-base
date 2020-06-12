#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

# Which Debian version to use
export DEBIAN_DATE=${DEBIAN_DATE:-2020-06-01}
# Image name to push
export IMAGE_NAME="${IMAGE_NAME:-base}"

# Override composed base image
export BUILDER_BASE="${BUILDER_BASE:-docker.io/dubodubonduponey/debian:$DEBIAN_DATE}"
export RUNTIME_BASE="${RUNTIME_BASE:-docker.io/dubodubonduponey/debian:$DEBIAN_DATE}"

refresh() {
  local cwd="$1"
  local base="$2"

  PROXY="${PROXY:-}"
  APTPROXY="${APTPROXY:-}"
  docker buildx build -f "$cwd"/Dockerfile.downloader \
    --build-arg "BUILDER_BASE=$base" \
    --tag local/dubodubonduponey/downloader \
    --build-arg="APTPROXY=$APTPROXY" \
    --output type=docker \
    "$cwd/context/downloader"

  docker rm -f downloader 2>/dev/null || true
  export DOCKER_CONTENT_TRUST=0
  docker run --rm --name downloader --env="http_proxy=$PROXY" --env="https_proxy=$PROXY" --volume "$cwd/context/builder/cache:/cache" local/dubodubonduponey/downloader
  export DOCKER_CONTENT_TRUST=1
}

[ "${NO_REFRESH:-}" ] || refresh "$root" "$BUILDER_BASE"

## Runtime

# Title and description
export TITLE="Dubo Runtime"
export DESCRIPTION="Base runtime image for all DBDBDP images"
# Image tag to push
export IMAGE_TAG="runtime-${DEBIAN_DATE}"
export DOCKERFILE=Dockerfile.runtime
export CONTEXT=context/runtime

# shellcheck source=/dev/null
bash "$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/helpers.sh"

## Builder

# Title and description
export TITLE="Dubo Builder"
export DESCRIPTION="Base builder image for all DBDBDP images"
# Image tag to push
export IMAGE_TAG="builder-${DEBIAN_DATE}"
export DOCKERFILE=Dockerfile.builder
export CONTEXT=context/builder

# shellcheck source=/dev/null
bash "$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/helpers.sh" --target builder

# Title and description
export TITLE="Dubo Builder with Node"
export DESCRIPTION="Base builder image for all DBDBDP images (with node)"
# Image tag to push
export IMAGE_TAG="builder-node-${DEBIAN_DATE}"
export DOCKERFILE=Dockerfile.builder
# Node does not support armv6
export PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"
export CONTEXT=context/builder

# shellcheck source=/dev/null
bash "$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/helpers.sh" --target builder-node

#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

export DEBIAN_DATE=${DEBIAN_DATE:-2020-01-01}
export BASE="docker.io/dubodubonduponey/debian:$DEBIAN_DATE"
export PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6"

export REGISTRY="${REGISTRY:-registry-1.docker.io}"
export VENDOR="${VENDOR:-dubodubonduponey}"
export IMAGE_NAME="${IMAGE_NAME:-base}"

export IMAGE_NAME_RUNTIME="${IMAGE_NAME_RUNTIME:-${REGISTRY}/${VENDOR}/${IMAGE_NAME}:runtime-${DEBIAN_DATE}}"
export IMAGE_NAME_BUILDER="${IMAGE_NAME_BUILDER:-${REGISTRY}/${VENDOR}/${IMAGE_NAME}:builder-${DEBIAN_DATE}}"

export DOCKER_CONTENT_TRUST=1
export DOCKER_CLI_EXPERIMENTAL=enabled

docker::version_check(){
  dv="$(docker version | grep "^ Version")"
  dv="${dv#*:}"
  dv="${dv##* }"
  if [ "${dv%%.*}" -lt "19" ]; then
    >&2 printf "Docker is too old and doesn't support buildx. Failing!\n"
    return 1
  fi
}

build::setup(){
  docker buildx create --node "dubo-dubon-duponey-building-0" --name "dubo-dubon-duponey-building"
  docker buildx use "dubo-dubon-duponey-building"
}

build::runtime(){
  docker buildx build -f Dockerfile.runtime --pull --target runtime \
    --build-arg BASE="$BASE" \
    --tag "$IMAGE_NAME_RUNTIME" \
    --platform "$PLATFORMS" --push "$@" .
}

build::builder(){
# --cache-to type=local,dest="$HOME"/tmp/dubo-cache
  docker buildx build -f Dockerfile.builder --pull --target builder \
    --build-arg BASE="$BASE" \
    --tag "$IMAGE_NAME_BUILDER" \
    --platform "$PLATFORMS" --push "$@" .
}

docker::version_check
build::setup

build::builder "$@"
build::runtime "$@"

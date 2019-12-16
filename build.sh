#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

export DEBIAN_DATE=${DEBIAN_DATE:-2019-12-01}
export BASE="dubodubonduponey/debian:$DEBIAN_DATE"
export PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6"

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
    --tag docker.io/dubodubonduponey/base:runtime-${DEBIAN_DATE} \
    --platform "$PLATFORMS" --push "$@" .
}

build::builder(){
# --cache-to type=local,dest="$HOME"/tmp/dubo-cache
  docker buildx build -f Dockerfile.builder --pull --target builder \
    --build-arg BASE="$BASE" \
    --tag docker.io/dubodubonduponey/base:builder-${DEBIAN_DATE} \
    --platform "$PLATFORMS" --push "$@" .
}

docker::version_check
build::setup

build::builder "$@"
build::runtime "$@"

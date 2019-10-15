#!/usr/bin/env bash

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
# --cache-to type=local,dest="$HOME"/tmp/dubo-cache
  docker buildx build -f Dockerfile.runtime --pull --target runtime \
    -t docker.io/dubodubonduponey/base:runtime \
    --platform "linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6" --push "$@" .
}

build::builder(){
# --cache-to type=local,dest="$HOME"/tmp/dubo-cache
  docker buildx build -f Dockerfile.builder --pull --target builder \
    -t docker.io/dubodubonduponey/base:builder \
    --platform "linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6" --push "$@" .
}

docker::version_check || exit 1
build::setup || exit 1

build::builder "$@" || exit 1
build::runtime "$@"

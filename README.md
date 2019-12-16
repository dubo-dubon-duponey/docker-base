# Base images

Provides base images (builder and runtime) used by all our images.

Currently, on linux amd64, arm64, arm/v7, arm/v6:

 * `docker.io/dubodubonduponey/base:runtime`
    * based on our debootstrapped version of Debian Buster (at `$DEBIAN_DATE`)
    * labels
    * ca-certificates copied over
    * ONBUILD instructions to copy over runtime folders
    * user creation
    * entrypoint definition
 * `docker.io/dubodubonduponey/base:builder`
    * based on our debootstrapped version of Debian Buster (at `$DEBIAN_DATE`)
    * golang, python, and essential dev & build tools
    * nodejs + yarnpkg (except on arm/v6)
    * ONBUILD version verification

## How to build

```bash
./build.sh
```

## Advanced build parameters

```bash
# Control which debian version to use (see available tags at docker.io/dubodubonduponey/debian)
DEBIAN_DATE=2019-12-01
# If you want to use an entirely different Debian base
BASE="docker.io/dubodubonduponey/debian:$DEBIAN_DATE"
# If you want to control which platforms are being built
PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6"

# Control images naming
REGISTRY="registry-1.docker.io"
VENDOR="dubodubonduponey"
IMAGE_NAME="base"

# Still unhappy? Hack these
IMAGE_NAME_RUNTIME="${REGISTRY}/${VENDOR}/${IMAGE_NAME}:runtime-${DEBIAN_DATE}"
IMAGE_NAME_BUILDER="${REGISTRY}/${VENDOR}/${IMAGE_NAME}:builder-${DEBIAN_DATE}"
```

## Caveats

This: https://github.com/moby/qemu/issues/9

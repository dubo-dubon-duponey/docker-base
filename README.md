# Base images

Provides base images (builder and runtime) used by all our images.

Currently, on linux amd64, arm64, arm/v7, s390x, ppc64le:

 * `dubodubonduponey/base:runtime` and `dubodubonduponey/base:runtime-$DEBOOTSTRAP_SUITE-$DEBOOTSTRAP_DATE`
    * based on our debootstrapped version of Debian Buster (currently `DEBOOTSTRAP_DATE=2020-08-15`, for suite `buster`)
    * labels
    * ca-certificates copied over
    * ONBUILD instructions to copy over runtime folders
    * user creation
    * entrypoint definition
 * `dubodubonduponey/base:builder` and `dubodubonduponey/base:builder-$DEBOOTSTRAP_SUITE-$DEBOOTSTRAP_DATE`
    * based on our debootstrapped version of Debian Buster (currently `DEBOOTSTRAP_DATE=2020-08-15`, for suite `buster`)
    * golang, python, and essential dev & build tools
 * `dubodubonduponey/base:builder-node` and `dubodubonduponey/base:builder-node-$DEBOOTSTRAP_SUITE-$DEBOOTSTRAP_DATE`
    * +nodejs +yarnpkg

## How to build

```bash

# Download golang, node, yarn (once)
./build.sh downloader

# Build and push the builders and runtime images
VENDOR=you ./build.sh --push
```

## Advanced build parameters

```bash
# Optional if you change apt behavior
APT_OPTIONS="space separated arguments for apt -o"
APT_SOURCES="replacement sources.list"
APT_GPG_KEYRING="base64 encoded content of a trusted.gpg file"

# Control which debian version to use (see available tags at docker.io/dubodubonduponey/debian)
DEBOOTSTRAP_DATE=2020-08-15
# Debian version you want (only buster exist currently)
DEBOOTSTRAP_SUITE=buster

# destination for your final Debian image - defaults to Docker Hub if left unspecified
REGISTRY="docker.io"
VENDOR="dubodubonduponey"

# If you want to use an entirely different Debian base - caution: you may have to adjust packages versions inside the dockerfile as well as this might break!
BUILDER_BASE="registry/foo/bar:tag"
RUNTIME_BASE="..."

# Additionally, any additional argument passed to build.sh is fed to docker buildx bake.
# Specifically you may want to use any of
#  --no-cache           Do not use cache when building the image
#  --print              Print the options without building
#  --progress string    Set type of progress output (auto, plain, tty). Use plain to show container output (default "auto")
#  --set stringArray    Override target value (eg: targetpattern.key=value)

# Specifically, you may want to override platform if you want to restrict building to a subset of supported platforms.
```

## Notes

The downloader image will FAIL building if it detects a new patch release for golang, node or yarn.

In that case, it will display updated versions (and sha) to copy over in the dockerfile.

Alternatively, you can pass `FAIL_WHEN_OUTDATED=` as a build arg to build with outdated versions.

## Caveats

This: https://github.com/moby/qemu/issues/9

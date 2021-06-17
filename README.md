# Base images

Provides base images (builder and runtime) used by all our images.

Currently, on linux amd64, 386, arm64, arm/v7, arm/v6, s390x, ppc64le:

* `dubodubonduponey/base:runtime-latest` and `dubodubonduponey/base:runtime-$SUITE-$DATE`
  * based on our debootstrapped version of Debian Bullseye (currently `DATE=2021-06-01`)
  * labels
  * ca-certificates copied over
  * ONBUILD instructions to copy over runtime folders
  * user creation
  * entrypoint definition
* `dubodubonduponey/base:builder-latest` and `dubodubonduponey/base:builder-$SUITE-$DATE`
  * based on our debootstrapped version of Debian Bullseye (currently `DATE=2021-06-01`)
  * golang, python, and essential dev & build tools
* `dubodubonduponey/base:node-latest` and `dubodubonduponey/base:node-$SUITE-$DATE`
  * +nodejs +yarnpkg

## TL;DR

```bash

# Download golang, node, yarn (once)
./hack/build.sh downloader

# Build the overlay
./hack/build.sh overlay

# Build and push the builders and runtime images
./hack/build.sh builder --inject tags=registry.com/name/image:tag
./hack/build.sh node --inject tags=registry.com/name/image:tag
./hack/build.sh runtime --inject tags=registry.com/name/image:tag
```

## Configuration

You can control additional aspects of the build passing arguments:

```
# Control base image, target platforms, and cache
./hack/build.sh runtime \
  --inject from_image="ghcr.io/dubo-dubon-duponey/debian:bullseye-2021-06-01" \
  --inject platforms="linux/arm/v6" \
  --inject cache_base=type=registry,ref=somewhere.com/cache/foo
```

## Notes

The downloader image will FAIL building if it detects a new patch release for golang, node or yarn.

In that case, it will display updated versions (and sha) to copy over in the dockerfile.

Alternatively, you can pass `FAIL_WHEN_OUTDATED=` as a build arg to build with outdated versions (see the `recipe` file).

## Caveats

Qemu as usual is a problem - see specifically https://github.com/moby/qemu/issues/9

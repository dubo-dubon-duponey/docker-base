# Base images

Provides base images (builder, auditor, golang, node, runtime) used by all our images.

Currently, on linux amd64, 386, arm64, arm/v7, arm/v6, s390x, ppc64le:

* `index.docker.io/dubodubonduponey/base:runtime-latest` and `index.docker.io/dubodubonduponey/base:runtime-$SUITE-$DATE`
  * based on our debootstrapped version of Debian Bullseye (currently `DATE=2021-11-01`)
  * labels
  * ca-certificates copied over
  * ONBUILD instructions to copy over runtime folders
  * user creation
  * entrypoint definition
* `index.docker.io/dubodubonduponey/base:builder-latest` and `index.docker.io/dubodubonduponey/base:builder-$SUITE-$DATE`
  * based on our debootstrapped version of Debian Bullseye (currently `DATE=2021-11-01`)
  * golang, python, and essential cross compilation dev & build tools
* `index.docker.io/dubodubonduponey/base:node-latest` and `index.docker.io/dubodubonduponey/base:node-$SUITE-$DATE`
  * +nodejs +yarnpkg
* `index.docker.io/dubodubonduponey/base:golang-latest` and `index.docker.io/dubodubonduponey/base:golang-$SUITE-$DATE`
  * just golang and git
* `index.docker.io/dubodubonduponey/base:auditor-latest` and `index.docker.io/dubodubonduponey/base:auditor-$SUITE-$DATE`
  * test and security hardening tools

## TL;DR

Point to your buildkit host or use the helper to start one

```bash
export BUILDKIT_HOST=$(./hack/helpers/start-buildkit.sh 2>/dev/null)
```

```bash
# Build the overlay
./hack/build.sh overlay

# Download golang, node, yarn (once)
./hack/build.sh downloader

# Build and push the builders and runtime images
./hack/build.sh builder
./hack/build.sh node
./hack/build.sh golang
./hack/build.sh runtime
./hack/build.sh auditor
```

Note that the above will by default try to push to `index.docker.io/dubodubonduponey/base`.
Edit `recipe.cue`, or better, use an `env.cue` file (see [advanced](ADVANCED.md) for that) to control
the push destination.

## Configuration

You can control additional aspects of the build passing arguments:

```bash
# Control base image, target platforms, and cache
./hack/build.sh runtime \
  --inject platforms="linux/arm/v6" \
  --inject registry="private.registry/yourname"
```

## Notes

The downloader image will FAIL building if it detects a new patch release for golang, node or yarn.

In that case, it will display updated versions (and sha) to copy over in the dockerfile.

Alternatively, you can pass `FAIL_WHEN_OUTDATED=` as a build arg to build with outdated versions (see the `recipe` file).

## Caveats

Qemu as usual is a problem - see specifically https://github.com/moby/qemu/issues/9

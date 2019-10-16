# Base images

This provides base images (builder and runtime) for all our images.

Currently, on linux amd64, arm64, arm/v7, arm/v6:

 * `docker.io/dubodubonduponey/base:builder`
    * debian:buster-slim
    * labels
    * ca-certificates copied over
    * ONBUILD instructions to copy over runtime folders
    * user creation
    * entrypoint definition
 * `docker.io/dubodubonduponey/base:runtime`
    * debian:buster-slim
    * golang, python, and essential dev & build tools
    * nodejs + yarnpkg (except on arm/v6)

# Caveats

This is pretty bad: https://github.com/moby/qemu/issues/9

Time to consider moving to alpine :s.

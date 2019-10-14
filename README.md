# Base images

This provides base images (builder and runtime) for all our images.
Currently:

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

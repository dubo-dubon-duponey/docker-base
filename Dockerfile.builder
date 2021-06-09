ARG           FROM_IMAGE=docker.io/dubodubonduponey/debian@sha256:04f7bfea58c6c4af846af6d34fc25d6420c50d7ae8e0ca26e6bf89779437feb0
#######################
# "Builder"
# This image is meant to provide basic files copied over directly into the base target image.
# Right now:
# - updated ca root
# XXX IIRC we have to do this gymnastic on the NATIVE platform because qemu will fail silently installing ca-certs
#######################
# hadolint ignore=DL3006
FROM          $FROM_IMAGE                                                                                               AS overlay-builder

ARG           BUILD_CREATED="1976-04-14T17:00:00-07:00"

RUN           --mount=type=secret,mode=0444,id=CA \
              --mount=type=secret,id=CERTIFICATE \
              --mount=type=secret,id=KEY \
              --mount=type=secret,id=PASSPHRASE \
              --mount=type=secret,mode=0444,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_OPTIONS,dst=/etc/apt/apt.conf.d/dbdbdp.conf \
              set -eu; \
              ln -s /run/secrets/CA /etc/ssl/certs/ca-certificates.crt; \
              apt-get update -qq; \
              apt-get install -qq --no-install-recommends \
                ca-certificates=20210119

RUN           update-ca-certificates

RUN           set -eu; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /etc/ssl/certs -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +; \
              find /usr/share/ca-certificates -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +

RUN           set -eu; \
              tar -cf /overlay.tar /etc/ssl/certs /usr/share/ca-certificates

########################################################################################################################
# Export of the above
########################################################################################################################
FROM          scratch                                                                                                   AS overlay
# hadolint ignore=DL3010
COPY          --from=overlay-builder /overlay.tar /overlay.tar

#######################
# Actual "builder" image
#######################
# hadolint ignore=DL3006
FROM          $FROM_IMAGE                                                                                               AS builder

ARG           TARGETPLATFORM
ARG           BUILDPLATFORM

ENV           GOLANG_VERSION=1.15.13
ENV           GOPATH=/build/golang/source
ENV           GOROOT=/build/golang/go
ENV           PATH=$GOPATH/bin:$GOROOT/bin:$PATH

WORKDIR       $GOPATH
ADD           ./cache/$TARGETPLATFORM/golang-$GOLANG_VERSION.tar.gz /build/golang

###########################################################
# C++ and generic
# Generic development stuff
# Python
###########################################################
# For CGO
RUN           --mount=type=secret,mode=0444,id=CA \
              --mount=type=secret,id=CERTIFICATE \
              --mount=type=secret,id=KEY \
              --mount=type=secret,id=PASSPHRASE \
              --mount=type=secret,mode=0444,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_OPTIONS,dst=/etc/apt/apt.conf.d/dbdbdp.conf \
              set -eu; \
              ln -s /run/secrets/CA /etc/ssl/certs/ca-certificates.crt; \
              apt-get update -qq; \
              apt-get install -qq --no-install-recommends \
                g++=4:10.2.1-1 \
                gcc=4:10.2.1-1 \
                libc6-dev=2.31-12 \
                make=4.3-4.1 \
                dpkg-dev=1.20.9 \
                autoconf=2.69-14 \
                automake=1:1.16.3-2 \
                libtool=2.4.6-15 \
		            pkg-config=0.29.2-1 \
                python2=2.7.18-2 \
                python3=3.9.2-3 \
                virtualenv=20.4.0+ds-1 \
                jq=1.6-2.1 \
                curl=7.74.0-1.2 \
                git=1:2.30.2-1; \
              apt-get -qq autoremove      && \
              apt-get -qq clean           && \
              rm -rf /var/lib/apt/lists/* && \
              rm -rf /tmp/*               && \
              rm -rf /var/tmp/*

RUN           set -eu; \
              git config --global advice.detachedHead false

# The usefulness/security angle of this should be assessed.
ADD           ./cache/overlay/overlay.tar /

ARG           BUILD_CREATED="1976-04-14T17:00:00-07:00"
ARG           BUILD_URL="https://github.com/dubo-dubon-duponey/docker-base"
ARG           BUILD_DOCUMENTATION="https://github.com/dubo-dubon-duponey/docker-base"
ARG           BUILD_SOURCE="https://github.com/dubo-dubon-duponey/docker-base"
ARG           BUILD_VERSION="unknown"
ARG           BUILD_REVISION="unknown"
ARG           BUILD_VENDOR="dubodubonduponey"
ARG           BUILD_LICENSES="MIT"
ARG           BUILD_REF_NAME="latest"
ARG           BUILD_TITLE="A DBDBDP image"
ARG           BUILD_DESCRIPTION="So image. Much DBDBDP. Such description."

LABEL         org.opencontainers.image.created="$BUILD_CREATED"
LABEL         org.opencontainers.image.authors="Dubo Dubon Duponey <dubo-dubon-duponey@farcloser.world>"
LABEL         org.opencontainers.image.url="$BUILD_URL"
LABEL         org.opencontainers.image.documentation="$BUILD_DOCUMENTATION"
LABEL         org.opencontainers.image.source="$BUILD_SOURCE"
LABEL         org.opencontainers.image.version="$BUILD_VERSION"
LABEL         org.opencontainers.image.revision="$BUILD_REVISION"
LABEL         org.opencontainers.image.vendor="$BUILD_VENDOR"
LABEL         org.opencontainers.image.licenses="$BUILD_LICENSES"
LABEL         org.opencontainers.image.ref.name="$BUILD_REF_NAME"
LABEL         org.opencontainers.image.title="$BUILD_TITLE"
LABEL         org.opencontainers.image.description="$BUILD_DESCRIPTION"

# Base
ONBUILD ARG   TARGETPLATFORM
ONBUILD ARG   TARGETOS
ONBUILD ARG   TARGETARCH
ONBUILD ARG   TARGETVARIANT

ONBUILD ARG   BUILDPLATFORM
ONBUILD ARG   BUILDOS
ONBUILD ARG   BUILDARCH
ONBUILD ARG   BUILDVARIANT

ONBUILD ARG   DEBIAN_FRONTEND="noninteractive"
ONBUILD ARG   TERM="xterm"
ONBUILD ARG   LANG="C.UTF-8"
ONBUILD ARG   LC_ALL="C.UTF-8"
ONBUILD ARG   TZ="America/Los_Angeles"

ONBUILD ARG   BUILD_CREATED="1976-04-14T17:00:00-07:00"
ONBUILD ARG   BUILD_VERSION="unknown"
ONBUILD ARG   BUILD_REVISION="unknown"

# CGO disabled by default for cross-compilation to work
ONBUILD ARG   CGO_ENABLED=0

# Modules are on by default
ONBUILD ARG   GO111MODULE=on
ONBUILD ARG   GOPROXY="https://proxy.golang.org"

#######################
# Actual "builder" image (with node)
#######################
# hadolint ignore=DL3006
FROM          builder                                                                                                   AS builder-node

ARG           BUILD_TITLE="A DBDBDP image"
ARG           BUILD_DESCRIPTION="So image. Much DBDBDP. Such description."
LABEL         org.opencontainers.image.title="$BUILD_TITLE"
LABEL         org.opencontainers.image.description="$BUILD_DESCRIPTION"

# Base
ONBUILD ARG   TARGETPLATFORM
ONBUILD ARG   BUILDPLATFORM

ONBUILD ARG   DEBIAN_FRONTEND="noninteractive"
ONBUILD ARG   TERM="xterm"
ONBUILD ARG   LANG="C.UTF-8"
ONBUILD ARG   LC_ALL="C.UTF-8"
ONBUILD ARG   TZ="America/Los_Angeles"

ONBUILD ARG   BUILD_CREATED="1976-04-14T17:00:00-07:00"
ONBUILD ARG   BUILD_VERSION="unknown"
ONBUILD ARG   BUILD_REVISION="unknown"

# CGO disabled by default for cross-compilation to work
ONBUILD ARG   CGO_ENABLED=0
# Modules are on by default
ONBUILD ARG   GO111MODULE=on
ONBUILD ARG   GOPROXY="https://proxy.golang.org"

ENV           NODE_VERSION=14.17.0
ENV           YARN_VERSION=1.22.5

ADD           ./cache/$TARGETPLATFORM/node-$NODE_VERSION.tar.gz /opt
ADD           ./cache/$TARGETPLATFORM/yarn-$YARN_VERSION.tar.gz /opt

###########################################################
# Node and Yarn install
###########################################################
RUN           set -eu; \
              ln -s /opt/node-*/bin/* /usr/local/bin/; \
              ln -s /opt/yarn-*/bin/yarn /usr/local/bin/; \
              ln -s /opt/yarn-*/bin/yarnpkg /usr/local/bin/; \
              ln -s /usr/local/bin/node /usr/local/bin/nodejs

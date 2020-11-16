ARG           BUILDER_BASE=docker.io/dubodubonduponey/debian@sha256:04f7bfea58c6c4af846af6d34fc25d6420c50d7ae8e0ca26e6bf89779437feb0

#######################
# "Builder"
# This image is meant to provide basic files copied over directly into the base target image.
# Right now:
# - updated ca root
#######################
# hadolint ignore=DL3006
FROM          $BUILDER_BASE                                                                                             AS overlay-builder

ARG           BUILD_CREATED="1976-04-14T17:00:00-07:00"

ARG           DEBIAN_FRONTEND="noninteractive"
ARG           TERM="xterm"
ARG           LANG="C.UTF-8"
ARG           LC_ALL="C.UTF-8"
ARG           TZ="America/Los_Angeles"

RUN           apt-get update -qq
RUN           apt-get install -qq --no-install-recommends \
                ca-certificates=20200601~deb10u1
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
FROM          $BUILDER_BASE                                                                                             AS builder

ARG           TARGETPLATFORM
ARG           BUILDPLATFORM

ARG           DEBIAN_FRONTEND="noninteractive"
ENV           TERM="xterm"
ENV           LANG="C.UTF-8"
ENV           LC_ALL="C.UTF-8"
ENV           TZ="America/Los_Angeles"

ENV           GOLANG_VERSION 1.15.5
ENV           GOPATH=/build/golang/source
ENV           GOROOT=/build/golang/go
ENV           PATH=$GOPATH/bin:$GOROOT/bin:$PATH

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
ONBUILD ARG   BUILDPLATFORM
ONBUILD ARG   DEBIAN_FRONTEND="noninteractive"

ONBUILD ARG   BUILD_CREATED="1976-04-14T17:00:00-07:00"
ONBUILD ARG   BUILD_VERSION="unknown"
ONBUILD ARG   BUILD_REVISION="unknown"

# CGO disabled by default for cross-compilation to work
ONBUILD ARG   CGO_ENABLED=0

# Modules are on by default
ONBUILD ARG   GO111MODULE=on
ONBUILD ARG   GOPROXY="https://proxy.golang.org"

# Apt behavior
ONBUILD ARG   APT_OPTIONS
ONBUILD ARG   APT_SOURCES
ONBUILD ARG   APT_GPG_KEYRING
ONBUILD ARG   APT_NETRC
ONBUILD ARG   APT_TLS_CA

ONBUILD ARG   http_proxy
ONBUILD ARG   https_proxy

###########################################################
# C++ and generic
# Generic development stuff
# Python
###########################################################
# For CGO
RUN           apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                g++=4:8.3.0-1 \
                gcc=4:8.3.0-1 \
                libc6-dev=2.28-10 \
                make=4.2.1-1.2 \
                dpkg-dev=1.19.7 \
                autoconf=2.69-11 \
                automake=1:1.16.1-4 \
                libtool=2.4.6-9 \
		            pkg-config=0.29-6 \
                python=2.7.16-1 \
                python3=3.7.3-1 \
                virtualenv=15.1.0+ds-2 \
                jq=1.5+dfsg-2+b1 \
                curl=7.64.0-4+deb10u1 \
                git=1:2.20.1-2+deb10u3 && \
              apt-get -qq autoremove      && \
              apt-get -qq clean           && \
              rm -rf /var/lib/apt/lists/* && \
              rm -rf /tmp/*               && \
              rm -rf /var/tmp/*

# The usefulness/security angle of this should be assessed.
ADD           ./cache/overlay/overlay.tar /

ADD           ./cache/$TARGETPLATFORM/golang-$GOLANG_VERSION.tar.gz /build/golang

WORKDIR       $GOPATH

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

ONBUILD ARG   BUILD_CREATED="1976-04-14T17:00:00-07:00"
ONBUILD ARG   BUILD_VERSION="unknown"
ONBUILD ARG   BUILD_REVISION="unknown"

# CGO disabled by default for cross-compilation to work
ONBUILD ARG   CGO_ENABLED=0
# Modules are on by default
ONBUILD ARG   GO111MODULE=on
ONBUILD ARG   GOPROXY="https://proxy.golang.org"

# Apt behavior
ONBUILD ARG   APT_OPTIONS
ONBUILD ARG   APT_SOURCES
ONBUILD ARG   APT_GPG_KEYRING
ONBUILD ARG   APT_NETRC
ONBUILD ARG   APT_TLS_CA

ONBUILD ARG   http_proxy
ONBUILD ARG   https_proxy

ENV           NODE_VERSION 10.23.0
ENV           YARN_VERSION 1.22.5

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

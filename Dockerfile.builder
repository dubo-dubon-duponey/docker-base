ARG           BUILDER_BASE=dubodubonduponey/debian@sha256:cb25298b653310dd8b7e52b743053415452708912fe0e8d3d0d4ccf6c4003746
#######################
# "Builder"
# This image is meant to provide basic files copied over directly into the base target image.
# Right now:
# - updated ca root
#######################
# hadolint ignore=DL3006
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder-builder

ARG           TARGETPLATFORM

ARG           DEBIAN_FRONTEND="noninteractive"
ARG           TERM="xterm"
ARG           LANG="C.UTF-8"
ARG           LC_ALL="C.UTF-8"
ARG           TZ="America/Los_Angeles"

RUN           apt-get update -qq
RUN           apt-get install -qq --no-install-recommends \
                ca-certificates=20190110
RUN           update-ca-certificates

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

# Base
ONBUILD ARG   TARGETPLATFORM
ONBUILD ARG   BUILDPLATFORM
ONBUILD ARG   DEBIAN_FRONTEND="noninteractive"

# CGO disabled by default for cross-compilation to work
ONBUILD ARG   CGO_ENABLED=0
# Modules are on by default
ONBUILD ARG   GO111MODULE=on
ONBUILD ARG   GOPROXY="https://proxy.golang.org"

# Since the same statement from Debian is already enshrined, make sure we override it for descendants
ONBUILD ARG   APTPROXY=""
ONBUILD RUN   printf 'Acquire::HTTP::proxy "%s";\n' "$APTPROXY" > /etc/apt/apt.conf.d/99-dbdbdp-proxy.conf

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
                build-essential=12.6 \
                autoconf=2.69-11 \
                automake=1:1.16.1-4 \
                libtool=2.4.6-9 \
		            pkg-config=0.29-6 \
                python=2.7.16-1 \
                python3=3.7.3-1 \
                virtualenv=15.1.0+ds-2 \
                jq=1.5+dfsg-2+b1 \
                git=1:2.20.1-2+deb10u3 && \
              apt-get -qq autoremove      && \
              apt-get -qq clean           && \
              rm -rf /var/lib/apt/lists/* && \
              rm -rf /tmp/*               && \
              rm -rf /var/tmp/*

# The usefulness/security angle of this should be assessed.
COPY          --from=builder-builder /etc/ssl/certs /etc/ssl/certs
COPY          --from=builder-builder /usr/share/ca-certificates /usr/share/ca-certificates

ENV           GOLANG_VERSION 1.13.12

# Bring in the cache for that platform - XXX this may become messy if people do not clean their cache
ADD           ./cache/$TARGETPLATFORM/golang-$GOLANG_VERSION.tar.gz /build/golang

###########################################################
# Golang install
###########################################################
ENV           GOPATH=/build/golang/source
ENV           GOROOT=/build/golang/go
ENV           PATH=$GOPATH/bin:$GOROOT/bin:$PATH

WORKDIR       $GOPATH

#######################
# Actual "builder" image (with node)
#######################
# hadolint ignore=DL3006
FROM          builder                                                                                                   AS builder-node

# Base
ONBUILD ARG   TARGETPLATFORM
ONBUILD ARG   BUILDPLATFORM
ONBUILD ARG   DEBIAN_FRONTEND="noninteractive"

# CGO disabled by default for cross-compilation to work
ONBUILD ARG   CGO_ENABLED=0
# Modules are on by default
ONBUILD ARG   GO111MODULE=on
ONBUILD ARG   GOPROXY="https://proxy.golang.org"

# Since the same statement from Debian is already enshrined, make sure we override it for descendants
ONBUILD ARG   APTPROXY=""
ONBUILD RUN   printf 'Acquire::HTTP::proxy "%s";\n' "$APTPROXY" > /etc/apt/apt.conf.d/99-dbdbdp-proxy.conf

ENV           NODE_VERSION 10.21.0
ENV           YARN_VERSION 1.22.2

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

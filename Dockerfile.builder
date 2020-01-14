ARG           BASE=dubodubonduponey/debian@sha256:96a576f7ea067283150a43a78c10ebfc1eff502ac5a4010dabafefa4a178ee1e
# hadolint ignore=DL3006
FROM          $BASE                                                                                                     AS builder

ARG           TARGETPLATFORM

ENV           DEBIAN_FRONTEND="noninteractive"
ENV           TERM="xterm"
ENV           LANG="C.UTF-8"
ENV           LC_ALL="C.UTF-8"
ENV           TZ="America/Los_Angeles"

# hadolint ignore=DL3009
RUN           apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                curl=7.64.0-4 \
                gnupg=2.2.12-1+deb10u1 \
                dirmngr=2.2.12-1+deb10u1 \
                ca-certificates=20190110

RUN           update-ca-certificates

###########################################################
# Golang
###########################################################
ENV           GOLANG_VERSION 1.13.6
ENV           GOLANG_AMD64_SHA512 92ec5741c9330c86bc598c1db97bb3eb9a784a13988befae5f4bbb647a14db27389c48df4dbfa277f54aa598a0c20f7165f3bf996d108f445f993e2579e0b01d
ENV           GOLANG_ARM64_SHA512 99ff498d7de3b8b339e28eb66017e2237f58b914b9bcb552cab5ee1fda1edad18f54fb38084b026167471efafe0185b2a5e75bfc54563541cea7b074edccf006
ENV           GOLANG_ARMV6L_SHA512 bba388dc24cb7c13e5e00699488e25dc5d81fe08a84720e9a5e8f6da6845cd3030717a057ac483785787d5c192d7baab76c09b5804323e3d8eaa512dbd716639

###########################################################
# Node
###########################################################
ENV           NODE_VERSION 10.18.1
ENV           YARN_VERSION 1.21.1

ARG           FAIL_WHEN_OUTDATED=true

# This massive nonsense serves only a gentle purpose: check if we should be running a more recent version of golang, and annoy everybody consuming our image if we should.
COPY          ./scripts /scripts

RUN           /scripts/version-check.sh

###########################################################
# Golang build
###########################################################
ENV           GOPATH=/build/golang/source
ENV           GOROOT=/build/golang/go
ENV           PATH=$GOPATH/bin:$GOROOT/bin:$PATH
# CGO disabled by default for cross-compilation to work
ENV           GCO_ENABLED=0

WORKDIR       /build/golang

# hadolint ignore=DL4006
RUN           set -eu; \
              arch="$(dpkg --print-architecture)"; \
              case "${arch##*-}" in \
                amd64) arch='linux-amd64'; checksum="$GOLANG_AMD64_SHA512" ;; \
                arm64) arch='linux-arm64'; checksum="$GOLANG_ARM64_SHA512" ;; \
            		armel) arch='linux-armv6l'; checksum="$GOLANG_ARMV6L_SHA512" ;; \
            		armhf) arch='linux-armv6l'; checksum="$GOLANG_ARMV6L_SHA512" ;; \
            		*) echo "unsupported architecture ${arch##*-}"; exit 1;; \
              esac; \
              # If using QEMU on a glibc system, cacerts are broken. Ignoring tls errors here for now - safeguarded by checksum verification
              curl -k -fsSL -o go.tar.gz "https://dl.google.com/go/go${GOLANG_VERSION}.${arch}.tar.gz"; \
              printf "%s *go.tar.gz" "$checksum" | sha512sum -c -; \
              tar -xzf go.tar.gz; \
              rm go.tar.gz; \
              mkdir -p "$GOPATH/src" "$GOPATH/bin"

WORKDIR       $GOPATH

###########################################################
# Node build
###########################################################
# hadolint ignore=DL4006
RUN           set -eu; \
              arch="$(dpkg --print-architecture)"; \
              if [ "${arch##*-}" != "armel" ]; then \
                case "${arch##*-}" in \
                  amd64) arch='x64';; \
                  arm64) arch='arm64';; \
                  armhf) arch='armv7l';; \
                  *) echo "unsupported architecture ${arch##*-}"; exit 1;; \
                esac; \
                for key in \
                  94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
                  FD3A5288F042B6850C66B31F09FE44734EB7990E \
                  71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
                  DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
                  C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
                  B9AE9905FFD7803F25714661B63B535A4C206CA9 \
                  77984A986EBC2AA786BC0F66B01FBB92821C587A \
                  8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
                  4ED778F539E3634C779C87C6D7062848A1AB005C \
                  A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
                  B9E2F5981AA6E0CD28160D9FF13993A75599653C \
                ; do \
                  gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
                  gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
                  gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
                done; \
                curl -k -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$arch.tar.gz"; \
                curl -k -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc"; \
                gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc; \
                grep " node-v$NODE_VERSION-linux-$arch.tar.gz\$" SHASUMS256.txt | sha256sum -c -; \
                tar -xzf "node-v$NODE_VERSION-linux-$arch.tar.gz" -C /usr/local --strip-components=1 --no-same-owner; \
                rm "node-v$NODE_VERSION-linux-$arch.tar.gz" SHASUMS256.txt.asc SHASUMS256.txt; \
                ln -s /usr/local/bin/node /usr/local/bin/nodejs; \
              fi

RUN           set -eu; \
              arch="$(dpkg --print-architecture)"; \
              if [ "${arch##*-}" != "armel" ]; then \
                gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "6A010C5166006599AA17F08146C2130DFD2497F5" || \
                gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "6A010C5166006599AA17F08146C2130DFD2497F5" || \
                gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "6A010C5166006599AA17F08146C2130DFD2497F5"; \
                curl -k -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz"; \
                curl -k -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc"; \
                gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz; \
                mkdir -p /opt; \
                tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/; \
                ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn; \
                ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg; \
                rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz; \
              fi

###########################################################
# C++ and generic
###########################################################
# For CGO
RUN           apt-get install -qq --no-install-recommends \
                g++=4:8.3.0-1 \
                gcc=4:8.3.0-1 \
                libc6-dev=2.28-10 \
                make=4.2.1-1.2 \
                build-essential=12.6 \
                autoconf=2.69-11 \
                automake=1:1.16.1-4 \
                libtool=2.4.6-9 \
		            pkg-config=0.29-6

# Generic development stuff
RUN           apt-get install -qq --no-install-recommends \
                jq=1.5+dfsg-2+b1 \
                git=1:2.20.1-2

###########################################################
# Python
###########################################################
RUN           apt-get install -qq --no-install-recommends \
                python=2.7.16-1 \
                virtualenv=15.1.0+ds-2

ONBUILD ARG   TARGETPLATFORM
ONBUILD ARG   BUILDPLATFORM
ONBUILD ARG   FAIL_WHEN_OUTDATED=true

ONBUILD RUN   /scripts/version-check.sh

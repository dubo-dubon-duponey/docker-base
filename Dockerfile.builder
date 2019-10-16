FROM          debian:buster-slim                                                                          AS builder

ONBUILD ARG   TARGETPLATFORM
ONBUILD ARG   BUILDPLATFORM
ONBUILD ARG   NO_FAIL_OUTDATED

RUN           apt-get update                                                                              > /dev/null \
              && apt-get install -y --no-install-recommends \
                curl=7.64.0-4 \
                xz-utils=5.2.4-1 \
                gnupg=2.2.12-1+deb10u1 \
                dirmngr=2.2.12-1+deb10u1 \
                ca-certificates=20190110                                                                  > /dev/null

RUN           update-ca-certificates

ENV           DEBIAN_FRONTEND="noninteractive"
ENV           TERM="xterm"
ENV           LANG="C.UTF-8"
ENV           LC_ALL="C.UTF-8"

###########################################################
# Golang
###########################################################
ENV           GOLANG_VERSION=1.13.1
ENV           GOLANG_AMD64_SHA256=94f874037b82ea5353f4061e543681a0e79657f787437974214629af8407d124
ENV           GOLANG_ARM64_SHA256=8af8787b7c2a3c0eb3f20f872577fcb6c36098bf725c59c4923921443084c807
ENV           GOLANG_ARMV6_SHA256=7c75d4002321ea4a066dfe13f6dd5168076e9a231317c5afd55e78b86f478e37

WORKDIR       /build/golang

RUN           set -eu; \
              arch="$(dpkg --print-architecture)"; \
              case "${arch##*-}" in \
                amd64) arch='linux-amd64'; checksum="$GOLANG_AMD64_SHA256" ;; \
                arm64) arch='linux-arm64'; checksum="$GOLANG_ARM64_SHA256" ;; \
            		armel) arch='linux-armv6l'; checksum="$GOLANG_ARMV6_SHA256" ;; \
            		armhf) arch='linux-armv6l'; checksum="$GOLANG_ARMV6_SHA256" ;; \
            		*) echo "unsupported architecture ${arch##*-}"; exit 1;; \
              esac; \
              # XXX for some reason, debian certs are broken on armv67 - ignoring tls errors here for now - safeguarded by checksum verification
              curl -k -fsSL -o go.tgz "https://dl.google.com/go/go${GOLANG_VERSION}.${arch}.tar.gz"; \
              printf "%s *go.tgz" "$checksum" | sha256sum -c -; \
              tar -xzf go.tgz; \
              rm go.tgz

ENV           GOPATH=/build/golang/source
ENV           PATH=$GOPATH/bin:/build/golang/go/bin:$PATH
# CGO disabled by default for cross-compilation to work
ENV           GCO_ENABLED=0

RUN           mkdir -p "$GOPATH/src" "$GOPATH/bin"
WORKDIR       $GOPATH

###########################################################
# Node
###########################################################
ENV           NODE_VERSION 10.16.3
ENV           YARN_VERSION 1.17.3

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
                curl -k -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$arch.tar.xz"; \
                curl -k -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc"; \
                gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc; \
                grep " node-v$NODE_VERSION-linux-$arch.tar.xz\$" SHASUMS256.txt | sha256sum -c -; \
                tar -xJf "node-v$NODE_VERSION-linux-$arch.tar.xz" -C /usr/local --strip-components=1 --no-same-owner; \
                rm "node-v$NODE_VERSION-linux-$arch.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt; \
                ln -s /usr/local/bin/node /usr/local/bin/nodejs; \
              fi

RUN           set -eu; \
              arch="$(dpkg --print-architecture)"; \
              if [ "${arch##*-}" != "armel" ]; then \
                for key in \
                  6A010C5166006599AA17F08146C2130DFD2497F5 \
                ; do \
                  gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
                  gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
                  gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key"; \
                done; \
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
RUN           apt-get install -y --no-install-recommends \
                g++=4:8.3.0-1 \
                gcc=4:8.3.0-1 \
                libc6-dev=2.28-10 \
                make=4.2.1-1.2 \
		            pkg-config=0.29-6                                                                         > /dev/null

# Generic development stuff
RUN           apt-get install -y --no-install-recommends \
                git=1:2.20.1-2                                                                            > /dev/null

###########################################################
# Python
###########################################################
RUN           apt-get install -y --no-install-recommends \
                python=2.7.16-1 \
                virtualenv=15.1.0+ds-2                                                                    > /dev/null

# This massive nonsense serves only a gentle purpose: check if we should be running a more recent version of golang, and annoy everybody consuming our image if we should.
ONBUILD RUN   set -eu; \
              major=${GOLANG_VERSION%%.*}; \
              rest=${GOLANG_VERSION#*.}; \
              minor=${rest%%.*}; \
              if [ "$rest" != "$minor" ]; then patch=${rest#*.}; fi; \
              candidate_patch=${patch:-0}; \
              next_patch=$((patch + 1)); \
              while [ "$(curl -k -I -o /dev/null -v https://dl.google.com/go/go$major.$minor.$next_patch.linux-amd64.tar.gz 2>&1 | grep -P "HTTP/[0-9] [0-9]{3}" | sed -E 's/.* ([0-9]{3}).*/\1/')" != "404" ]; do \
                candidate_patch=$next_patch; \
                next_patch=$((next_patch + 1)); \
              done; \
              if [ "$candidate_patch" != "${patch:-0}" ]; then \
                >&2 printf "WARNING: golang has a new patch version - the base image should DEFINITELY be updated to:\n"; \
                >&2 printf "ENV           GOLANG_VERSION %s.%s.%s\n" "$major" "$minor" "$candidate_patch"; \
                checksum=$(curl -k -fsSL "https://dl.google.com/go/go$major.$minor.$candidate_patch.linux-amd64.tar.gz" | sha256sum); \
                >&2 printf "ENV           GOLANG_AMD64_SHA256 %s\n" "${checksum%*-}"; \
                checksum=$(curl -k -fsSL "https://dl.google.com/go/go$major.$minor.$candidate_patch.linux-arm64.tar.gz" | sha256sum); \
                >&2 printf "ENV           GOLANG_ARM64_SHA256 %s\n" "${checksum%*-}"; \
                if [ ! "$NO_FAIL_OUTDATED" ]; then \
                  exit 1; \
                fi \
              fi; \
              candidate_minor=$minor; \
              next_minor=$((minor + 1)); \
              while [ "$(curl -k -I -o /dev/null -v https://dl.google.com/go/go$major.$next_minor.linux-amd64.tar.gz 2>&1 | grep -P "HTTP/[0-9] [0-9]{3}" | sed -E 's/.* ([0-9]{3}).*/\1/')" != "404" ]; do \
                candidate_minor=$next_minor; \
                next_minor=$((next_minor + 1)); \
              done; \
              if [ "$candidate_minor" != "$minor" ]; then \
                if [ "$candidate_minor" != "$((minor + 1))" ]; then \
                  >&2 printf "WARNING: the version of golang you are using is badly outdated. The base image NEED to be updated to %s.%s ASAP." "$major" "$candidate_minor"; \
                  if [ ! "$NO_FAIL_OUTDATED" ]; then \
                    exit 1; \
                  fi \
                else \
                  >&2 printf "WARNING: there is a new golang version %s.%s - the base image should be updated to it soon." "$major" "$candidate_minor"; \
                fi \
              fi


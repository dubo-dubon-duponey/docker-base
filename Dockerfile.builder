FROM          debian:buster-slim                                                                          AS builder

ONBUILD ARG   TARGETPLATFORM
ONBUILD ARG   BUILDPLATFORM
ONBUILD ARG   NO_FAIL_OUTDATED

ENV           GOLANG_VERSION=1.13.1
ENV           GOLANG_AMD64_SHA256=94f874037b82ea5353f4061e543681a0e79657f787437974214629af8407d124
ENV           GOLANG_ARM64_SHA256=8af8787b7c2a3c0eb3f20f872577fcb6c36098bf725c59c4923921443084c807

ENV           DEBIAN_FRONTEND="noninteractive"
ENV           TERM="xterm"
ENV           LANG="C.UTF-8"
ENV           LC_ALL="C.UTF-8"

# Install golang
RUN           apt-get update                                                                              > /dev/null \
              && apt-get install -y --no-install-recommends \
                curl=7.64.0-4 \
                ca-certificates=20190110                                                                  > /dev/null \
              && apt-get -y autoremove                                                                    > /dev/null \
              && apt-get -y clean            \
              && rm -rf /var/lib/apt/lists/* \
              && rm -rf /tmp/*               \
              && rm -rf /var/tmp/*

RUN           update-ca-certificates

WORKDIR       /build/golang

RUN           set -eu; \
              arch="$(dpkg --print-architecture)"; \
              case "${arch##*-}" in \
                amd64) arch='linux-amd64'; checksum="$GOLANG_AMD64_SHA256" ;; \
                arm64) arch='linux-arm64'; checksum="$GOLANG_ARM64_SHA256" ;; \
              esac; \
              curl -fsSL -o go.tgz "https://dl.google.com/go/go${GOLANG_VERSION}.${arch}.tar.gz"; \
              printf "%s *go.tgz" "$checksum" | sha256sum -c -; \
              tar -xzf go.tgz; \
              rm go.tgz

ENV           GOPATH=/build/golang/source
ENV           PATH=$GOPATH/bin:/build/golang/go/bin:$PATH
# CGO disabled by default for cross-compilation to work
ENV           GCO_ENABLED=0

RUN           mkdir -p "$GOPATH/src" "$GOPATH/bin"
WORKDIR       $GOPATH

# Additional packages useful for building

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

# Python
RUN           apt-get install -y --no-install-recommends \
                virtualenv=15.1.0+ds-2                                                                    > /dev/null

# This massive nonsense serves only a gentle purpose: check if we should be running a more recent version of golang, and annoy everybody consuming our image if we should.
ONBUILD RUN   set -eu; \
              major=${GOLANG_VERSION%%.*}; \
              rest=${GOLANG_VERSION#*.}; \
              minor=${rest%%.*}; \
              if [ "$rest" != "$minor" ]; then patch=${rest#*.}; fi; \
              candidate_patch=${patch:-0}; \
              next_patch=$((patch + 1)); \
              while [ "$(curl -I -o /dev/null -v https://dl.google.com/go/go$major.$minor.$next_patch.linux-amd64.tar.gz 2>&1 | grep -P "HTTP/[0-9] [0-9]{3}" | sed -E 's/.* ([0-9]{3}).*/\1/')" != "404" ]; do \
                candidate_patch=$next_patch; \
                next_patch=$((next_patch + 1)); \
              done; \
              if [ "$candidate_patch" != "${patch:-0}" ]; then \
                >&2 printf "WARNING: golang has a new patch version - the base image should DEFINITELY be updated to:\n"; \
                >&2 printf "ENV           GOLANG_VERSION %s.%s.%s\n" "$major" "$minor" "$candidate_patch"; \
                checksum=$(curl -fsSL "https://dl.google.com/go/go$major.$minor.$candidate_patch.linux-amd64.tar.gz" | sha256sum); \
                >&2 printf "ENV           GOLANG_AMD64_SHA256 %s\n" "${checksum%*-}"; \
                checksum=$(curl -fsSL "https://dl.google.com/go/go$major.$minor.$candidate_patch.linux-arm64.tar.gz" | sha256sum); \
                >&2 printf "ENV           GOLANG_ARM64_SHA256 %s\n" "${checksum%*-}"; \
                if [ ! "$NO_FAIL_OUTDATED" ]; then \
                  exit 1; \
                fi \
              fi; \
              candidate_minor=$minor; \
              next_minor=$((minor + 1)); \
              while [ "$(curl -I -o /dev/null -v https://dl.google.com/go/go$major.$next_minor.linux-amd64.tar.gz 2>&1 | grep -P "HTTP/[0-9] [0-9]{3}" | sed -E 's/.* ([0-9]{3}).*/\1/')" != "404" ]; do \
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


ARG           FROM_IMAGE=ghcr.io/dubo-dubon-duponey/debian:bullseye-2021-07-01@sha256:d162e34b3a53944cec3ba525b07ef6152ff391ed916de4ee4eb04debb019c8b0
#######################
# "Builder"
# This image is meant to provide basic files copied over directly into the base target image.
# Right now:
# - ca-certificates: originally due to a bug in qemu / libc installing ca-certificates would fail 32bits systems, which prompted this deviation
# The problem may (?) be fixed now in qemu6, although ca-certificates do install libssl and openssl, which is undesirable.
# By installing out of band, on the native arch, and copying the files, we get to install trusted roots without the hassle of shipping openssl
#######################
FROM          $FROM_IMAGE                                                                                               AS overlay-builder

ARG           BUILD_CREATED="1976-04-14T17:00:00-07:00"

RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq; \
              apt-get install -qq --no-install-recommends \
                ca-certificates=20210119

RUN           update-ca-certificates

RUN           epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /etc/ssl/certs -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +; \
              find /usr/share/ca-certificates -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +

RUN           tar -cf /overlay.tar /etc/ssl/certs /usr/share/ca-certificates

########################################################################################################################
# Export of the above
########################################################################################################################
FROM          scratch                                                                                                   AS overlay
# hadolint ignore=DL3010
COPY          --from=overlay-builder /overlay.tar /overlay.tar

#######################
# Actual "builder" image
#######################
FROM          $FROM_IMAGE                                                                                               AS builder

# This is used to get the appropriate binaries from previous stages export
ARG           TARGETPLATFORM

# Add go to path, and point GOPATH and GOROOT to the right locations
ENV           GOPATH=/build/golang-current/source
ENV           GOROOT=/build/golang-current/go
ENV           PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# Install:
# - cross-toolchains for all supported architectures
# - basic dev stuff (git, jq, curl, devscripts)
# - additional often used build tools (automake, autoconf, libtool and pkg-config)
# Might not work on same platform as the cross build target...
# XXX WARNING
# Something weird is happening here: for some reason, installing everything in one call breaks apt which complains about "broken packages being held"
# Also, transient qemu core dumps (even with qemu 6), so... here be effing dragons  
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              packages=(); \
              for architecture in armel armhf arm64 ppc64el i386 s390x amd64; do \
                dpkg --add-architecture "$architecture"; \
                packages+=(crossbuild-essential-"$architecture"=12.9); \
              done; \
              apt-get update -qq; \
              apt-get install -qq --no-install-recommends \
                build-essential=12.9 \
                autoconf=2.69-14 \
                automake=1:1.16.3-2 \
                libtool=2.4.6-15 \
		            pkg-config=0.29.2-1 \
                jq=1.6-2.1 \
                curl=7.74.0-1.2 \
                ca-certificates=20210119 \
                git=1:2.30.2-1; \
              apt-get install -qq --no-install-recommends \
                "${packages[@]}"; \
              apt-get install -qq devscripts=2.21.2; \
              apt-get -qq autoremove; \
              apt-get -qq clean; \
              rm -rf /var/lib/apt/lists/*; \
              rm -rf /tmp/*; \
              rm -rf /var/tmp/*

# Prevent git from complaining about detached heads all the time
RUN           git config --global advice.detachedHead false

# This used to be necessary because of a bug in qemu/libc
# Now replaced with proper ca-certificates install (which does pull in openssl <- not a problem for build, but keeping the lightweight deviation for runtime)
# ADD           ./cache/overlay.tar /

ENV           GOLANG_VERSION=1.16.5

ADD           ./cache/$TARGETPLATFORM/golang-$GOLANG_VERSION.tar.gz /build/golang-current

# Add metadata
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

# Image building from here can use this for buildtime (that is usually set at the time of the last commit to their repo)
ONBUILD ARG   BUILD_CREATED="1976-04-14T17:00:00-07:00"

# Helper for our secrets
# Pointing curl home out, allowing for /run/secrets/.curlrc to be seen automatically
ENV           CURL_HOME=/run/secrets
# go tools use this to find the netrc file
ENV           NETRC=/run/secrets/NETRC
# go tools honor this to find our CA
ENV           SSL_CERT_FILE=/run/secrets/CA

# Go stuff
# Images inheriting this will get a normal GOPROXY through the ARG (expected to go mod download), further inherits will get OFF (expected to ONLY build with no network)
ENV           GOPROXY=off
ONBUILD ARG   GOPROXY="https://proxy.golang.org,direct"
# Modules are on by default unless specifically disabled by projects
ENV           GO111MODULE=on

# Location
WORKDIR       /source

#######################
# Actual "builder" image (with node)
#######################
FROM          $FROM_IMAGE                                                                                               AS builder-node

# This is used to get the appropriate binaries from previous stages export
ARG           TARGETPLATFORM

# Add node
ENV           NODE_VERSION=14.17.2
ENV           YARN_VERSION=1.22.5

ADD           ./cache/$TARGETPLATFORM/node-$NODE_VERSION.tar.gz /opt
ADD           ./cache/$TARGETPLATFORM/yarn-$YARN_VERSION.tar.gz /opt

# Add metadata
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

# Image building from here can use this for buildtime (that is usually set at the time of the last commit to their repo)
ONBUILD ARG   BUILD_CREATED="1976-04-14T17:00:00-07:00"

# Location
WORKDIR       /source

# Node and Yarn post-install normalize
RUN           ln -s /opt/node-*/bin/* /usr/local/bin/; \
              ln -s /opt/yarn-*/bin/yarn /usr/local/bin/; \
              ln -s /opt/yarn-*/bin/yarnpkg /usr/local/bin/; \
              ln -s /usr/local/bin/node /usr/local/bin/nodejs

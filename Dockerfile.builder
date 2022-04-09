ARG           FROM_REGISTRY=ghcr.io/dubo-dubon-duponey
ARG           FROM_IMAGE_RUNTIME=debian:bullseye-2022-04-01@sha256:eb89aeccb5828d0bec68d3b67f56f47c6d919ceaacff2096b81b48d49a914350

#######################
# Actual "builder" image
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME                                                                        AS builder

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

# hadolint ignore=DL3008
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              for architecture in armel armhf arm64 ppc64el i386 s390x amd64; do \
                dpkg --add-architecture "$architecture"; \
              done; \
              apt-get update -qq; \
              apt-get install -qq --no-install-recommends \
                build-essential=12.9 \
                autoconf=2.69-14 \
                automake=1:1.16.3-2 \
                libtool=2.4.6-15 \
		            pkg-config=0.29.2-1 \
                jq=1.6-2.1 \
                curl=7.74.0-1.3+deb11u1 \
                ca-certificates=20210119 \
                git=1:2.30.2-1; \
              for architecture in armel armhf arm64 ppc64el i386 s390x amd64; do \
                apt-get install -qq --no-install-recommends \
                  crossbuild-essential-"$architecture"=12.9 \
                  musl-dev:"$architecture"=1.2.2-1 \
                  musl:"$architecture"=1.2.2-1 \
                  libc6:"$architecture"=2.31-13+deb11u3 \
                  libc6-dev:"$architecture"=2.31-13+deb11u3; \
              done; \
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

ENV           GOLANG_VERSION=1.16.15

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
# XXX this is problematic - rust also uses this - if the file does not exist, at least rust will tits-up
ENV           SSL_CERT_FILE=/run/secrets/CA

# Go stuff
# Images inheriting this will get a normal GOPROXY through the ARG (expected to go mod download), further inherits will get OFF (expected to ONLY build with no network)
ENV           GOPROXY=off
ONBUILD ARG   GOPROXY="https://proxy.golang.org,direct"
# Modules are on by default unless specifically disabled by projects
ENV           GO111MODULE=on
# Make sure it's off by default
ENV           CGO_ENABLED=0

# C/C++/CGO stuff
# https://news.ycombinator.com/item?id=18874113
# https://developers.redhat.com/blog/2018/03/21/compiler-and-linker-flags-gcc
# https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html
ENV           WARNING_OPTIONS="-Werror=implicit-function-declaration -Werror=format-security -Wall"
# https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html#Optimize-Options
ENV           OPTIMIZATION_OPTIONS="-O3"
# https://gcc.gnu.org/onlinedocs/gcc/Debugging-Options.html#Debugging-Options
ENV           DEBUGGING_OPTIONS="-grecord-gcc-switches -g"
# https://gcc.gnu.org/onlinedocs/gcc/Preprocessor-Options.html#Preprocessor-Options
ENV           PREPROCESSOR_OPTIONS="-Wp,-D_GLIBCXX_ASSERTION -D_FORTIFY_SOURCE=2"
# https://gcc.gnu.org/onlinedocs/gcc/Instrumentation-Options.html
ENV           COMPILER_OPTIONS="-pipe -fexceptions -fstack-protector-strong -fstack-clash-protection"
# AMD64 only
# -mcet -fcf-protection
# https://gcc.gnu.org/onlinedocs/gcc/Link-Options.html#Link-Options
ENV           LDFLAGS="-Wl,-z,relro -Wl,-z,now -Wl,-z,defs -Wl,-z,noexecstack"
ENV           CFLAGS="$WARNING_OPTIONS $OPTIMIZATION_OPTIONS $DEBUGGING_OPTIONS $PREPROCESSOR_OPTIONS $COMPILER_OPTIONS -s"
# Werror=implicit-function-declaration is not allowed for CXX
ENV           CXXFLAGS="-Werror=format-security -Wall $OPTIMIZATION_OPTIONS $DEBUGGING_OPTIONS $PREPROCESSOR_OPTIONS $COMPILER_OPTIONS -s"

# Location
WORKDIR       /source

#######################
# Actual "builder" image (with node)
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME                                                                        AS builder-node

# This is used to get the appropriate binaries from previous stages export
ARG           TARGETPLATFORM

# Add node
ENV           NODE_VERSION=14.19.1
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



#######################
# Slim go image, solely for goproxy or as a lightweight go building without CGO
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME                                                                        AS builder-golang

# This is used to get the appropriate binaries from previous stages export
ARG           TARGETPLATFORM

# Add go to path, and point GOPATH and GOROOT to the right locations
ENV           GOPATH=/build/golang-current/source
ENV           GOROOT=/build/golang-current/go
ENV           PATH=$GOPATH/bin:$GOROOT/bin:$PATH

ENV           GOLANG_VERSION=1.16.15

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

# hadolint ignore=DL3008
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq; \
              apt-get install -qq --no-install-recommends \
                curl=7.74.0-1.3+deb11u1 \
                ca-certificates=20210119 \
                git=1:2.30.2-1; \
              apt-get -qq autoremove; \
              apt-get -qq clean; \
              rm -rf /var/lib/apt/lists/*; \
              rm -rf /tmp/*; \
              rm -rf /var/tmp/*

# Image building from here can use this for buildtime (that is usually set at the time of the last commit to their repo)
ONBUILD ARG   BUILD_CREATED="1976-04-14T17:00:00-07:00"

# Location
WORKDIR       /source

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
# Make sure it's off by default
ENV           CGO_ENABLED=0

# Make sure git stops whining about detached heads
RUN           git config --global advice.detachedHead false

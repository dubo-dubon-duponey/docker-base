#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

# shellcheck source=/dev/null
. "$root/helpers.sh"
# shellcheck source=/dev/null
. "$root/version_check.sh"

init::golang(){
  logger::debug "Golang: nothing to init"
}

platforms::golang() {
  printf "linux/amd64 linux/arm64 linux/arm/v7 linux/arm/v6"
}

checksum::golang() {
  local arch="$1"
  local version="$2"
  local binary="$3"

  cache::checksum::verify "$arch" "$binary" "$(env::checksum::read "golang" "$arch")"
}

url::golang() {
  local arch="$1"
  local version="$2"

  # If we were passed major minor patch instead or just a raw version...
  if [ "${3:-}" ]; then
    version="$2.$3"
    if [ "$4" ] && [ "$4" != "0" ]; then
      version="$version.$4"
    fi
  fi

  case "$arch" in
  "linux/amd64")
    arch="linux-amd64"
    ;;
  "linux/arm64")
    arch="linux-arm64"
    ;;
  "linux/arm/v7")
    arch="linux-armv6l"
    ;;
  "linux/arm/v6")
    arch="linux-armv6l"
    ;;
  esac
  printf "https://dl.google.com/go/go%s.%s.tar.gz" "$version" "$arch"
}

init::node() {
  # First key is for Yarn, the rest for Node
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
    B9E2F5981AA6E0CD28160D9FF13993A75599653C; do
    logger::debug "Importing Node key $key"
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" 2>/dev/null ||
      gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" 2>/dev/null  ||
      gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" 2>/dev/null
    gpg --list-keys --fingerprint --with-colon "$key" | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | head -1 | gpg --import-ownertrust 2>/dev/null
  done
}

platforms::node() {
  printf "linux/amd64 linux/arm64 linux/arm/v7"
}

url::node() {
  local arch="$1"
  local version="$2"

  # Major minor patch form of the arg
  if [ "${3:-}" ]; then
    version="$2.$3.$4"
  fi
  case "$arch" in
  "linux/amd64")
    arch="linux-x64"
    ;;
  "linux/arm64")
    arch="linux-arm64"
    ;;
  "linux/arm/v7")
    arch="linux-armv7l"
    ;;
  esac
  printf "https://nodejs.org/dist/v%s/node-v%s-%s.tar.gz" "$version" "$version" "$arch"
}

checksum::node() {
  local arch="$1"
  local version="$2"
  local binary="$3"
  local checksum
  local narch

  cache::download "$arch" "node-$version.txt.asc" "https://nodejs.org/dist/v$version/SHASUMS256.txt.asc"
  cache::delete "$arch" "node-$version.txt"
  gpg --batch --decrypt --output "$(cache::path "$arch" "node-$version.txt")" "$(cache::path "$arch" "node-$version.txt.asc")"
  logger::debug "Verifying node signature"

  case "$arch" in
  "linux/amd64")
    narch="linux-x64"
    ;;
  "linux/arm64")
    narch="linux-arm64"
    ;;
  "linux/arm/v7")
    narch="linux-armv7l"
    ;;
  esac

  checksum="$(grep " node-v$version-$narch.tar.gz\$" "$(cache::path "$arch" "node-$version.txt")")"

  cache::checksum::verify "$arch" "$binary" "${checksum%% *}" 256
}

init::yarn() {
  # First key is for Yarn, the rest for Node
  local key=6A010C5166006599AA17F08146C2130DFD2497F5
  logger::debug "Importing Yarn key $key"
  gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" 2>/dev/null ||
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" 2>/dev/null ||
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" 2>/dev/null
  gpg --list-keys --fingerprint --with-colon "$key" | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | head -1 | gpg --import-ownertrust 2>/dev/null
}

platforms::yarn() {
  printf "linux/amd64 linux/arm64 linux/arm/v7"
}

url::yarn() {
  local arch="$1"
  local version="$2"

  # Major minor patch form of the arg
  if [ "${3:-}" ]; then
    version="$2.$3.$4"
  fi
  printf "https://yarnpkg.com/downloads/%s/yarn-v%s.tar.gz" "$version" "$version"
}

checksum::yarn() {
  local arch="$1"
  local version="$2"
  local binary="$3"

  cache::download "$arch" "yarn-$version.asc" "https://yarnpkg.com/downloads/$version/yarn-v$version.tar.gz.asc"
  logger::debug "Verifying Yarn signature"
  gpg --batch --verify "$(cache::path "$arch" "yarn-$version.asc")" "$(cache::path "$arch" "$binary")"
}

check::node
check::golang
check::yarn

for product in golang node yarn; do
  init::"$product"

  version="$(env::version::read "$product")"

  for platform in $(platforms::"$product"); do
    binary="$product-$version.tar.gz"
    cache::download "$platform" "$binary" "$(url::"$product" "$platform" "$version")"

    checksum::"$product" "$platform" "$version" "$binary" || {
      logger::error "Checksum FAIL! Deleting artifact ($product $platform $version: $binary)"
      cache::delete "$platform" "$binary"
      exit 1
    }
  done
done

#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

# shellcheck source=/dev/null
. "$root/helpers.sh"
# shellcheck source=/dev/null
. "$root/version_check.sh"

gpgopts=()
if [ "${http_proxy:-}" ]; then
  gpgopts+=(--keyserver-options "http-proxy=$http_proxy")
fi
gpgopts+=(--recv-keys)

init::golang(){
  logger::debug "Golang: nothing to init"
}

platforms::golang() {
  printf "linux/amd64 linux/arm64"
  # linux/arm/v7 linux/arm/v6 linux/386 linux/ppc64le linux/s390x"
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
  "linux/386")
    arch="linux-386"
    ;;
  "linux/ppc64le")
    arch="linux-ppc64le"
    ;;
  "linux/s390x")
    arch="linux-s390x"
    ;;
  esac
  printf "https://dl.google.com/go/go%s.%s.tar.gz" "$version" "$arch"
}

init::node() {
  # Older keys
  # 9554F04D7259F04124DE6B476D5A82AC7E37093B
  # 1C050899334244A8AF75E53792EF661D867B9DFA
  # B9AE9905FFD7803F25714661B63B535A4C206CA9
  # 77984A986EBC2AA786BC0F66B01FBB92821C587A
  # 93C7E9E91B49E432C2F75674B0A78B0A6C481CF6
  # 56730D5401028683275BD23C23EFEFE93C4CFFFE
  # FD3A5288F042B6850C66B31F09FE44734EB7990E
  # 114F43EE0176B71C7BC219DD50A3051F888C628D
  # 7937DFD2AB06298B2293C3187D33FF9D0246406D

  # From https://github.com/nodejs/node#release-keys
  for key in \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    74F12602B6F1C4E913FAA37AD3A89613643B6201 \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C; do
    logger::debug "Importing Node key $key"
    # GPG is (still) such a fucking shitshow
    local server
    # XXX Discarded servers: hkps://keys.gnupg.net hkps://pgp.mit.edu hkps://keyoxide.org hkps://keybase.io; do
    # hkps://keys.openpgp.org <- may work as well for some of them
    #for server in hkps://keyserver.ubuntu.com; do
    server=hkps://keyserver.ubuntu.com
    >&2 echo "gpg --batch --keyserver $server ${gpgopts[*]} --recv-keys $key"
    # XXX gpg may return 0 but still NOT import the key if it has no user ID, so we HAVE to iterate over them all, for all keys
    # root@af1c2517c790:/# gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B9E2F5981AA6E0CD28160D9FF13993A75599653C; echo $?
    # gpg: key F13993A75599653C: new key but contains no user ID - skipped
    # gpg: Total number processed: 1
    # gpg:           w/o user IDs: 1
    # Quite effed-up ^, gpg
    gpg --batch --keyserver "$server" "${gpgopts[@]}" --recv-keys $key || true
    # && break || {
    #  >&2 echo "No dice. Moving on to next server"
    #  continue
    #}
    #done
    gpg --list-keys --fingerprint --with-colon "$key" | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | head -1 | gpg --import-ownertrust 2>/dev/null
  done
}

platforms::node() {
  printf "linux/amd64 linux/arm64"
  # linux/arm/v7 linux/ppc64le linux/s390x" # linux/arm/v6
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
  #"linux/arm/v6")
  #  arch="linux-armv6l"
  #  ;;
  "linux/ppc64le")
    arch="linux-ppc64le"
    ;;
  "linux/s390x")
    arch="linux-s390x"
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
  >&2 echo gpg --batch --decrypt --output "$(cache::path "$arch" "node-$version.txt")" "$(cache::path "$arch" "node-$version.txt.asc")"
  ls -lA "$(cache::path "$arch" "node-$version.txt.asc")"
  cat "$(cache::path "$arch" "node-$version.txt.asc")"
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
  "linux/arm/v6")
    narch="linux-armv6l"
    ;;
  "linux/ppc64le")
    narch="linux-ppc64le"
    ;;
  "linux/s390x")
    narch="linux-s390x"
    ;;
  esac

  checksum="$(grep " node-v$version-$narch.tar.gz\$" "$(cache::path "$arch" "node-$version.txt")")"

  cache::checksum::verify "$arch" "$binary" "${checksum%% *}" 256
}

init::yarn() {
  local key=6A010C5166006599AA17F08146C2130DFD2497F5
  logger::debug "Importing Yarn key $key"
  # hkps://keys.openpgp.org <- may work as well for some of them
  #for server in hkps://keyserver.ubuntu.com; do
  local server=hkps://keyserver.ubuntu.com
  >&2 echo "gpg --batch --keyserver $server ${gpgopts[*]} --recv-keys $key"
  gpg --batch --keyserver "$server" "${gpgopts[@]}" --recv-keys $key || true
  #done
  gpg --list-keys --fingerprint --with-colon "$key" | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | head -1 | gpg --import-ownertrust 2>/dev/null
}

platforms::yarn() {
  printf "linux/amd64 linux/arm64"
  # linux/arm/v7 linux/arm/v6 linux/ppc64le linux/s390x"
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


entrypoint(){
  local product="$1"
  logger::debug "Checking $product"
  check::"$product"

  init::"$product"

  version="$(env::version::read "$product")"

  for platform in $(platforms::"$product"); do
    binary="$product-$version.tar.gz"
    cache::download "$platform" "$binary" "$(url::"$product" "$platform" "$version")" || {
      logger::error "PANIC. Failed downloading $(url::"$product" "$platform" "$version")"
      exit 1
    }

    checksum::"$product" "$platform" "$version" "$binary" || {
      logger::error "Checksum FAIL! Deleting artifact ($product $platform $version: $binary - checksum was $(cache::checksum::compute "$platform" "$binary"))"
      logger::error "If this was mounted from local cache, you must also remove it on the host (under ./context/cache/linux/$platform/$binary)"
      cache::delete "$platform" "$binary"
      exit 1
    }
  done
}

entrypoint "$@"

#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

FAIL_WHEN_OUTDATED=${FAIL_WHEN_OUTDATED:-}

version::latest::checksum() {
  local lang="$1"
  local base_version="$2"
  shift
  shift
  local platforms=("$@")

  local major=${base_version%%.*}
  local rest=${base_version#*.}
  local minor=${rest%%.*}
  local patch=0
  # Handle short and long versions (X.Y vs. X.Y.Z)
  if [ "$rest" != "$minor" ]; then
    patch=${rest#*.}
  fi

  local platform

  printf >&2 "ENV           %s %s.%s.%s\n" "$(env::version::name "$lang")" "$major" "$minor" "$patch"

  for platform in "${platforms[@]}"; do
    cache::download "$platform" "$lang-$major.$minor.$patch.tar.gz" "$(url::"$lang" "$major" "$minor" "$patch" "$platform")"
    printf >&2 "ENV           %s %s\n" \
      "$(env::checksum::name "$lang" "$platform")" \
      "$(cache::checksum::compute "$platform" "$lang-$major.$minor.$patch.tar.gz")"
  done
}

check::golang() {
  local version

  version="$(env::version::read "golang")"

  if ! newversion=$(version::latest::patch url::golang "$version" "linux/amd64"); then
    logger::error "There is a more recent patch for the version of golang you want. You must update:"

    version::latest::checksum "golang" "$newversion" "linux/amd64" "linux/arm64" "linux/arm/v7" "linux/arm/v6"

    [ ! "$FAIL_WHEN_OUTDATED" ] || {
      logger::error "We will stop now - if you really want to NOT update though and build with that, set the build argument 'FAIL_WHEN_OUTDATED='";
      exit 1
    }
  fi

  if ! newversion=$(version::latest::minor url::golang "$version" "linux/amd64"); then
    ! newversion=$(version::latest::patch url::golang "$newversion" "linux/amd64")
    logger::warning "Although you are running a fully patched version of golang ($version), there is a new minor version that you should migrate to:"

    version::latest::checksum "golang" "$newversion" "linux/amd64" "linux/arm64" "linux/arm/v7" "linux/arm/v6"
  fi
}

check::node() {
  local version

  version="$(env::version::read "node")"

  if  ! newversion=$(version::latest::minor url::node "$version" "linux/amd64") || \
      ! newversion=$(version::latest::patch url::node "$version" "linux/amd64"); then

    ! newversion=$(version::latest::patch url::node "$newversion" "linux/amd64")
    logger::error "There is a new patch for Node. You must update to $newversion (you currently asked for $version)"

    [ ! "$FAIL_WHEN_OUTDATED" ] || {
      logger::error "We will stop now - if you really want to NOT update though and build with that, set the build argument 'FAIL_WHEN_OUTDATED='";
      exit 1
    }
  fi

  if ! newversion=$(version::latest::major url::node "$version" "linux/amd64" "evenonly"); then
    ! newversion=$(version::latest::minor url::node "$newversion" "linux/amd64")
    ! newversion=$(version::latest::patch url::node "$newversion" "linux/amd64")
    logger::warning "There is a new major version of Node that you should migrate to: $newversion (you currently asked for $version)"
  fi
}

check::yarn() {
  local version

  version="$(env::version::read "yarn")"
  if  ! newversion=$(version::latest::minor url::yarn "$version" "linux/amd64") || \
      ! newversion=$(version::latest::patch url::yarn "$version" "linux/amd64"); then

    ! newversion=$(version::latest::patch url::yarn "$newversion" "linux/amd64")
    logger::error "There is a new patch for Yarn. You must update to $newversion (you currently asked for $version)"

    [ ! "$FAIL_WHEN_OUTDATED" ] || {
      logger::error "We will stop now - if you really want to NOT update though and build with that, set the build argument 'FAIL_WHEN_OUTDATED='";
      exit 1
    }
  fi

  if ! newversion=$(version::latest::major url::yarn "$version"); then
    ! newversion=$(version::latest::minor url::yarn "$newversion")
    ! newversion=$(version::latest::patch url::yarn "$newversion")
    logger::warning "There is a new major version of Yarn that you should migrate to: $newversion (you currently asked for $version)"
  fi
}

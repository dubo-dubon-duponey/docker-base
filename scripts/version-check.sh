#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

FAIL_WHEN_OUTDATED=${FAIL_WHEN_OUTDATED:-}
GOLANG_VERSION=${GOLANG_VERSION:-1.13.0}
NODE_VERSION=${NODE_VERSION:-10.16.0}
YARN_VERSION=${YARN_VERSION:-1.17.0}

url::golang(){
  local sub="$2"
  if [ "$3" ] && [ "$3" != "0" ]; then
    sub="$sub.$3"
  fi
  printf "https://dl.google.com/go/go%s.%s.linux-%s.tar.gz" "$1" "$sub" "$4"
}

url::node(){
  printf "https://nodejs.org/dist/v%s.%s.%s/node-v%s.%s.%s-linux-%s.tar.xz" "$1" "$2" "$3" "$1" "$2" "$3" "$4"
}

url::yarn(){
  printf "https://github.com/yarnpkg/yarn/releases/download/v%s.%s.%s/yarn-v%s.%s.%s.tar.gz" "$1" "$2" "$3" "$1" "$2" "$3"
}

version::latest::checksum(){
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

  local platform=${platforms[0]}

  local varname
  varname=$(printf "%s" "$lang" | tr '[:lower:]' '[:upper:]')
  local platformname

  >&2 printf "ENV           ${varname}_VERSION %s.%s.%s\n" "$major" "$minor" "$patch"

  for platform in "${platforms[@]}"; do
    platformname=$(printf "%s" "$platform" | tr '[:lower:]' '[:upper:]')
    checksum=$(curl -k -fsSL "$(url::"$lang" "$major" "$minor" "$patch" "$platform")" | sha512sum)
    >&2 printf "ENV           ${varname}_${platformname}_SHA512 %s\n" "${checksum%*-}"
  done
}

version::latest::patch(){
  local lang="$1"
  local base_version="$2"
  local platform="${3:-}"

  local major=${base_version%%.*}
  local rest=${base_version#*.}
  local minor=${rest%%.*}
  local patch=0
  # Handle short and long versions (X.Y vs. X.Y.Z)
  if [ "$rest" != "$minor" ]; then
    patch=${rest#*.}
  fi

  local candidate_patch="$patch"
  local next_patch

  next_patch=$((patch + 1))
  while [ "$(curl -k -I -o /dev/null -v "$(url::"$lang" "$major" "$minor" "$next_patch" "$platform")" 2>&1 | grep -E "HTTP/[0-9.]+ [0-9]{3}" | sed -E 's/.* ([0-9]{3}).*/\1/')" != "404" ]; do
    candidate_patch="$next_patch"
    next_patch=$((next_patch + 1))
  done
  printf "$major.$minor.$candidate_patch"
  if [ "$candidate_patch" != "$patch" ];then
    return 1
  fi
}

version::latest::minor(){
  local lang="$1"
  local base_version="$2"
  local platform="${3:-}"

  local major=${base_version%%.*}
  local rest=${base_version#*.}
  local minor=${rest%%.*}
  local patch=0

  local candidate_minor=${minor}
  local next_minor

  next_minor=$((minor + 1))
  while [ "$(curl -k -I -o /dev/null -v "$(url::"$lang" "$major" "$next_minor" "$patch" "$platform")" 2>&1 | grep -E "HTTP/[0-9.]+ [0-9]{3}" | sed -E 's/.* ([0-9]{3}).*/\1/')" != "404" ]; do
    candidate_minor=${next_minor}
    next_minor=$((next_minor + 1))
  done
  printf "$major.$candidate_minor.0"
  if [ "$candidate_minor" != "$minor" ];then
    return 1
  fi
}

version::latest::major(){
  local lang="$1"
  local base_version="$2"
  local platform="${3:-}"
  local evenonly="${4:-}"
  local increment=1
  [ ! "$evenonly" ] || increment=2

  local major=${base_version%%.*}
  local minor=0
  local patch=0

  local candidate_major=${major}
  local next_major

  next_major=$((major + increment))
  while [ "$(curl -k -I -o /dev/null -v "$(url::"$lang" "$next_major" "$minor" "$patch" "$platform")" 2>&1 | grep -E "HTTP/[0-9.]+ [0-9]{3}" | sed -E 's/.* ([0-9]{3}).*/\1/')" != "404" ]; do
    candidate_major=${next_major}
    next_major=$((next_major + increment))
  done
  printf "$candidate_major.0.0"
  if [ "$candidate_major" != "$major" ];then
    return 1
  fi
}

golang(){
  if ! newversion=$(version::latest::patch "golang" "$GOLANG_VERSION" "amd64"); then
    >&2 printf "ERROR: you are trying to build with an outdated version of golang. You must update to:\n"
    version::latest::checksum "golang" "$newversion" "amd64" "arm64" "armv6l"
    if [ "$FAIL_WHEN_OUTDATED" ]; then
      >&2 printf "ERROR: we will stop now - if you really want to NOT update though, set the build argument 'FAIL_WHEN_OUTDATED='\n"
      exit 1
    fi
  fi

  if ! newversion=$(version::latest::minor "golang" "$GOLANG_VERSION" "amd64"); then
    ! newversion=$(version::latest::patch "golang" "$newversion" "amd64")
    >&2 printf "WARNING: although you are running a fully patched version of golang, there is a new minor version that you should migrate to:\n"
    version::latest::checksum "golang" "$newversion" "amd64" "arm64" "armv6l"
  fi
}

node(){
  if ! newversion=$(version::latest::minor "node" "$NODE_VERSION" "x64"); then
    ! newversion=$(version::latest::patch "node" "$newversion" "x64")
    >&2 printf "ERROR: you are trying to build with an outdated version of node. You must update to $newversion.\n"
#    version::latest::checksum "node" "$newversion" "x64" "arm64" "armv7l"
    if [ "$FAIL_WHEN_OUTDATED" ]; then
      >&2 printf "ERROR: we will stop now - if you really want to NOT update though, set the build argument 'FAIL_WHEN_OUTDATED='\n"
      exit 1
    fi
  fi

  if ! newversion=$(version::latest::patch "node" "$NODE_VERSION" "x64"); then
    >&2 printf "ERROR: you are trying to build with an outdated version of node. You must update to: $newversion.\n"
#    version::latest::checksum "node" "$newversion" "x64" "arm64" "armv7l"
    if [ "$FAIL_WHEN_OUTDATED" ]; then
      >&2 printf "ERROR: we will stop now - if you really want to NOT update though, set the build argument 'FAIL_WHEN_OUTDATED='\n"
      exit 1
    fi
  fi

  if ! newversion=$(version::latest::major "node" "$NODE_VERSION" "x64" "evenonly"); then
    ! newversion=$(version::latest::minor "node" "$newversion" "x64")
    ! newversion=$(version::latest::patch "node" "$newversion" "x64")
    >&2 printf "WARNING: although you are running a fully patched LTS version of node, there is a new LTS version that you should migrate to: $newversion\n"
    # version::latest::checksum "node" "$newversion" "x64" "arm64" "armv7l"
  fi
}

yarn(){
  if ! newversion=$(version::latest::minor "yarn" "$YARN_VERSION"); then
    ! newversion=$(version::latest::patch "yarn" "$newversion")
    >&2 printf "ERROR: you are trying to build with an outdated version of yarn. You must update to $newversion.\n"
    if [ "$FAIL_WHEN_OUTDATED" ]; then
      >&2 printf "ERROR: we will stop now - if you really want to NOT update though, set the build argument 'FAIL_WHEN_OUTDATED='\n"
      exit 1
    fi
  fi

  if ! newversion=$(version::latest::patch "yarn" "$YARN_VERSION"); then
    >&2 printf "ERROR: you are trying to build with an outdated version of yarn. You must update to: $newversion.\n"
    if [ "$FAIL_WHEN_OUTDATED" ]; then
      >&2 printf "ERROR: we will stop now - if you really want to NOT update though, set the build argument 'FAIL_WHEN_OUTDATED='\n"
      exit 1
    fi
  fi

  if ! newversion=$(version::latest::major "yarn" "$YARN_VERSION"); then
    ! newversion=$(version::latest::minor "yarn" "$newversion")
    ! newversion=$(version::latest::patch "yarn" "$newversion")
    >&2 printf "WARNING: although you are running a fully patched version of yarn, there is a new LTS version that you should migrate to: $newversion\n"
    # version::latest::checksum "node" "$newversion" "x64" "arm64" "armv7l"
  fi
}

golang
node
yarn

#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

#############################################################
# Cache helpers
# XXX it seems like yarn at least does not support tls v1.3, so, only enforcing 1.2 for now
#############################################################
readonly CACHE_ROOT=/cache

cache::download(){
  local arch="$1"
  local name="$2"

  local url="$3"

  mkdir -p "$CACHE_ROOT/$arch"
  [ -f "$CACHE_ROOT/$arch/$name" ] || curl --tlsv1.2 -sSfL --compressed -o "$CACHE_ROOT/$arch/$name" "$url" # >/dev/null 2>&1
}

cache::path(){
  local arch="$1"
  local name="$2"

  printf "%s/%s/%s" "$CACHE_ROOT" "$arch" "$name"
}

# XXX if something was corrupted in the existing cache that was mounted, no new download occured, and we just fail
# One has to purge the local cache to fix that
cache::delete(){
  local arch="$1"
  local name="$2"

  rm -f "$CACHE_ROOT/$arch/$name"
}

cache::checksum::compute(){
  local arch="$1"
  local name="$2"
  local type="${3:-512}"

  local checksum

  checksum="$("sha${type}sum" "$CACHE_ROOT/$arch/$name")"
  printf "%s" "${checksum%% *}"
}

cache::checksum::verify(){
  local arch="$1"
  local name="$2"
  local checksum="$3"
  local type="${4:-512}"

  printf "%s %s" "$checksum" "$CACHE_ROOT/$arch/$name" | "sha${type}sum" -c - >/dev/null
}

#############################################################
# Env manipulation helpers
#############################################################
env::checksum::name(){
  local product="$1"
  local arch="$2"

  printf "%s_%s_SHA512" "$product" "$arch" | tr '/' '_' | tr '[:lower:]' '[:upper:]'
}

env::checksum::read(){
  local product="$1"
  local arch="$2"
  local varname

  varname="$(printf "%s_%s_SHA512" "$product" "$arch" | tr '/' '_' | tr '[:lower:]' '[:upper:]')"
  printf "%s" "${!varname:-}"
}

env::version::name(){
  local product="$1"

  printf "%s_VERSION" "$product" | tr '/' '_' | tr '[:lower:]' '[:upper:]'
}

env::version::read(){
  local product="$1"

  varname="$(printf "%s_VERSION" "$product" | tr '/' '_' | tr '[:lower:]' '[:upper:]')"
  printf "%s" "${!varname:-}"
}

#############################################################
# Logging helpers
#############################################################
readonly COLOR_RED=1
readonly COLOR_GREEN=2
readonly COLOR_YELLOW=3
readonly COLOR_WHITE=7

# Prefix a date to a log line and output to stderr
logger::stamp(){
  local color="$1"
  local level="$2"
  local i
  shift
  shift
  [ ! "$TERM" ] || [ ! -t 2 ] || >&2 tput setaf "$color"
  for i in "$@"; do
    printf >&2 "[%s] [%s] %s\n" "$(date)" "$level" "$i"
  done
  [ ! "$TERM" ] || [ ! -t 2 ] || >&2 tput op
}

logger::debug(){
  logger::stamp "$COLOR_WHITE" "DEBUG" "$@"
}

logger::info(){
  logger::stamp "$COLOR_GREEN" "INFO" "$@"
}

logger::warning(){
  logger::stamp "$COLOR_YELLOW" "WARNING" "$@"
}

logger::error(){
  logger::stamp "$COLOR_RED" "ERROR" "$@"
}

#############################################################
# Version detectors
#############################################################
version::latest::patch(){
  local urlfunction="$1"
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
  echo >&2 curl --tlsv1.2 -L -I -o /dev/null -v "$("$urlfunction" "$platform" "$major" "$minor" "$next_patch")"
  while curl --tlsv1.2 -L -I -o /dev/null -v "$("$urlfunction" "$platform" "$major" "$minor" "$next_patch")" 2>&1 | grep -qE "HTTP/[0-9. ]+ 200"; do
  #while [ "$(curl --tlsv1.2 -L -I -o /dev/null -v "$("$urlfunction" "$platform" "$major" "$minor" "$next_patch")" 2>&1 | grep -E "HTTP/[0-9.]+ [0-9]{3}" | tail -1 | sed -E 's/.* ([0-9]{3}).*/\1/')" != "404" ]; do
    candidate_patch="$next_patch"
    next_patch=$((next_patch + 1))
    echo >&2 curl --tlsv1.2 -L -I -o /dev/null -v "$("$urlfunction" "$platform" "$major" "$minor" "$next_patch")"
    curl --tlsv1.2 -L -I -o /dev/null -v "$("$urlfunction" "$platform" "$major" "$minor" "$next_patch")" 2>&1 | grep -E "HTTP/[0-9.]+" 1>&2
    sleep 1
  done

  printf "%s.%s.%s" "$major" "$minor" "$candidate_patch"
  if [ "$candidate_patch" != "$patch" ];then
    return 1
  fi
}

version::latest::minor(){
  local urlfunction="$1"
  local base_version="$2"
  local platform="${3:-}"

  local major=${base_version%%.*}
  local rest=${base_version#*.}
  local minor=${rest%%.*}
  local patch=0

  local candidate_minor=${minor}
  local next_minor

  next_minor=$((minor + 1))

  echo >&2 curl --tlsv1.2 -L -I -o /dev/null -v "$("$urlfunction" "$platform" "$major" "$next_minor" "$patch")"
  while curl --tlsv1.2 -L -I -o /dev/null -v "$("$urlfunction" "$platform" "$major" "$next_minor" "$patch")" 2>&1 | grep -qE "HTTP/[0-9. ]+ 200"; do
#  while [ "$(curl --tlsv1.2 -L -I -o /dev/null -v "$("$urlfunction" "$platform" "$major" "$next_minor" "$patch")" 2>&1 | grep -E "HTTP/[0-9.]+ [0-9]{3}" | tail -1 | sed -E 's/.* ([0-9]{3}).*/\1/')" != "404" ]; do
    candidate_minor=${next_minor}
    next_minor=$((next_minor + 1))
    echo >&2 curl --tlsv1.2 -L -I -o /dev/null -v "$("$urlfunction" "$platform" "$major" "$next_minor" "$patch")"
    curl --tlsv1.2 -L -I -o /dev/null -v "$("$urlfunction" "$platform" "$major" "$next_minor" "$patch")" 2>&1 | grep -E "HTTP/[0-9.]" 1>&2
    sleep 1
  done

  printf "%s.%s.0" "$major" "$candidate_minor"
  if [ "$candidate_minor" != "$minor" ];then
    return 1
  fi
}

version::latest::major(){
  local urlfunction="$1"
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
  echo >&2 curl --tlsv1.2 -L -I -o /dev/null -v "$("$urlfunction" "$platform" "$next_major" "$minor" "$patch")"
  while curl --tlsv1.2 -L -I -o /dev/null -v "$("$urlfunction" "$platform" "$next_major" "$minor" "$patch")" 2>&1 | grep -qE "HTTP/[0-9. ]+ 200"; do
    candidate_major=${next_major}
    next_major=$((next_major + increment))
    echo >&2 curl --tlsv1.2 -L -I -o /dev/null -v "$("$urlfunction" "$platform" "$next_major" "$minor" "$patch")"
    curl --tlsv1.2 -L -I -o /dev/null -v "$("$urlfunction" "$platform" "$next_major" "$minor" "$patch")" 2>&1 | grep -E "HTTP/[0-9.]+" 1>&2
    sleep 1
  done
  printf "%s.0.0" "$candidate_major"
  if [ "$candidate_major" != "$major" ];then
    return 1
  fi
}


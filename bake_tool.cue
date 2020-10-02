// platf: [...string] @tag(platforms)

import (
  "tool/os"
  "strings"
  "tool/cli"
)

command: {
  // tarball: "cache/export-oci.tar"
  // tarballtype: "oci"
  //  	no_cache: nocache | *false
  // XXX how do you do that with buildkit?
  // pull = true

  downloader: #Bake & {
    target: "downloader"
    context: "context/builder"
    dockerfile: "Dockerfile.downloader"

    platforms: [AMD64]

    directory: "context/builder"

    args: os.Getenv & {
      http_proxy: string | * ""
      https_proxy: string | * ""
      APT_OPTIONS: string | * "Acquire::HTTP::User-Agent=DuboDubonDuponey/0.1 Acquire::Check-Valid-Until=no"
      APT_SOURCES: string | * ""
      APT_TRUSTED: string | * ""

      BUILDER_BASE: string | * "dubodubonduponey/debian@sha256:05ff8e388e27caddcc2eb07056aaec33af736ba8639939081feeace936df4d54"
    }
  }

  overlay: #Bake & {
    target: "overlay"
    context: "context/empty"
    dockerfile: "Dockerfile.builder"

    platforms: [AMD64]

    directory: "context/builder/cache/overlay"

    args: os.Getenv & {
      http_proxy: string | * ""
      https_proxy: string | * ""
      APT_OPTIONS: string | * "Acquire::HTTP::User-Agent=DuboDubonDuponey/0.1 Acquire::Check-Valid-Until=no"
      APT_SOURCES: string | * ""
      APT_TRUSTED: string | * ""

      BUILDER_BASE: string | * "dubodubonduponey/debian@sha256:05ff8e388e27caddcc2eb07056aaec33af736ba8639939081feeace936df4d54"
    }
    //  string | * "default as in cue" | string @tag(TESTIT,type=string)
  }

  builder: #Bake & {
    target: "builder"
    context: "context/builder"
    dockerfile: "Dockerfile.builder"

    args: os.Getenv & {
      BUILD_TITLE: "Dubo Builder"
      BUILD_DESCRIPTION: "Base builder image for all DBDBDP images"

      BUILD_CREATED: string | *"1900-01-01",
      BUILD_URL: string | *"https://github.com/dubo-dubon-duponey/unknown",
      BUILD_DOCUMENTATION: string | *"\(BUILD_URL)/blob/master/README.md",
      BUILD_SOURCE: string | *"\(BUILD_URL)/tree/master",
      BUILD_VERSION: string | *"unknown",
      BUILD_REVISION: string | *"unknown",
      BUILD_VENDOR: string | *"dubodubonduponey",
      BUILD_LICENSES: string | *"MIT",
      BUILD_REF_NAME: string | *"latest",

      http_proxy: string | * ""
      https_proxy: string | * ""
      APT_OPTIONS: string | * "Acquire::HTTP::User-Agent=DuboDubonDuponey/0.1 Acquire::Check-Valid-Until=no"
      APT_SOURCES: string | * ""
      APT_TRUSTED: string | * ""

      BUILDER_BASE: string | * "dubodubonduponey/debian@sha256:05ff8e388e27caddcc2eb07056aaec33af736ba8639939081feeace936df4d54"
    }

    platforms: [
      AMD64,
      ARM64,
      V6,
      V7,
      I386,
      S390X,
      PPC64LE,
    ]
  }

  builder_node: #Bake & {
    target: "builder-node"
    context: "context/builder"
    dockerfile: "Dockerfile.builder"

    args: os.Getenv & {
      BUILD_TITLE: "Dubo Builder with Node"
      BUILD_DESCRIPTION: "Base builder image for all DBDBDP images (with Node)"

      BUILD_CREATED: string | *"1900-01-01",
      BUILD_URL: string | *"https://github.com/dubo-dubon-duponey/unknown",
      BUILD_DOCUMENTATION: string | *"\(BUILD_URL)/blob/master/README.md",
      BUILD_SOURCE: string | *"\(BUILD_URL)/tree/master",
      BUILD_VERSION: string | *"unknown",
      BUILD_REVISION: string | *"unknown",
      BUILD_VENDOR: string | *"dubodubonduponey",
      BUILD_LICENSES: string | *"MIT",
      BUILD_REF_NAME: string | *"latest",

      http_proxy: string | * ""
      https_proxy: string | * ""
      APT_OPTIONS: string | * "Acquire::HTTP::User-Agent=DuboDubonDuponey/0.1 Acquire::Check-Valid-Until=no"
      APT_SOURCES: string | * ""
      APT_TRUSTED: string | * ""

      BUILDER_BASE: string | * "dubodubonduponey/debian@sha256:05ff8e388e27caddcc2eb07056aaec33af736ba8639939081feeace936df4d54"
    }

    platforms: [
      AMD64,
      ARM64,
      V6,
      V7,
      S390X,
      PPC64LE,
    ]
  }

  runtime: #Bake & {
    target: "runtime"
    context: "context/builder/cache/overlay"
    dockerfile: "Dockerfile.runtime"

    args: os.Getenv & {
      http_proxy: string | * ""
      https_proxy: string | * ""
      APT_OPTIONS: string | * "Acquire::HTTP::User-Agent=DuboDubonDuponey/0.1 Acquire::Check-Valid-Until=no"
      APT_SOURCES: string | * ""
      APT_TRUSTED: string | * ""

      RUNTIME_BASE: string | * "dubodubonduponey/debian@sha256:05ff8e388e27caddcc2eb07056aaec33af736ba8639939081feeace936df4d54"
    }

    platforms: [
      AMD64,
      ARM64,
      V6,
      V7,
      I386,
      S390X,
      PPC64LE,
    ]
  }
}

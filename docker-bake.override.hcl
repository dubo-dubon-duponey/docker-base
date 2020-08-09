variable "REGISTRY" {
  default = "docker.io"
}

variable "VENDOR" {
  default = "dubodubonduponey"
}

variable "DEBIAN_DATE" {
  default = "2020-01-01"
}

variable "DEBIAN_SUITE" {
  default = "buster"
}

variable "PWD" {
  default = "."
}

variable "BUILDER_BASE" {
  default = ""
}

variable "RUNTIME_BASE" {
  default = ""
}

target "base-shared" {
  args = {
    BUILDER_BASE = "${equal(BUILDER_BASE,"") ? "${REGISTRY}/dubodubonduponey/debian:${DEBIAN_SUITE}-${DEBIAN_DATE}" : "${BUILDER_BASE}"}"
    RUNTIME_BASE = "${equal(RUNTIME_BASE,"") ? "${REGISTRY}/dubodubonduponey/debian:${DEBIAN_SUITE}-${DEBIAN_DATE}" : "${RUNTIME_BASE}"}"
  }
}

group "default" {
  targets = ["builder", "builder-node", "runtime"]
}

target "downloader" {
  inherits = ["shared"]
  dockerfile = "${PWD}/Dockerfile.downloader"
  context = "${PWD}/context/builder"
  target = "downloader"
  tags = []
  platforms = ["linux/amd64"]
  args = {
    BUILDER_BASE = "${REGISTRY}/dubodubonduponey/debian@sha256:87fcbc5d89e3a85fb43752c96352d6071519479b41eac15e4128118e250b4b73"
  }
  output = [
    "${PWD}/context/builder",
  ]
}

target "overlay" {
  inherits = ["shared"]
  dockerfile = "${PWD}/Dockerfile.builder"
  context = "${PWD}/context/empty"
  target = "overlay"
  tags = []
  platforms = ["linux/amd64"]
  args = {
    BUILDER_BASE = "${REGISTRY}/dubodubonduponey/debian@sha256:87fcbc5d89e3a85fb43752c96352d6071519479b41eac15e4128118e250b4b73"
  }
  output = [
    "${PWD}/context/builder/overlay",
  ]
}


target "builder" {
  inherits = ["shared", "base-shared"]
  dockerfile = "${PWD}/Dockerfile.builder"
  context = "${PWD}/context/builder"
  args = {
    BUILD_TITLE = "Dubo Builder"
    BUILD_DESCRIPTION = "Base builder image for all DBDBDP images"
  }
  tags = [
    "${REGISTRY}/${VENDOR}/base:builder-${DEBIAN_SUITE}-${DEBIAN_DATE}",
  ]
  target = "builder"
}

target "builder-node" {
  inherits = ["shared", "base-shared"]
  dockerfile = "${PWD}/Dockerfile.builder"
  context = "${PWD}/context/builder"
  args = {
    BUILD_TITLE = "Dubo Builder with Node"
    BUILD_DESCRIPTION = "Base builder image for all DBDBDP images (with Node)"
  }
  # No v6 for node
  platforms = [
    "linux/amd64",
    "linux/arm64",
    "linux/arm/v7",
  ]
  tags = [
    "${REGISTRY}/${VENDOR}/base:builder-node-${DEBIAN_SUITE}-${DEBIAN_DATE}",
  ]
  target = "builder-node"
}

target "runtime" {
  inherits = ["shared", "base-shared"]
  dockerfile = "${PWD}/Dockerfile.runtime"
  context = "${PWD}/context/builder/overlay"
  args = {
    BUILD_TITLE = "Dubo Runtime"
    BUILD_DESCRIPTION = "Base runtime image for all DBDBDP images"
  }
  tags = [
    "${REGISTRY}/${VENDOR}/base:runtime-${DEBIAN_SUITE}-${DEBIAN_DATE}",
  ]
}

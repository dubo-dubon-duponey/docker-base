variable "REGISTRY" {
  default = "docker.io"
}

variable "VENDOR" {
  default = "dubodubonduponey"
}

variable "DEBOOTSTRAP_DATE" {
  default = "2020-01-01"
}

variable "DEBOOTSTRAP_SUITE" {
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
    BUILDER_BASE = "${equal(BUILDER_BASE,"") ? "${REGISTRY}/dubodubonduponey/debian:${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}" : "${BUILDER_BASE}"}"
    RUNTIME_BASE = "${equal(RUNTIME_BASE,"") ? "${REGISTRY}/dubodubonduponey/debian:${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}" : "${RUNTIME_BASE}"}"
  }
}

group "default" {
  targets = ["overlay", "builder", "builder-node", "runtime"]
}

target "downloader" {
  inherits = ["shared"]
  dockerfile = "${PWD}/Dockerfile.downloader"
  context = "${PWD}/context/builder"
  target = "downloader"
  tags = []
  platforms = ["linux/amd64"]
  args = {
    BUILDER_BASE = "${REGISTRY}/dubodubonduponey/debian@sha256:e4347b6edff261b1f21e8448a25374e502375e4bf5c8d8ae11fb7c3c005044ab"
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
    BUILDER_BASE = "${REGISTRY}/dubodubonduponey/debian@sha256:e4347b6edff261b1f21e8448a25374e502375e4bf5c8d8ae11fb7c3c005044ab"
  }
  output = [
    "${PWD}/context/builder/cache/overlay",
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
    "${REGISTRY}/${VENDOR}/base:builder-${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}",
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
    "${REGISTRY}/${VENDOR}/base:builder-node-${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}",
  ]
  target = "builder-node"
}

target "runtime" {
  inherits = ["shared", "base-shared"]
  dockerfile = "${PWD}/Dockerfile.runtime"
  context = "${PWD}/context/builder/cache/overlay"
  args = {
    BUILD_TITLE = "Dubo Runtime"
    BUILD_DESCRIPTION = "Base runtime image for all DBDBDP images"
  }
  tags = [
    "${REGISTRY}/${VENDOR}/base:runtime-${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}",
  ]
}

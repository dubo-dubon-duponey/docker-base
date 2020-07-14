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
  context = "${PWD}/context/downloader"
  tags = []
  platforms = ["local"]
  args = {
    BUILDER_BASE = "docker.io/dubodubonduponey/debian@sha256:cb25298b653310dd8b7e52b743053415452708912fe0e8d3d0d4ccf6c4003746"
  }
  output = [
    "${PWD}/context/builder",
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
  context = "${PWD}/context/runtime"
  args = {
    BUILD_TITLE = "Dubo Runtime"
    BUILD_DESCRIPTION = "Base runtime image for all DBDBDP images"
  }
  tags = [
    "${REGISTRY}/${VENDOR}/base:runtime-${DEBIAN_SUITE}-${DEBIAN_DATE}",
  ]
}

#!/bin/bash
# Recode base development environment docker image builder
set -euo pipefail

BUILDER_NAME="recode-base-dev-env-image-builder"

log () {
  echo -e "${1}" >&2
}

handleExit () {
  docker buildx rm --force "${BUILDER_NAME}"
}

if [[ "${#}" != 1 ]]; then
  echo "usage: $0 <image-tag-name>"
  exit 1
fi

IMAGE_TAG_NAME="${1}"

# Install emulators to cross-build our base
# dev env image for different architectures
docker run -it --rm --privileged tonistiigi/binfmt --install all

# Create and use buildx builder
docker buildx create --name "${BUILDER_NAME}" --use

# Make sure to remove previously
# created builder (even in case of error)
# given that the command "buildx create"
# will return an error if the builder already exists
trap "handleExit" EXIT

cat /tmp/docker-password | docker login --username jeremylevy --password-stdin

log ""

docker buildx build --platform linux/amd64,linux/arm64 -t recodesh/base-dev-env:"${IMAGE_TAG_NAME}" -t recodesh/base-dev-env:latest --push .

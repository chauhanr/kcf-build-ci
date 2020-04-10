#!/usr/bin/env bash

exec 3> `basename "$0"`.trace
BASH_XTRACEFD=3

set -eux

# Start the Docker daemon.
source docker-image-resource/assets/common.sh
max_concurrent_downloads=10
max_concurrent_uploads=10
insecure_registries=""
registry_mirror=""
start_docker \
  "${max_concurrent_downloads}" \
  "${max_concurrent_uploads}" \
  "${insecure_registries}" \
  "${registry_mirror}"
trap 'stop_docker' EXIT

# Login to the Docker registry.
echo "${DOCKER_TEAM_PASSWORD_RW}" | docker login "${DOCKER_REGISTRY}" --username "${DOCKER_TEAM_USERNAME}" --password-stdin

# Extract the fissile binary.
tar xvf ./s3.fissile-linux/fissile-4.3.tar.gz --directory "/usr/local/bin/"

# Pull the stemcell image.
stemcell_version="${STEMCELL_VERSION}"
stemcell_image="${STEMCELL_REPOSITORY}:${stemcell_version}"
docker pull "${stemcell_image}"

# Build the releases.
tasks_dir="$(dirname $0)"

CF_VERSION=$(yq -r .manifest_version ${CF_DEPLOYMENT_YAML})
RELEASE_NAME=$(yq -r ".releases[] | select(.name==\"${RELEASE}\") | .name" ${CF_DEPLOYMENT_YAML})
RELEASE_URL=$(yq -r ".releases[] | select(.name==\"${RELEASE}\") | .url" ${CF_DEPLOYMENT_YAML})
RELEASE_VERSION=$(yq -r ".releases[] | select(.name==\"${RELEASE}\") | .version" ${CF_DEPLOYMENT_YAML})
RELEASE_SHA=$(yq -r ".releases[] | select(.name==\"${RELEASE}\") | .sha1" ${CF_DEPLOYMENT_YAML})

source ${tasks_dir}/build_release.sh; build_release ${CF_VERSION} ${DOCKER_REGISTRY} ${DOCKER_ORGANIZATION} ${DOCKER_TEAM_USERNAME} ${DOCKER_TEAM_PASSWORD_RW} ${STEMCELL_OS} ${stemcell_version} ${stemcell_image} ${RELEASE_NAME} ${RELEASE_URL} ${RELEASE_VERSION} ${RELEASE_SHA}

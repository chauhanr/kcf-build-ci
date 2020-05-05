#!/bin/bash

exec 3> `basename "$0"`.trace
BASH_XTRACEFD=3

set -ex 

# Start Docker Daemon (and set a trap to stop it once this script is done)
echo 'DOCKER_OPTS="--data-root /scratch/docker --max-concurrent-downloads 10"' >/etc/default/docker
service docker start
service docker status
trap 'service docker stop' EXIT
sleep 10

echo "${DOCKER_TEAM_PASSWORD_RW}" | docker login --username "${DOCKER_TEAM_USERNAME}" --password-stdin

# extract the fissile binary
tar xvf ./s3.fissile-linux/fissile.tgz --directory "/usr/local/bin"

VERSION=$(cat release/version)
echo ${VERSION} 

# Pull the stemcell image.
stemcell_version="${STEMCELL_VERSION}"
stemcell_image="${STEMCELL_REPOSITORY}:${stemcell_version}"

docker pull "${stemcell_image}"

if [ ! -e release/sha1 ]; then
  # Calculate sha1sum if the resource is a file from s3. bosh.io resources provide the checksum automatically
  SHA1=$(sha1sum release/*gz | cut -f1 -d ' ' )
else
  SHA1=$(cat release/sha1)
fi

URL="$(cat release/url)"
echo "URL ${URL}"
echo "RELEASE NAME is ${RELEASE_NAME}"
echo "SHA1 for RELEASE VERSION: ${VERSION}, is ${SHA1}"

fissile build release-images --stemcell="${stemcell_image}" --name="${RELEASE_NAME}" --version="${VERSION}" --sha1="${SHA1}" --url="${URL}" 

BUILT_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "$STEMCELL_REPOSITORY" | head -1)
docker tag "${BUILT_IMAGE}" "${REGISTRY_NAMESPACE}/${BUILT_IMAGE}"
docker push "${REGISTRY_NAMESPACE}/${BUILT_IMAGE}"




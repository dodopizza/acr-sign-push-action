#!/bin/bash

set -euo pipefail

# colors
GREEN='\033[0;32m'
PURPLE_BOLD='\033[1;35m'
RED_BOLD='\033[1;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

function usage_info() {
    echo
    echo -e "Usage: ${BLUE}./$(basename "${0}")${NC} ${GREEN}<registry-passphrase> <repository-passphrase> <signer-name> <acr-name> <repository>${NC}"
    echo
    echo -e "    ${GREEN}<registry-passphrase>${NC} - passphrase for registry (root) key"
    echo -e "    ${GREEN}<repository-passphrase>${NC} - passphrase for repository key"
    echo -e "    ${GREEN}<signer-name>${NC} - name of signer, example: ${YELLOW}site${NC}"
    echo -e "    ${GREEN}<acr-name>${NC} - name of ACR repository, example: ${YELLOW}dodoreg${NC}"
    echo -e "    ${GREEN}<repository>${NC} - name of repository, example: ${YELLOW}site-gateway${NC}"
    echo
    exit 1
}

[ $# -lt 5 ] && usage_info

function log() { echo -e "${PURPLE_BOLD}${*}${NC}"; }
function log::red() { echo -e "${RED_BOLD}${*}${NC}"; }

for required_util in az docker jq openssl base64; do
    if ! command -v "${required_util}" &>/dev/null; then
        log::red "[E] ${required_util} is not installed. Please install it and try again."
        exit 1
    fi
done

trap 'log::red [!] Error on line ${LINENO}' ERR
trap 'log [.]' EXIT

export DOCKER_CONTENT_TRUST_ROOT_PASSPHRASE="${1}"
export DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE="${2}"
export DOCKER_CONTENT_TRUST=1

signer="${3}"
acr_name="${4}"
repository="${5}"
repository_full="${acr_name}.azurecr.io/${repository}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
docker_trust_dir="${HOME}/.docker/trust"
artifacts_dir="${script_dir}/artifacts/${acr_name}/${repository}/${signer}"

log "[~] Login to acr. Required to bind repo"
az acr login --name "${acr_name}"

log "[~] Create artifacts dir"
mkdir -p "${artifacts_dir}"

log "[~] Create signer personal key pair to identify who is pushed"
docker trust key generate "${signer}" --dir "${artifacts_dir}/"
signer_pub_key="${artifacts_dir}/${signer}.pub"

log "[~] Bind signer to specific repo"
docker trust signer add --key "${signer_pub_key}" "${signer}" "${repository_full}"

log "[~] Create test image based on alpine"
alpine_image="alpine:latest"
test_image="${repository_full}:signed-image-test"
docker pull "${alpine_image}"
docker tag "${alpine_image}" "${test_image}"

log "[~] Sign tag and push test image based on alpine. Required to create repository metadata"
docker trust sign "${test_image}"

log "[~] Remove local test image based on alpine"
docker image rm "${alpine_image}" "${test_image}"

log "[~] Inspect image metadata"
image_metadata=$(docker trust inspect "${repository_full}")

signer_private_key_id=$(echo "${image_metadata}" | jq -r --arg signer "${signer}" '.[0].Signers[] | select(.Name == $signer) | .Keys[0].ID')
log "[i] Signer key id = ${signer_private_key_id}"
log "[c] Copy signer private key to artifacts dir"
cp "${docker_trust_dir}/private/${signer_private_key_id}.key" "${artifacts_dir}/"

log "[~] Create signer private key file with base64 encoded content to use in GHA secret"
base64 -i "${artifacts_dir}/${signer_private_key_id}.key" | tr -d \\n >"${artifacts_dir}/${signer_private_key_id}.key.base64"

repository_private_key_id=$(echo "${image_metadata}" | jq -r '.[0].AdministrativeKeys[] | select(.Name == "Repository") | .Keys[0].ID')
log "[i] Repository key id = ${repository_private_key_id}"
log "[c] Copy repository private key to artifacts dir"
cp "${docker_trust_dir}/private/${repository_private_key_id}.key" "${artifacts_dir}/"

# About differents between canonical (your host) root key and registry (root) key
# https://stackoverflow.com/questions/58876566/are-there-two-root-keys-in-docker-content-trust
#
# For each file in trust private dir find file with the line "role: root" and get basename of this file without extension
canonical_root_private_key_id=$(find "${docker_trust_dir}/private" -type f -exec grep -l "role: root" {} \; | xargs -I {} basename {} .key)
log "[i] Canonical (your host) root key id = ${canonical_root_private_key_id}"
log "[c] Copy canonical (your host) root private key to artifacts dir"
cp "${docker_trust_dir}/private/${canonical_root_private_key_id}.key" "${artifacts_dir}/"

##

root_metadata_file="${docker_trust_dir}/tuf/${repository_full}/metadata/root.json"

log "[~] Get registry (root) id"
registry_root_key_id=$(jq -r '.signed.roles.root.keyids[0]' <"${root_metadata_file}")
log "[i] Registry (root) key id = ${registry_root_key_id}"

log "[~] Get registry (root) public key encoded"
registry_root_key_public_encoded=$(jq -r --arg rootkeyid "${registry_root_key_id}" '.signed.keys[$rootkeyid].keyval.public' <"${root_metadata_file}")

log "[w] Save registry (root) public certificate to file"
registry_root_public_crt="${artifacts_dir}/${acr_name}.crt"
echo "${registry_root_key_public_encoded}" | base64 -d >"${registry_root_public_crt}"

log "[w] Save registry (root) public key to file"
registry_root_public_key="${artifacts_dir}/${acr_name}.pub"
openssl x509 -pubkey -noout <"${registry_root_public_crt}" >"${registry_root_public_key}"

log "[.] All done!"
log "[.] Artifacts was exported here: ${artifacts_dir}/"

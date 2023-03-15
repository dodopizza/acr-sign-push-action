#!/bin/bash

set -euo pipefail

function usage_info() {
    echo
    echo "Usage: ./$(basename "${0}") <image-ref> <signer-key-id> <signer-key> <repository-passphrase>"
    echo
    echo "    <image-ref> - image reference, example: dodoreg.azurecr.io/site-gateway:latest"
    echo "    <signer-key-id> - signer key id (hash), example: 1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    echo "    <signer-key> - signer key file path, example: ./1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef.key"
    echo "    <repository-passphrase> - passphrase for repository key"
    echo
    exit 1
}

[ $# -lt 4 ] && usage_info

image_ref="${1}"
signer_key_id="${2}"
signer_key="${3}"
repository_passphrase="${4}"

private_key_path="${HOME}/.docker/trust/private/${signer_key_id}.key"

echo "[~] Prepare signing key"
mkdir -p "${HOME}/.docker/trust/private/"
cp -f "${signer_key}" "${private_key_path}"
chmod 600 "${private_key_path}"

export DOCKER_CONTENT_TRUST=1
export DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE="${repository_passphrase}"

echo "[~] Load signing key"
docker trust key load "${private_key_path}"

echo "[~] Sign image"
docker trust sign "${image_ref}"

echo "[~] Inspect image"
docker trust inspect --pretty "${image_ref}"

echo "[.] Done"

#!/bin/bash

set -euo pipefail

function usage_info() {
    echo
    echo "Usage: ./$(basename "${0}") <tags> <signer-key-id> <signer-key> <repository-passphrase>"
    echo
    echo "    <tags> - image tags separated by comma, example: example.azurecr.io/app:latest"
    echo "    <signer-key-id> - signer key id (hash), example: 1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    echo "    <signer-key> - signer key file path, example: ./1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef.key"
    echo "    <repository-passphrase> - passphrase for repository key"
    echo
    exit 1
}

[ $# -lt 4 ] && usage_info

tags="${1}"
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

for tag in ${tags//,/ }; do
    echo "[~] Sign and push image ${tag}"
    docker trust sign "${tag}"

    echo "[~] Inspect image ${tag}"
    docker trust inspect --pretty "${tag}"
done

echo "[.] Done"

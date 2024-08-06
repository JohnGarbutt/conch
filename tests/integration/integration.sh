#! /bin/bash
# SPDX-FileCopyrightText: © 2024 Matt Williams <matt.williams@bristol.ac.uk>
# SPDX-License-Identifier: MIT
set -euo pipefail

# Run the integration tests in podman.

function on_exit {
    rm -f conch.log
    podman pod logs conch > conch.log
    echo "Shutting down pod"
    podman pod rm --force --time=0 conch || podman pod rm --force conch
}

trap on_exit EXIT

function wait_for_url {
    echo "Testing $1..."
    printf 'GET %s\nHTTP 200' "$1" | hurl --retry "$2" > /dev/null;
    return 0
}

echo "Starting container"
tests/integration/run.sh

echo "Waiting server to be ready"
wait_for_url "http://0.0.0.0:3000" 60

echo "Getting auth issuer URL"
ISSUER=$(curl --no-progress-meter http://0.0.0.0:3000/issuer)

echo "Logging in as test user"
TOKEN=$(curl --silent --show-error --data "username=test&password=test&grant_type=password&client_id=conch" ${ISSUER}/protocol/openid-connect/token | jq --raw-output '.access_token')

echo "Running Hurl tests"
hurl \
    --variable conch="http://0.0.0.0:3000" \
    --variable token="${TOKEN}" \
    --test tests/integration/*.hurl \
    --report-html results \
    --error-format long \
    --color


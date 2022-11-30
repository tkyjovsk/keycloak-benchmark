#!/usr/bin/env bash
set -e

namespace=keycloak
scale=${1:-1}

kubectl -n $namespace patch keycloak/keycloak --type merge --patch="{\"spec\": {\"instances\": ${scale} }}"

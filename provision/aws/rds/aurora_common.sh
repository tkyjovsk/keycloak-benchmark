#!/usr/bin/env bash
set -e

export AURORA_CLUSTER=${AURORA_CLUSTER:-"keycloak"}
export AURORA_ENGINE=${AURORA_ENGINE:-"aurora-postgresql"}
export AURORA_ENGINE_VERSION=${AURORA_ENGINE_VERSION:-"16.1"}
export AURORA_INSTANCES=${AURORA_INSTANCES:-"1"}
export AURORA_INSTANCE_CLASS=${AURORA_INSTANCE_CLASS:-"db.t4g.large"}
export AURORA_PASSWORD=${AURORA_PASSWORD:-"secret99"}
export AURORA_REGION=${AURORA_REGION}
export AURORA_SECURITY_GROUP_NAME=${AURORA_SECURITY_GROUP_NAME:-"${AURORA_CLUSTER}-security-group"}
export AURORA_SUBNET_GROUP_NAME=${AURORA_SUBNET_GROUP_NAME:-"${AURORA_CLUSTER}-subnet-group"}
export AURORA_USERNAME=${AURORA_USERNAME:-"keycloak"}
export AWS_REGION=${AWS_REGION:-${AURORA_REGION}}
export AWS_PAGER=""

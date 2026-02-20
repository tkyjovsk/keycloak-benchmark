#!/usr/bin/env bash
set -e
export NAMESPACE="${NAMESPACE:-$(whoami)-keycloak}"
echo "NAMESPACE: ${NAMESPACE}"

scale=${1:-1}
timeout=${2:-60}

echo "Scaling Keycloak to $scale pods."
kubectl -n ${NAMESPACE} patch keycloaks.k8s.keycloak.org/keycloak --type merge --patch="{\"spec\": {\"instances\": ${scale} }}"

if [ "$timeout" == "0" ]; then
  echo "Not waiting for Keycloak to be scaled to $scale pods."
else
  echo "Waiting up to $timeout seconds for Keycloak to be scaled to $scale pods."
  t0=$(date +%s)
  while [ "$(( $(date +%s) - $t0 ))" -lt $timeout ]; do
    if [ "$(kubectl -n ${NAMESPACE} get pods -o name | grep -oP 'keycloak-[0-9]+' | wc -l)" == "${scale}" ]; then 
      echo "Keycloak is scaled to $scale pods."
      exit
    fi
    sleep 1
  done
  echo "Timed out after ${timeout} seconds."
  exit 1
fi

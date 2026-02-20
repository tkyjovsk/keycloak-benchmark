#!/usr/bin/env bash
set -e
export NAMESPACE="${NAMESPACE:-$(whoami)-keycloak}"
for pod in $(kubectl -n ${NAMESPACE} get pods -o name | grep -oP "keycloak-[0-9]+"); do 
  echo "pods/${pod} .spec.containers[0].image:            $(kubectl -n ${NAMESPACE} get pods/${pod} -o jsonpath='{.spec.containers[0].image}')"
  echo "pods/${pod} .status.containerStatuses[0].image:   $(kubectl -n ${NAMESPACE} get pods/${pod} -o jsonpath='{.status.containerStatuses[0].image}')"
  echo "pods/${pod} .status.containerStatuses[0].imageID: $(kubectl -n ${NAMESPACE} get pods/${pod} -o jsonpath='{.status.containerStatuses[0].imageID}')"
done
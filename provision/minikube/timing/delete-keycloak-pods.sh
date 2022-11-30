#!/usr/bin/env bash
set -e

namespace=keycloak
deletePodsLimit=${1:-all}
keycloakResource="keycloak/keycloak"

echo "Killing ${deletePodsLimit} Keycloak pods"
if [ "${deletePodsLimit}" = "all" ]; then deletePodsLimit=999999; fi
for pod in $(kubectl -n $namespace get pods -o name | grep -oP "keycloak-[0-9]+" | head -n ${deletePodsLimit} ); do 
  kubectl -n $namespace delete pod $pod &
done

echo "Waiting for the 'Ready' status of the Keycloak resource to become 'false'."
until [ "$(kubectl -n $namespace get ${keycloakResource} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" == "false" ]; do sleep 0.1; done
echo "The 'Ready' status of the Keycloak resource is now 'false'."

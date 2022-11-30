#!/usr/bin/env bash
# 
# This script will:
#  - kill all Keycloak pods
#  - wait for the 'Ready' status of Keycloak resource to become 'false' to mark the start of measurement
#  - wait for the first HTTP 200 response from the Keycloak service 
#  - compute the time differernce in ms
#

set -e

namespace="keycloak"
keycloakResource="keycloak/keycloak"
csvFile="keycloak-service-curl-timing.csv"

if [ $# -eq 0 ]
then
  HOST=$(minikube ip).nip.io
else
  HOST=$0
fi

echo "Killing all Keycloak pods"
for pod in $(kubectl -n $namespace get pods -o name | grep -oP "keycloak-[0-9]+"); do 
  kubectl -n $namespace delete pod $pod &
done

echo "Waiting for the 'Ready' status of Keycloak resource to become 'false'."
until [ "$(kubectl -n $namespace get ${keycloakResource} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" == "false" ]; do
  sleep 0.1
done
echo "The 'Ready' status of Keycloak resource is now 'false'. Starting the measurement."

echo "Waiting for the first HTTP 200 response from Keycloak server."
unset dateStartNanos
while [[ "$(curl --head -s -o /dev/null -w ''%{http_code}'' -k https://keycloak.${HOST}/realms/master/.well-known/openid-configuration)" != "200" ]]; do 
  if [ -z "$dateStartNanos" ]; then dateStartNanos=$(date +%s%N); fi
  sleep .001; 
done

if [ -z "$dateStartNanos" ]; then 
  echo "ERROR: Already the first request was successful. Unable to deduce startup time."
  exit 1
else
  keycloakStartupMillis=$(( ($(date +%s%N) - $dateStartNanos) / 1000000 ))
fi

if [ ! -f "${csvFile}" ]; then
  echo "Time of measurement (UTC),Namespace,Keycloak resource,Keycloak startup time measured via cURL (ms)" > "${csvFile}"
fi
echo "$(date -uIseconds),${namespace},${keycloakResource},$keycloakStartupMillis" >> "${csvFile}"
echo "Keycloak service startup time measured via cURL: $keycloakStartupMillis ms"

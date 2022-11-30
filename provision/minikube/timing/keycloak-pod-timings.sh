#!/bin/bash
#
# This script will:
#   - wait for the Keycloak resource to become ready
#   - for all Keycloak pods:
#     - record time differences between conditions: PodScheduled --> Initialized --> ContainersReady --> Ready
#     - record Keycloak server startup time and Quarkus augmentation time as reported in the pod log
#

set -e

namespace="keycloak"
keycloakResource="keycloak/keycloak"
csvFile="keycloak-pod-timings.csv"

echo "Waiting for the 'Ready' status of the Keycloak resource to become 'true'."
until [ "$(kubectl -n ${namespace} get ${keycloakResource} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" == "true" ]; do sleep 1; done
echo "The 'Ready' status of the Keycloak resource is now 'true'."

for keycloakPod in $(kubectl -n $namespace get pods -o name | grep -oP "keycloak-[0-9]+"); do 
  echo "Getting timing information for pod: '$keycloakPod'"

  kubectl -n $namespace wait --for=condition=PodScheduled=true pod/${keycloakPod}
  podUID=$(kubectl -n $namespace get pods/${keycloakPod} -o jsonpath='{.metadata.uid}')
  if grep -q "$podUID" "$csvFile"; then
    echo "Timing information for pod '$keycloakPod' with UID '$podUID' already recorded in '$csvFile'. Skipping."
  else

    # Pod timings
    kubectl -n $namespace wait --for=condition=Initialized=true pod/${keycloakPod}
    kubectl -n $namespace wait --for=condition=ContainersReady=true pod/${keycloakPod}
    kubectl -n $namespace wait --for=condition=Ready=true pod/${keycloakPod}

    timePodScheduled=$(kubectl -n $namespace  get pods/${keycloakPod} -o jsonpath='{.status.conditions[?(@.type=="PodScheduled")].lastTransitionTime}')
    timeInitialized=$(kubectl -n $namespace  get pods/${keycloakPod} -o jsonpath='{.status.conditions[?(@.type=="Initialized")].lastTransitionTime}')
    timeContainersReady=$(kubectl -n $namespace  get pods/${keycloakPod} -o jsonpath='{.status.conditions[?(@.type=="ContainersReady")].lastTransitionTime}')
    timeReady=$(kubectl -n $namespace  get pods/${keycloakPod} -o jsonpath='{.status.conditions[?(@.type=="Ready")].lastTransitionTime}')

    if [ -z "$timePodScheduled" ]; then exit 1; fi
    if [ -z "$timeInitialized" ]; then exit 1; fi
    if [ -z "$timeContainersReady" ]; then exit 1; fi
    if [ -z "$timeReady" ]; then exit 1; fi

    podInitializationTime=$(( $( date -d "$timeInitialized" +%s ) - $( date -d "$timePodScheduled" +%s ) ))
    containersRedyingTime=$(( $( date -d "$timeContainersReady" +%s ) - $( date -d "$timeInitialized" +%s ) ))
    podReadyingTime=$(( $( date -d "$timeReady" +%s ) - $( date -d "$timeContainersReady" +%s ) ))

    # Keycloak server log timings
    keycloakAugmentationMillis=$(kubectl -n $namespace logs $keycloakPod | grep 'io.quarkus.deployment.QuarkusAugmentor' | grep -oP 'Quarkus augmentation completed in \K[0-9]+' | tail -n 1)
    keycloakStartedInSeconds=$(kubectl -n $namespace logs $keycloakPod | grep 'io.quarkus' | grep Keycloak | grep -oP 'started in \K[0-9\.]+' | tail -n 1)
    if [ -z "$keycloakStartedInSeconds" ]; then
      keycloakStartedInMillis=""
    else
      keycloakStartedInMillis=$(echo "scale=0; ($keycloakStartedInSeconds * 1000)/1" | bc)
    fi

    if [ ! -f "${csvFile}" ]; then
      echo "Namespace,Pod,Pod UID,Pod initialization time (s),Containers readying-time (s),Pod readying-time (s),Keycloak server startup time (ms),Keycloak server augmentation time (ms)" > "${csvFile}"
    fi
    echo "${namespace},${keycloakPod},${podUID},${podInitializationTime},${containersRedyingTime},${podReadyingTime},${keycloakStartedInMillis},${keycloakAugmentationMillis}" >> "${csvFile}"

  fi

  echo
done
#!/bin/bash
#
# This script records memory usage for Keycloak pods by collecting their cgroups information.
# 
# Usage: `keycloak-pod-memory-usage.sh [MEASUREMENT_TIME] [TIMEOUT]`
# 
# The script will continuously record memory usage of all Keycloak pods until 
# `measurementTime` seconds after initialization.
#
# Additionally `postInitDelay` can be set to indicate how long after pod initialization 
# we should wait before taking measurements. This is done to prevent failing 
# container connections shorthly after pod initialization.
#
# The recording will stop after `timeout` seconds, in case some of the pods never reach 
# the intended `measurementTime`.
#
# `measurementTime` parameter defaults to 120 seconds and may be overriden via $1
# `timeout` parameter defaults to 300 seconds and may be overriden via $2
# `postInitDelay` parameter defaults to 5 seconds and may be overriden via env variable
#

set -e

namespace="keycloak"
keycloakResource="keycloak/keycloak"
csvFile="keycloak-pod-memory-usage.csv"

postInitDelay=${postInitDelay:-5}
measurementTime=${1:-120}
timeout=${2:-300}

remainingMeasurementTime=$measurementTime
t0=$(date +%s)
while [ $remainingMeasurementTime -gt 0 ]; do
  remainingMeasurementTime=0

  for keycloakPod in $(kubectl -n $namespace get pods -o name | grep -oP "keycloak-[0-9]+"); do 
    echo "Record memory usage for pod: '$keycloakPod'"
    podRemainingMeasurementTime=$measurementTime
    if ! kubectl -n ${namespace} get pods/${keycloakPod} | grep -i Terminating; then
      if [ "$(kubectl -n ${namespace} get pods/${keycloakPod} -o jsonpath='{.status.conditions[?(@.type=="Initialized")].status}' | tr '[:upper:]' '[:lower:]')" == "true" ]; then
        timeInitialized=$(kubectl -n $namespace  get pods/${keycloakPod} -o jsonpath='{.status.conditions[?(@.type=="Initialized")].lastTransitionTime}')
        timeSinceInitialized=$(( $( date +%s ) - $( date -d "$timeInitialized" +%s ) ))
        podRemainingMeasurementTime=$(( $measurementTime - $timeSinceInitialized ))
        if [ ${podRemainingMeasurementTime} -ge 0 ]; then
          if [ ${timeSinceInitialized} -ge ${postInitDelay} ]; then
            podUID=$(kubectl -n $namespace get pods/${keycloakPod} -o jsonpath='{.metadata.uid}')
            memoryUsageInBytes=$(kubectl -n ${namespace} exec ${keycloakPod} -- cat /sys/fs/cgroup/memory/memory.usage_in_bytes)
            if [ ! -f "${csvFile}" ]; then
              echo "Time since pod initialized (s),Namespace,Pod,Pod UID,Memory usage (B)" > "${csvFile}"
            fi
            echo "${timeSinceInitialized},${namespace},${keycloakPod},${podUID},${memoryUsageInBytes}" >> "${csvFile}"
          else
            echo "Post-init delay for pod '${keycloakPod}' not elapsed yet. Skipping."
          fi
        else
          podRemainingMeasurementTime=0
          echo "Measurement time for pod '${keycloakPod}' elapsed. Skipping."
        fi
      else
        echo "Pod '${keycloakPod}' not initialized yet. Skipping."
      fi
    else
      echo "Pod '${keycloakPod}' is terminating. Skipping."
    fi
    if [ $podRemainingMeasurementTime -gt $remainingMeasurementTime ]; then 
      remainingMeasurementTime=$podRemainingMeasurementTime
    fi
  done
  echo "-----" 
  echo "Remaining measurement time: $remainingMeasurementTime s"
  echo "-----" 

  if [ $(( $(date +%s) - $t0 )) -gt $timeout ]; then
    echo "Measurement exceeded the maximum time of $timeout seconds. Stopping the recording."
    break
  fi
  sleep 1

done

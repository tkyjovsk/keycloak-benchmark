#!/usr/bin/env bash

set -e
set -o pipefail

if [[ "$RUNNER_DEBUG" == "1" ]]; then
  set -x
fi

### DATASET PROVIDER - KEYCLOAK REST API SERVICE ###

set_environment_variables () {
  ACTION="help"
  REALM_COUNT="1"
  REALM_NAME="realm-0"
  CLIENTS_COUNT="100"
  USERS_COUNT="100"
  EVENTS_COUNT="100"
  SESSIONS_COUNT="100"
  if ( minikube version &>/dev/null ); then
    DATASET_PROVIDER_URI="https://keycloak-keycloak.$(minikube ip || echo 'unknown').nip.io/realms/master/dataset"
  fi
  REALM_PREFIX="realm"
  STATUS_TIMEOUT="120"
  CREATE_TIMEOUT="3600"
  THREADS="-1"

  while getopts ":a:r:n:c:u:e:o:g:i:p:l:t:C:T:" OPT
  do
    case $OPT in
      a)
        ACTION=$OPTARG
        ;;
      r)
        REALM_COUNT=$OPTARG
        ;;
      n)
        REALM_NAME=$OPTARG
        ;;
      c)
        CLIENTS_COUNT=$OPTARG
        ;;
      u)
        USERS_COUNT=$OPTARG
        ;;
      e)
        EVENTS_COUNT=$OPTARG
        ;;
      o)
        SESSIONS_COUNT=$OPTARG
        ;;
      g)
        HASH_ALGORITHM=$OPTARG
        ;;
      i)
        HASH_ITERATIONS=$OPTARG
        ;;
      p)
        REALM_PREFIX=$OPTARG
        ;;
      l)
        DATASET_PROVIDER_URI=$OPTARG
        ;;
      t)
        STATUS_TIMEOUT=$OPTARG
        ;;
      C)
        CREATE_TIMEOUT=$OPTARG
        ;;
      T)
        THREADS=$OPTARG
        ;;
      ?)
        echo "Invalid option: $OPT, read the usage carefully -> "
        help
        exit 1
    esac
  done
}

help () {
  echo "Dataset import to the local minikube Keycloak application - usage:"
  echo "1) create realms with clients, users - run -a (action) with or without other arguments: -a create-realms -r 10 -c 100 -u 100 -l 'https://keycloak.url.com'"
  echo "2) create clients in specific realm: -a create-clients -c 100 -n realm-0 -l 'https://keycloak.url.com'"
  echo "3) create users in specific realm: -a create-users -u 100 -n realm-0 -l 'https://keycloak.url.com'"
  echo "4) create events in specific realm: -a create-events -e 100 -n realm-0 -l 'https://keycloak.url.com'"
  echo "5) create offline sessions in specific realm: -a create-offline-sessions -o 100 -n realm-0' -l 'https://keycloak.url.com'"
  echo "6) delete specific realms with prefix -a delete-realms -p realm -l 'https://keycloak.url.com'"
  echo "7) dataset provider status -a status 'https://keycloak.url.com'"
  echo "8) dataset provider status check of last completed job -a status-completed -t 10 -l 'https://keycloak.url.com'"
  echo "9) dataset provider clear status of last completed job -a clear-status-completed -l 'https://keycloak.url.com'"
  echo "10) dataset import script usage -a help"
}

dataset_provider () {
  if [[ ! $1 =~ "status" ]]; then
    for i in {0..10}; do
      status=$(dataset_provider status)
      if [[ $(echo "$status" | grep "No task in progress") ]]; then
        break
      elif [[ $(echo "$status" | grep "Realm does not exist") ]]; then
        echo "Realm master does not exist, please rebuild your Keycloak application from scratch."
        exit 1
      elif [[ $(echo "$status" | grep "unknown_error") ]]; then
        echo "Unknown error occurred, please check your Keycloak instance for more info."
        exit 1
      elif [[ $i -eq 10 ]]; then
        echo "Keycloak dataset provider is busy, please try it again later."
        exit 1
      else
        echo "Waiting..."
        sleep 3s
      fi
    done
  fi
  curl -ks $2 "${DATASET_PROVIDER_URI}/$1"
  echo ""
}

main () {
  set_environment_variables $@

  echo "Action: [$ACTION] "
  case "$ACTION" in
    create-realms)
      if [ -z "$HASH_ALGORITHM" ];  then HA_PARAM=""; HASH_ALGORITHM="default";  else HA_PARAM="&password-hash-algorithm=$HASH_ALGORITHM"; fi
      if [ -z "$HASH_ITERATIONS" ]; then HI_PARAM=""; HASH_ITERATIONS="default"; else HI_PARAM="&password-hash-iterations=$HASH_ITERATIONS"; fi
      echo "Creating $REALM_COUNT realms with $CLIENTS_COUNT clients and $USERS_COUNT users with $HASH_ITERATIONS password-hashing iterations using the $HASH_ALGORITHM algorithm."
      dataset_provider "create-realms?count=$REALM_COUNT&clients-per-realm=$CLIENTS_COUNT&users-per-realm=$USERS_COUNT$HI_PARAM$HA_PARAM"
      exit 0
      ;;
    create-clients)
      echo "Creating $CLIENTS_COUNT clients in realm $REALM_NAME"
      dataset_provider "create-clients?count=$CLIENTS_COUNT&realm-name=$REALM_NAME"
      exit 0
      ;;
    create-users)
      echo "Creating $USERS_COUNT users in realm $REALM_NAME"
      dataset_provider "create-users?count=$USERS_COUNT&realm-name=$REALM_NAME"
      exit 0
      ;;
    create-events)
      echo "Creating $EVENTS_COUNT events in realm $REALM_NAME"
      dataset_provider "create-events?count=$EVENTS_COUNT&realm-name=$REALM_NAME"
      exit 0
      ;;
    create-offline-sessions)
      echo "Creating $SESSIONS_COUNT offline sessions in realm $REALM_NAME"
      dataset_provider "create-offline-sessions?count=$SESSIONS_COUNT&realm-name=$REALM_NAME"
      exit 0
      ;;
    delete-realms)
      echo "Deleting realms with prefix $REALM_PREFIX"
      dataset_provider "remove-realms?remove-all=true&realm-prefix=$REALM_PREFIX"
      exit 0
      ;;
    status)
      dataset_provider status
      exit 0
      ;;
    status-completed)
      echo "Dataset provider status of the last completed task"
      t=0
      RESPONSE=""
      until [[ $(echo $RESPONSE | grep '"success":"true"') ]]; do
        if [[ $t -gt $STATUS_TIMEOUT ]]; then
          echo "Status Polling timeout ${STATUS_TIMEOUT}s exceeded ";
          echo $RESPONSE
          dataset_provider status
          exit 1
          break
        fi
        RESPONSE=$(dataset_provider "status-completed")
        sleep 1 && ((t=t+1))
        echo "Polling...${t}s"
      done
      echo $RESPONSE
      exit 0
      ;;
    clear-status-completed)
      echo "Dataset provider clears the status of the last completed task"
      dataset_provider "status-completed" "-X DELETE"
      exit 0
      ;;
    help)
      help
      exit 0
      ;;
    *)
      echo "Action doesn't exist: $ACTION, read the usage carefully -> "
      help
      exit 1
      ;;
  esac
}

## Start of script
main "$@"

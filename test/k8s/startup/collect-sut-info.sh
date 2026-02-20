#!/usr/bin/env bash
set -e

export timestamp="${timestamp:-$(date -uIseconds)}"
export NAMESPACE="${NAMESPACE:-$(whoami)-keycloak}"

sutInfoDir="data/${timestamp}/system-under-test-info"

echo "Collecting information about the system under test."

mkdir -p "${sutInfoDir}"

echo "- keycloak operator image"
operatorPod=$(kubectl -n ${NAMESPACE} get pods -oname | grep "\(keycloak\|rhbk\)-operator" | head -1 | xargs basename)
if [ ! -z "$operatorPod" ]; then
  kubectl -n ${NAMESPACE} get pods $operatorPod -ojson | jq -r .spec.containers[0].image > "${sutInfoDir}/operator-image"
fi

echo "- keycloak CRD spec"
kubectl -n ${NAMESPACE} get keycloaks keycloak -oyaml | yq .spec > "${sutInfoDir}/keycloak-crd-spec.yaml"

for pod in $(kubectl -n ${NAMESPACE} get pods -oname | grep "keycloak-[0-9]*"); do
  keycloakPod=$(basename $pod)
  echo "- pods/$keycloakPod"
  mkdir -p "${sutInfoDir}/$keycloakPod"

  kubectl -n ${NAMESPACE} get pods/$keycloakPod -o yaml > pod.yaml 
  cat pod.yaml | yq ".spec.containers[0].env" > "${sutInfoDir}/$keycloakPod/env.yaml"

  JAVA_OPTS_APPEND=$(cat "${sutInfoDir}/$keycloakPod/env.yaml" | yq 'map(select(.name == "JAVA_OPTS_APPEND")) | .[] | .value')

  cat <<EOF > "${sutInfoDir}/$keycloakPod/parameters.yaml"
image: $(cat pod.yaml | yq ".status.containerStatuses[0].image")
imageID: $(cat pod.yaml | yq ".status.containerStatuses[0].imageID")
cpuLimits: $(cat pod.yaml | yq ".spec.containers[0].resources.limits.cpu")
memoryLimits: $(cat pod.yaml | yq ".spec.containers[0].resources.limits.memory")
heapInit: $(echo "$JAVA_OPTS_APPEND" | grep -oP '\-Xms\K\w+')
heapMax: $(echo "$JAVA_OPTS_APPEND" | grep -oP '\-Xmx\K\w+')
metaspaceInit: $(echo "$JAVA_OPTS_APPEND" | grep -oP '\-XX:MetaspaceSize=\K\w+')
metaspaceMax: $(echo "$JAVA_OPTS_APPEND" | grep -oP '\-XX:MaxMetaspaceSize=\K\w+')
EOF
  rm pod.yaml

  kubectl -n ${NAMESPACE} exec $keycloakPod -- cat /proc/cpuinfo | \
    sed "s/\s*:/:/g" | \
    sed "s/\s\([^[:space:]]*\):/_\1:/g" | \
    sed "/^processor/! s/\(.*\)/  \1/g" | \
    sed "s/^processor/- processor/g" \
  > "${sutInfoDir}/$keycloakPod/cpuinfo.yaml"
done

echo "- Kubernetes nodes"

for node in $(kubectl -n ${NAMESPACE} get nodes -o name); do 
  mkdir -p "${sutInfoDir}/${node}"
  kubectl -n ${NAMESPACE} get ${node} -o yaml > "${sutInfoDir}/node.yaml"
  cat "${sutInfoDir}/node.yaml" | yq ".status.nodeInfo" > "${sutInfoDir}/${node}/nodeInfo.yaml"
  cat "${sutInfoDir}/node.yaml" | yq ".status.capacity" > "${sutInfoDir}/${node}/capacity.yaml"
  cat "${sutInfoDir}/node.yaml" | yq ".status.allocatable" > "${sutInfoDir}/${node}/allocatable.yaml"
  cat "${sutInfoDir}/node.yaml" | yq ".status.conditions" > "${sutInfoDir}/${node}/conditions.yaml"
  rm "${sutInfoDir}/node.yaml"
done

echo "Information collected."

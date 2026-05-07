#!/bin/bash -e

dir=${1:-.}

files=$(find $dir -name result*.json)

SLO=0.9

for f in $files; do

  content=$(cat "$f")
  name=$(echo "$content" | jq -r .name)
  computeMachineType=$(echo "$content" | jq -r .computeMachineType)
  context=$(echo "$content" | jq -r --sort-keys .context)
  contextHash=$(echo "$context" | md5sum | cut -c -7)
  start=$(echo "$content" | jq -r .start)
  end=$(echo "$content" | jq -r .end)

  sessions=$(echo "$content" | jq -r .memoryUsageTest.activeSessionsPer500MbPerPod)
  sessionsStats=$(echo "$content" | jq -r '.memoryUsageTest.statistics')
  if [[ "$sessionsStats" != "null" ]]; then
    sessionsStatsAll=$(echo "$sessionsStats" | jq -r '.[] | select(.name=="All Requests")')
    sessionsTotal=$(echo "$sessionsStatsAll" | jq -r '.numberOfRequests.total' )
    sessionsOk=$(echo "$sessionsStatsAll" | jq -r '.numberOfRequests.ok' )
    sessionsOkPct=$(echo "$sessionsOk / $sessionsTotal" | bc -l)
  fi

  logins=$(echo "$content" | jq -r .cpuUsageForLoginsTest.userLoginsPerSecPer1vCpuPerPod)
  loginsStats=$(echo "$content" | jq -r '.cpuUsageForLoginsTest.statistics')
  if [[ "$loginsStats" != "null" ]]; then
    loginsStatsAll=$(echo "$loginsStats" | jq -r '.[] | select(.name=="All Requests")')
    loginsTotal=$(echo "$loginsStatsAll" | jq -r '.numberOfRequests.total' )
    loginsOk=$(echo "$loginsStatsAll" | jq -r '.numberOfRequests.ok' )
    loginsOkPct=$(echo "$loginsOk / $loginsTotal" | bc -l)
  fi

  credentialGrants=$(echo "$content" | jq -r .cpuUsageForCredentialGrantsTest.credentialGrantsPerSecPer1vCpu)
  credentialGrantsStats=$(echo "$content" | jq -r '.cpuUsageForCredentialGrantsTest.statistics')
  if [[ "$credentialGrantsStats" != "null" ]]; then
    credentialGrantsStatsAll=$(echo "$credentialGrantsStats" | jq -r '.[] | select(.name=="All Requests")')
    credentialGrantsTotal=$(echo "$credentialGrantsStatsAll" | jq -r '.numberOfRequests.total' )
    credentialGrantsOk=$(echo "$credentialGrantsStatsAll" | jq -r '.numberOfRequests.ok' )
    credentialGrantsOkPct=$(echo "$credentialGrantsOk / $credentialGrantsTotal" | bc -l)
  fi

  if [[ "$computeMachineType" == "null" ]]; then computeMachineType="unknown-machine-type"; fi
  if [ -z "$contextHash" ]; then echo "empty context hash"; exit 1; fi
  resultsDir="$name/$computeMachineType/$contextHash"
  mkdir -p "$resultsDir"; echo "$context" > "$resultsDir/context.json"
  csv="$resultsDir/results.csv"

  if [ ! -f "$csv" ]; then
    echo "start,sessions,logins,credentialGrants,sessions ok %,logins ok %,credentialGrants ok %" > "$csv"
  fi
  echo "$start,$sessions,$logins,$credentialGrants,$sessionsOkPct,$loginsOkPct,$credentialGrantsOkPct" >> "$csv"

  mkdir -p "$resultsDir/results"
  cp "$f" "$resultsDir/results/"

done

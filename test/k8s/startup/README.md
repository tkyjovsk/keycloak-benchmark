# Keycloak startup-testing scripts for Kubernetes

A set of scripts for measuring *startup times* of Keycloak pods, and optionally their *memory consumption* at specified times after start.

The scripts use `kubectl` to scale the Keycloak cluster via editing CRD spec, and to collect results.


## Prerequisities
- Keycloak installation running in Kubernetes cluster. (Set the `NAMESPACE` variable otherwise it defaults to `$(whoami)-keycloak`.)
- `kubectl` logged in
- `yq` - YAML-based `jq` alternative
- `awk` for computing statistics.


## Usage

The main entrypoint is `scale-and-measure-loop.sh`.

```
./scale-and-measure-loop.sh [SCALE] [MEASUREMENT_COUNT] [MEMORY_MEASUREMENT_TIMES]
```

## Results

Test results are then stored in `./data/$TIMESTAMP/keycloak-N/` folder:

- `startup-times.csv`
- `memory-usage-cgroups.csv`
- `memory-usage-rss.csv`

Computed stats:

- `startup-times-statistics.csv`
- `memory-usage-cgroups-statistics.csv`
- `memory-usage-rss-statistics.csv`

Additionally some information about the Keycloak cluster and the Kubernetes environment is recorded.


## Examples

### 1 pod, 3 measurements of startup times

```
./scale-and-measure-loop.sh
```

is the same as:

```
./scale-and-measure-loop.sh 1 3
```

### 3 pods, 10 measurements of startup times

```
./scale-and-measure-loop.sh 3 10
```

### 3 pods, 10 measurements of startup times, and of memory usage at 30, 60, 90, 120 seconds after start

```
./scale-and-measure-loop.sh 3 10 "30 60 90 120"
```


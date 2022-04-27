#!/usr/bin/env bash

export KUBECONFIG="${SCRIPT_DIR}/kubeconfig"

declare -r NUM_REMOTE_CLUSTERS=${NUM_REMOTE_CLUSTERS:-2}

declare -a REMOTE_CLUSTER_NAMES=()
for i in $(seq "${NUM_REMOTE_CLUSTERS}"); do
  REMOTE_CLUSTER_NAMES+=("kuma-remote-${i}")
done

readonly REMOTE_CLUSTER_NAMES

declare -r GLOBAL_CLUSTER_NAME="kuma-global"

# shellcheck disable=SC2034 # Used in other scripts.
declare -ra ALL_CLUSTER_NAMES=("${GLOBAL_CLUSTER_NAME}" "${REMOTE_CLUSTER_NAMES[@]}")

declare -r KUMA_VERSION="${KUMA_VERSION:-1.6.0}"

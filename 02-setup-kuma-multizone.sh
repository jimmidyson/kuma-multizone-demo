#!/usr/bin/env bash
# Copyright 2022 Jimmi Dyson
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
IFS=$'\n\t'

if [ -z ${SCRIPT_DIR+x} ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  readonly SCRIPT_DIR
fi

source "${SCRIPT_DIR}/lib/functions.sh"
source "${SCRIPT_DIR}/lib/variables.sh"

install_kuma_global

for c in "${ALL_CLUSTER_NAMES[@]}"; do
  install_kuma_zone "${c}"
done

export -f global_vcluster_connect
export GLOBAL_CLUSTER_NAME
timeout --verbose 120s bash -ec " \
  until [ \$(global_vcluster_connect kubectl get zones --no-headers | wc -l) -eq ${#ALL_CLUSTER_NAMES[@]} ]; do \
    sleep 1; \
  done"
export -fn global_vcluster_connect
export -n GLOBAL_CLUSTER_NAME

global_vcluster_connect kubectl get zones

#!/usr/bin/env bash
# Copyright 2022 Jimmi Dyson
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
IFS=$'\n\t'

if [ -z ${SCRIPT_DIR+x} ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  readonly SCRIPT_DIR
fi

# shellcheck source=./lib/functions.sh
source "${SCRIPT_DIR}/lib/functions.sh"
# shellcheck source=./lib/variables.sh
source "${SCRIPT_DIR}/lib/variables.sh"

for c in "${ALL_CLUSTER_NAMES[@]}"; do
  ensure_kind_cluster "${c}"
done

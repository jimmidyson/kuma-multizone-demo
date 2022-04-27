#!/usr/bin/env bash
# Copyright 2022 Jimmi Dyson
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
IFS=$'\n\t'

if [ -z ${SCRIPT_DIR+x} ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  readonly SCRIPT_DIR
fi

source "${SCRIPT_DIR}/lib/variables.sh"

pushd "${SCRIPT_DIR}" &>/dev/null

cut -f1 -d' ' .tool-versions | sort | xargs -I{} bash -ec '( \
  (asdf plugin list 2>/dev/null | grep -Eo "^{}$" &>/dev/null) || \
  asdf plugin add {}) && asdf install {}'

mkdir -p bin

if [ "$(kumactl version -a 2>/dev/null | grep -E '^Version:' | grep -Eo '[0-9].*$')" == "${KUMA_VERSION}" ]; then
  echo "kumactl ${KUMA_VERSION} is already installed"
else
  echo "Downloading kumactl from https://download.konghq.com/mesh-alpine/kuma-${KUMA_VERSION}-centos-amd64.tar.gz"
  curl -fsSL https://download.konghq.com/mesh-alpine/kuma-"${KUMA_VERSION}"-centos-amd64.tar.gz |
    tar xz --strip-components=3 -C bin --wildcards -- '*/kumactl'
fi

popd &>/dev/null

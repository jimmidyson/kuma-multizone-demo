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

cat <<'EOF' | global_vcluster_connect kubectl apply --server-side -f -
apiVersion: kuma.io/v1alpha1
kind: Mesh
metadata:
  name: multicluster
spec:
  networking:
    outbound:
      passthrough: false
  mtls:
    enabledBackend: multicluster-ca
    backends:
      - name: multicluster-ca
        type: builtin
        dpCert:
          rotation:
            expiration: 1d
        conf:
          caCert:
            RSAbits: 4096
            expiration: 10y
  constraints:
    dataplaneProxy:
      requirements:
      - tags:
          k8s.kuma.io/namespace: multicluster-demo
      - tags:
          kuma.io/zone: kuma-global
          k8s.kuma.io/namespace: multicluster-demo-cp
EOF

global_vcluster_connect kubectl delete trafficpermission allow-all-multicluster --ignore-not-found

cat <<'EOF' | global_vcluster_connect kubectl apply --server-side -f -
apiVersion: kuma.io/v1alpha1
kind: TrafficPermission
mesh: multicluster
metadata:
  name: allow-multicluster-traffic
spec:
  sources:
    - match:
        kuma.io/zone: kuma-global
        k8s.kuma.io/namespace: multicluster-demo-cp
  destinations:
    - match:
        federation.example.com/apiserver: "true"
EOF

for CLUSTER_NAME in "${ALL_CLUSTER_NAMES[@]}"; do
  kubectl kustomize "${SCRIPT_DIR}/manifests/overlays/${CLUSTER_NAME}" |
    kubectl --context kind-"${CLUSTER_NAME}" apply -f - --server-side
done

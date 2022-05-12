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
  routing:
    zoneEgress: true
    localityAwareLoadBalancing: true
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
        kuma.io/service: '*'
EOF

for CLUSTER_NAME in "${ALL_CLUSTER_NAMES[@]}"; do
  kubectl create namespace --dry-run=client -oyaml multicluster-demo |
    kubectl --context kind-"${CLUSTER_NAME}" apply --server-side -f -

  CLUSTER_KUBERNETES_API_ENDPOINTS="$(kubectl --context kind-"${CLUSTER_NAME}" \
    get endpoints -n default -ojson kubernetes |
    gojq -rc '.subsets')"

  cat <<EOF | kubectl --context kind-"${CLUSTER_NAME}" apply -f - --server-side
---
apiVersion: v1
kind: Service
metadata:
  name: kubernetes-api-${CLUSTER_NAME}
  namespace: multicluster-demo
spec:
  type: ClusterIP
  ports:
  - name: https
    port: 443
    protocol: TCP
    targetPort: 6443
---
apiVersion: v1
kind: Endpoints
metadata:
  name: kubernetes-api-${CLUSTER_NAME}
  namespace: multicluster-demo
subsets: ${CLUSTER_KUBERNETES_API_ENDPOINTS}
EOF

  cat <<EOF | global_vcluster_connect kubectl apply --server-side -f -
apiVersion: kuma.io/v1alpha1
kind: ExternalService
mesh: multicluster
metadata:
  name: kubernetes-api.${CLUSTER_NAME}
spec:
  tags:
    kuma.io/service: kubernetes-api.${CLUSTER_NAME}
    kuma.io/zone: ${CLUSTER_NAME}
    kuma.io/protocol: tcp
  networking:
    address: kubernetes-api-${CLUSTER_NAME}.multicluster-demo.svc:443
EOF
done

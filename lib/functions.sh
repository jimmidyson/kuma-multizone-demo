#!/usr/bin/env bash
# Copyright 2022 Jimmi Dyson
# SPDX-License-Identifier: Apache-2.0

function ensure_kind_cluster() {
  local -r CLUSTER_NAME="${1}"
  (kind get clusters 2>/dev/null | grep -Eo "^${CLUSTER_NAME}$" &>/dev/null) ||
    cat <<EOF | kind create cluster --name="${CLUSTER_NAME}" --config -
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true # disable kindnet
  podSubnet: 192.168.0.0/16 # set to Calico's default subnet
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.configs."registry-1.docker.io".auth]
    username = "${DOCKER_USERNAME:-}"
    password = "${DOCKER_PASSWORD:-}"
    auth = ""
    identitytoken = ""
kubeadmConfigPatches:
- |
  apiVersion: kubelet.config.k8s.io/v1beta1
  kind: KubeletConfiguration
  nodeStatusMaxImages: -1
EOF

  (helm repo list | cut -d' ' -f1 | grep -Eo '^projectcalico$' &>/dev/null) ||
    helm repo add projectcalico https://projectcalico.docs.tigera.io/charts

  helm upgrade --install --kube-context kind-"${CLUSTER_NAME}" calico projectcalico/tigera-operator

  local -r CONTAINER_IP="$(
    docker inspect \
      -f '"{{range .NetworkSettings.Networks}}{{.IPAddress}}{{break}}{{end}}"' \
      "${CLUSTER_NAME}-control-plane"
  )"
  local -r SUBNET_PREFIX="$(echo "${CONTAINER_IP}" | gojq -r '. | scan("^\\d+\\.\\d+")')"
  local CLUSTER_INDEX=0
  for i in "${!ALL_CLUSTER_NAMES[@]}"; do
    if [[ ${ALL_CLUSTER_NAMES[$i]} == "${CLUSTER_NAME}" ]]; then
      CLUSTER_INDEX=${i}
      break
    fi
  done
  local -r FIRST_IP="$((180 + CLUSTER_INDEX * 20))"
  local -r METALLB_ADDRESS_RANGE="${SUBNET_PREFIX}.255.${FIRST_IP}-${SUBNET_PREFIX}.255.$((FIRST_IP + 19))"

  (helm repo list | cut -d' ' -f1 | grep -Eo '^metallb$' &>/dev/null) ||
    helm repo add metallb https://metallb.github.io/metallb

  cat <<EOF | helm upgrade --install --kube-context kind-"${CLUSTER_NAME}" \
    --namespace metallb-system --create-namespace metallb metallb/metallb -f -
configInline:
  address-pools:
   - name: default
     protocol: layer2
     addresses:
     - "${METALLB_ADDRESS_RANGE}"
speaker:
  frr:
    enabled: true
EOF
}

function delete_kind_cluster() {
  local -r CLUSTER_NAME="${1}"
  if kind get clusters 2>/dev/null | grep -Eo "^${CLUSTER_NAME}$" &>/dev/null; then
    kind delete cluster --name "${CLUSTER_NAME}"
  fi
  rm -f "${KUBECONFIG}"
}

function install_kuma_global() {
  kubectl --context kind-"${GLOBAL_CLUSTER_NAME}" get ns kuma-global-system &>/dev/null ||
    kubectl --context kind-"${GLOBAL_CLUSTER_NAME}" create ns kuma-global-system

  (vcluster --context kind-kuma-global list -n kuma-global-system --output json |
    gojq -e '.[].Name == "kuma-global"' &>/dev/null) ||
    vcluster --context kind-"${GLOBAL_CLUSTER_NAME}" create kuma-global -n kuma-global-system --distro k8s

  (helm repo list | cut -d' ' -f1 | grep -Eo '^kuma$' &>/dev/null) ||
    helm repo add kuma https://kumahq.github.io/charts

  global_vcluster_connect helm upgrade --install --wait kuma-global \
    --namespace kuma-global-system --create-namespace \
    --set controlPlane.mode=global --set nameOverride=kuma-global \
    kuma/kuma
}

function install_kuma_zone() {
  local -r CLUSTER_NAME="${1}"

  local -r KDS_GLOBAL_IP="$(
    global_vcluster_connect kubectl get services -n kuma-global-system \
      kuma-global-global-zone-sync -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
  )"

  (helm repo list | cut -d' ' -f1 | grep -Eo '^kuma$' &>/dev/null) ||
    helm repo add kuma https://kumahq.github.io/charts

  helm upgrade --install kuma \
    --kube-context kind-"${CLUSTER_NAME}" --namespace kuma-system --create-namespace \
    --set controlPlane.mode=zone --set controlPlane.zone="${CLUSTER_NAME}" --set ingress.enabled=true \
    --set controlPlane.kdsGlobalAddress=grpcs://"${KDS_GLOBAL_IP}":5685 \
    --set cni.enabled=true \
    --set cni.chained=true \
    --set cni.netDir="/etc/cni/net.d" \
    --set cni.binDir=/opt/cni/bin \
    --set cni.confName=10-calico.conflist \
    kuma/kuma
}

function global_vcluster_connect() {
  vcluster --context kind-"${GLOBAL_CLUSTER_NAME}" connect kuma-global -n kuma-global-system -- \
    "${@}"
}

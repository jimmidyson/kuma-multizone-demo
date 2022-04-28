<!--
 Copyright 2022 Jimmi Dyson
 SPDX-License-Identifier: Apache-2.0
-->

# Kuma Multi-zone Demo

This repository contains a set of scripts to locally run [Kuma](https://kuma.io) multi-zone
deployment.

The scripts will create up multiple [`KinD`](https://kind.sigs.k8s.io/) clusters, configured to use
[`Calico`](https://projectcalico.docs.tigera.io/) in order to use
[Kuma CNI](https://kuma.io/docs/1.6.x/networking/cni/).

To work around Kuma [not supporting running global CP and zone CP on the same
cluster](https://github.com/kumahq/kuma/issues/1496), we set up a virtual cluster via
[`vcluster`](https://www.vcluster.com/) and install the Kuma global CP into this virtual cluster
(thanks to [@johnharris85](https://github.com/johnharris85) for the [suggestion on Kuma's community
Slack channel](https://kuma-mesh.slack.com/archives/CN2GN4HE1/p1650980477760209?thread_ts=1650964365.743859&cid=CN2GN4HE1)).

## Pre-requisites

The scripts require a number of tools to be available. The simplest way to install all required
tools is to use [`asdf`](https://asdf-vm.com/guide/getting-started.html). If you have `asdf`
installed, then you can just run `./00-install-tools.sh` and necessary tools will be installed.

If you prefer not to use `asdf`, then take a look at [`.tool-versions`](.tool-versions) to see the
required tools and versions. In additions, to those you will also need
[`kumactl`](https://kuma.io/docs/1.6.x/installation/kubernetes/#_1-download-kumactl) (also installed
via `./00-install-tools.sh` btw).

### Docker Hub rate limiting

When running the demo, you may hit [Docker Hub pull rate limiting](https://docs.docker.com/docker-hub/download-rate-limit/).
If you have a paid Docker Hub account, you can increase pull rate limits by authenticating to Docker
Hub. Before creating the KinD clusters below, export the following environment vaiables:

```bash
export DOCKER_USERNAME=<username></username> DOCKER_PASSWORD=<password>
```

These credentials will then be used by the KinD clusters when pulling images.

## Running

Once you've got all the tools set up, you can then create the required kind clusters:
`./01-create-clusters.sh`.

Then you can set up the Kuma multi-zone deployment: `./02-setup-kuma-multizone.sh`.

## Exploring the multi-zone mesh

As the Kuma global CP is deployed in a virtual cluster, you need to open a connection to the
vcluster to configure policies in the multi-zone mesh.

To open a shell configured appropriately to manage the Kuma global CP, run
`vcluster --context kind-kuma-global connect kuma-global -n kuma-global-system -- bash`. You can
then run `kubectl` or `kumactl` commands against the `vcluster` that hosts the Kuma global CP:

```bash
$ vcluster --context kind-kuma-global connect kuma-global -n kuma-global-system -- bash

$ kubectl get meshes
NAME      AGE
default   150m

$ kubectl get zones
NAME            AGE
kuma-global     150m
kuma-remote-1   150m
kuma-remote-2   149m

$ nohup kubectl port-forward svc/kuma-global-control-plane -n kuma-global-system 5681:5681 &>/dev/null &

$ kumactl get zones
NAME            AGE
kuma-global     2h
kuma-remote-1   2h
kuma-remote-2   2h

$ exit
```

## Cleaning up

Just run `./99-delete-clusters.sh` to delete all clusters.

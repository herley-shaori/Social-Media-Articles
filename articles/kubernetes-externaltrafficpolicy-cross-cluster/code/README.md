# Cross-cluster `externalTrafficPolicy` lab

This Docker-only experiment reproduces a cross-cluster request failure caused
by `externalTrafficPolicy: Local`.

`checkout-client` in Cluster A calls a NodePort exposed by Cluster B. The call
is deliberately sent to Cluster B's control-plane node, while `payment-api` is
scheduled only on Cluster B's worker node.

With `externalTrafficPolicy: Cluster`, kube-proxy may forward that request to
the worker endpoint, so it succeeds. With `externalTrafficPolicy: Local`, it
must use an endpoint local to the receiving node. There is none on the
control-plane node, so the identical call times out.

This is not a Service selector or DNS error. It is the trade-off made when
preserving the original client source IP: the load balancer must only target
nodes that have local, healthy endpoints.

## Prerequisites

- Docker Desktop running
- `kind` and `kubectl` available on `PATH`

No Kubernetes distribution is installed on Windows. Both clusters run as
Docker containers and are removed at the end of the run.

The cluster definitions deliberately pin `kindest/node:v1.32.2`, avoiding a
surprise node-image pull and keeping the experiment on a known local image.

## Run

From this directory:

```powershell
.\run.ps1
```

The script writes its evidence to `results/run-output.txt` and deletes both
kind clusters. Use `-KeepClusters` to inspect them after the test:

```powershell
.\run.ps1 -KeepClusters
```

Clean up retained clusters explicitly:

```powershell
kind delete cluster --name cross-a
kind delete cluster --name cross-b
```

## Topology

```text
Cluster A                                      Cluster B
checkout-client ──> control-plane IP:30080 ──> worker: payment-api
                         no local endpoint
```

The NodePort is a deliberately simple lab transport. In production, the
caller would normally use an internal load balancer, gateway, or service-mesh
endpoint. The requirement is unchanged: when `externalTrafficPolicy: Local`
is used, that frontend must health-check and target only nodes with local
endpoints.

`payment-api.yaml` is the `Cluster` phase and `payment-api-local.yaml` is the
same Service configured for the failing `Local` phase.

# Rethinking Node Autoscaling for Bursty Workloads — Experiment Code

> **Published:** the full article is live at **https://herley.dev** (hosted on
> Cloudflare). This repository holds only the standalone experiment code that
> the article references.

Reproducible, Docker-only harness backing the article *Rethinking Node
Autoscaling for Bursty Workloads*. It provisions a local Kubernetes cluster,
simulates node-boot latency, and measures how a 100-pod burst is served under
reactive autoscaling versus pre-staged headroom.

Everything runs on a laptop with no cloud cost: [KWOK](https://kwok.sigs.k8s.io/)
simulates node and pod lifecycle, and the real Cluster Autoscaler runs with its
KWOK cloud provider.

## Prerequisites

- Docker
- `kind`, `kubectl`, `helm`
- Python 3 with `matplotlib` and `numpy` (for `plot.py`)
- `kwokctl` / KWOK release manifests (the KWOK controller is deployed in-cluster)

## Layout

| Path | Purpose |
|------|---------|
| `kind-cluster.yaml` | Single-node kind cluster definition |
| `kwok/stages-fast.yaml` | Vendored KWOK lifecycle stages |
| `kwok/node-boot-delay.yaml.tmpl` | `node-initialize` override; `__BOOT_DELAY_MS__` sets the simulated boot time |
| `autoscaler/ca-values.yaml` | Helm values for Cluster Autoscaler (KWOK provider) |
| `autoscaler/kwok-provider-config.yaml` | KWOK provider config |
| `autoscaler/kwok-provider-templates.yaml` | Burst node template (born NotReady + not-ready taint) |
| `workload/priorityclasses.yaml` | `burst-app` (high) and `headroom` (negative) priority classes |
| `workload/burst.yaml.tmpl` | Burst Deployment (`__REPLICAS__` pods) |
| `workload/headroom.yaml.tmpl` | Low-priority pause-pod Deployment |
| `run.py` | Drive one arm (reactive/headroom) and collect JSON |
| `run_all.py` | Full matrix: boot-delay sweep + head-to-head |
| `plot.py` | Render the three annotated result figures |
| `test_run.py` | Sanity checks for the timestamp/stat logic |
| `results/` | Raw per-run JSON, run log, and summary |

## Running

1. Create the cluster and deploy KWOK, its stages, the provider ConfigMaps, and
   the Cluster Autoscaler (see the manifests above).
2. `python3 run_all.py` — runs the sweep and the head-to-head, writing one JSON
   per run into `results/`.
3. `python3 plot.py` — renders the figures from `results/`.
4. `python3 test_run.py` — runs the sanity checks.

## Headline result

At a 45s simulated node-boot delay, a 100-pod burst reaches p95 Ready in **51s**
under reactive autoscaling versus **5s** with headroom. Across a 5–90s boot-delay
sweep, reactive p95 tracks boot time one-for-one — the floor is structural.

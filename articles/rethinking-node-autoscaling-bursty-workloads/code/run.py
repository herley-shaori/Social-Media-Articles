#!/usr/bin/env python3
"""Drive one node-autoscaling burst experiment and record the result as JSON.

An "arm" is one experimental condition:

  reactive  fire N burst pods against an empty burst nodegroup; the Cluster
            Autoscaler must provision fresh KWOK nodes that only become Ready
            after the simulated boot delay.

  headroom  first park N low-priority pause pods so the autoscaler warms N
            nodes; then fire the real burst, which preempts the pause pods and
            lands on already-Ready nodes.

Latencies come from Kubernetes-recorded timestamps (pod/node conditions), so
they are measured on the cluster clock, immune to host/cluster skew. The burst
origin t0 is the earliest burst-pod creationTimestamp; every latency is
relative to it.
"""
import argparse
import json
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
CTX = "kind-autoscale-lab"


def kubectl(*args, check=True, capture=True):
    cmd = ["kubectl", "--context", CTX, *args]
    r = subprocess.run(cmd, capture_output=capture, text=True)
    if check and r.returncode != 0:
        sys.stderr.write(r.stderr)
        raise SystemExit(f"kubectl failed: {' '.join(args)}")
    return r.stdout


def apply_stdin(text):
    r = subprocess.run(
        ["kubectl", "--context", CTX, "apply", "-f", "-"],
        input=text, capture_output=True, text=True,
    )
    if r.returncode != 0:
        sys.stderr.write(r.stderr)
        raise SystemExit("kubectl apply failed")


def render(tmpl_path, **subs):
    text = Path(tmpl_path).read_text()
    for k, v in subs.items():
        text = text.replace(k, str(v))
    return text


def parse_ts(s):
    # Kubernetes RFC3339, e.g. 2026-07-17T04:39:16Z
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def cond_time(obj, ctype):
    for c in obj.get("status", {}).get("conditions", []):
        if c.get("type") == ctype and c.get("status") == "True":
            return parse_ts(c["lastTransitionTime"])
    return None


def get_json(*args):
    return json.loads(kubectl(*args, "-o", "json"))


CA_DEPLOY = "ca-kwok-cluster-autoscaler"


def reset():
    """Return the burst nodegroup to zero so the next arm starts clean.

    Deleting the autoscaler's own nodes puts its nodegroup into scale-up
    backoff, which would poison the next run's timing. Restarting the CA
    deployment clears that in-memory backoff so every arm starts identical.
    """
    kubectl("delete", "deploy", "burst", "headroom",
            "--ignore-not-found", "--wait=true", check=False)
    kubectl("delete", "node", "-l", "kwok-nodegroup=burst",
            "--ignore-not-found", "--wait=true", check=False)
    kubectl("-n", "kube-system", "rollout", "restart", f"deploy/{CA_DEPLOY}")
    kubectl("-n", "kube-system", "rollout", "status", f"deploy/{CA_DEPLOY}",
            "--timeout=120s")
    # Give the fresh CA leader time to acquire the lease and its first loop.
    time.sleep(15)


def set_boot_delay(delay_s):
    tmpl = HERE / "kwok" / "node-boot-delay.yaml.tmpl"
    apply_stdin(render(tmpl, __BOOT_DELAY_MS__=int(delay_s * 1000)))


def count_ready_burst_nodes():
    nodes = get_json("get", "nodes", "-l", "kwok-nodegroup=burst")["items"]
    ready = sum(1 for n in nodes if cond_time(n, "Ready") is not None)
    return ready, len(nodes)


def count_running_pods(label):
    pods = get_json("get", "pods", "-l", label)["items"]
    running = sum(1 for p in pods if p.get("status", {}).get("phase") == "Running")
    return running, len(pods)


def wait_pods_ready(label, target, timeout, series=None, t_series0=None):
    """Poll until `target` pods with `label` are Ready, or timeout."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        pods = get_json("get", "pods", "-l", label)["items"]
        ready = sum(1 for p in pods if cond_time(p, "Ready") is not None)
        rn, tn = count_ready_burst_nodes()
        if series is not None:
            series.append({
                "t": round(time.time() - t_series0, 2),
                "ready_pods": ready,
                "ready_nodes": rn,
                "total_nodes": tn,
            })
        if ready >= target:
            return True
        time.sleep(1)
    return False


def collect(arm, boot_delay, replicas, series):
    pods = get_json("get", "pods", "-l", "app=burst")["items"]
    created = [parse_ts(p["metadata"]["creationTimestamp"]) for p in pods]
    t0 = min(created)
    pod_rows = []
    for p in pods:
        ready = cond_time(p, "Ready")
        sched = cond_time(p, "PodScheduled")
        pod_rows.append({
            "name": p["metadata"]["name"],
            "created_s": (parse_ts(p["metadata"]["creationTimestamp"]) - t0).total_seconds(),
            "scheduled_s": (sched - t0).total_seconds() if sched else None,
            "ready_s": (ready - t0).total_seconds() if ready else None,
        })
    nodes = get_json("get", "nodes", "-l", "kwok-nodegroup=burst")["items"]
    node_rows = []
    for n in nodes:
        ready = cond_time(n, "Ready")
        node_rows.append({
            "name": n["metadata"]["name"],
            "created_s": (parse_ts(n["metadata"]["creationTimestamp"]) - t0).total_seconds(),
            "ready_s": (ready - t0).total_seconds() if ready else None,
        })
    return {
        "arm": arm,
        "boot_delay_s": boot_delay,
        "replicas": replicas,
        "t0": t0.isoformat(),
        "pods": pod_rows,
        "nodes": node_rows,
        "series": series,
    }


def run_reactive(replicas, boot_delay, timeout):
    reset()
    set_boot_delay(boot_delay)
    t_series0 = time.time()
    series = []
    apply_stdin(render(HERE / "workload" / "burst.yaml.tmpl", __REPLICAS__=replicas))
    ok = wait_pods_ready("app=burst", replicas, timeout, series, t_series0)
    if not ok:
        print("warning: not all burst pods Ready before timeout", file=sys.stderr)
    return collect("reactive", boot_delay, replicas, series)


def run_headroom(replicas, boot_delay, timeout):
    reset()
    set_boot_delay(boot_delay)
    # Phase 1: park pause pods and wait for the autoscaler to warm the nodes.
    apply_stdin(render(HERE / "workload" / "headroom.yaml.tmpl", __REPLICAS__=replicas))
    if not wait_pods_ready("app=headroom", replicas, timeout):
        print("warning: headroom not fully warm before timeout", file=sys.stderr)
    # Phase 2: release the warm capacity as the burst arrives. Scaling the
    # headroom Deployment to zero deflates the balloon (grace period 0, so the
    # pause pods vanish at once) instead of letting its ReplicaSet refill
    # preempted pods and race the autoscaler for the freed slots. The burst
    # then lands on nodes that are already Ready, skipping node boot entirely.
    t_series0 = time.time()
    series = []
    kubectl("scale", "deploy", "headroom", "--replicas=0")
    apply_stdin(render(HERE / "workload" / "burst.yaml.tmpl", __REPLICAS__=replicas))
    ok = wait_pods_ready("app=burst", replicas, timeout, series, t_series0)
    if not ok:
        print("warning: not all burst pods Ready before timeout", file=sys.stderr)
    return collect("headroom", boot_delay, replicas, series)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--arm", choices=["reactive", "headroom"], required=True)
    ap.add_argument("--boot-delay", type=float, default=30.0)
    ap.add_argument("--replicas", type=int, default=100)
    ap.add_argument("--timeout", type=float, default=300.0)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    fn = run_reactive if args.arm == "reactive" else run_headroom
    result = fn(args.replicas, args.boot_delay, args.timeout)

    ready = [p["ready_s"] for p in result["pods"] if p["ready_s"] is not None]
    ready.sort()
    if ready:
        p50 = ready[len(ready) // 2]
        p95 = ready[min(len(ready) - 1, int(0.95 * len(ready)))]
        print(f"{args.arm} boot={args.boot_delay}s "
              f"n={len(ready)}/{args.replicas} ready  "
              f"p50={p50:.1f}s p95={p95:.1f}s max={ready[-1]:.1f}s")

    Path(args.out).write_text(json.dumps(result, indent=2))
    print("wrote", args.out)


if __name__ == "__main__":
    main()

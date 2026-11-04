# Runbook: pod OOMKilled

**Alert:** `WebApiOOMKilled`. A `web-api` container was killed by the kernel for going over its memory limit.

## 1. Confirm it's really OOM

```bash
kubectl -n <ns> get pods -l app.kubernetes.io/name=web-api
kubectl -n <ns> describe pod <pod> | grep -A5 "Last State"
#   Last State: Terminated
#     Reason:   OOMKilled
#     Exit Code: 137
```

Exit code 137 *without* `OOMKilled` means something else sent SIGKILL, such as a failing liveness probe or node pressure. Check events instead:

```bash
kubectl -n <ns> get events --sort-by=.lastTimestamp | tail -20
```

## 2. Was it the container limit or the node?

| Signal | Meaning | Fix lives in |
|---|---|---|
| `Reason: OOMKilled` on the container | The container went over its **limit** | the app's `resources.limits.memory` |
| Pod `Evicted`, node shows `MemoryPressure` | The **node** ran out; kubelet evicted pods | node size, or **requests** too low (overcommit) |

```bash
kubectl describe node <node> | grep -A8 Conditions
```

## 3. Size it from data, not guesses

```promql
# peak working set per pod over the last day
max_over_time(container_memory_working_set_bytes{namespace="<ns>", container="app"}[1d])
```

- Set the **limit** about 25–30% above the observed peak.
- Set the **request** near typical usage so the scheduler doesn't overcommit the node.
- If usage climbs steadily and never drops, it's a **leak**. Raising the limit only delays the next kill, so open a bug with the graph attached.

## 4. Ship the fix through Git

Change `resources` in `charts/web-api/values-<env>.yaml` and open a PR. CI renders and validates the chart, and Argo CD rolls it out. Don't `kubectl edit` the Deployment: Argo CD's self-heal reverts it within minutes.

## 5. Check the fix

```bash
kubectl -n <ns> get pods -w      # restarts stop climbing
```

The alert resolves once there have been no OOM restarts for 15 minutes.

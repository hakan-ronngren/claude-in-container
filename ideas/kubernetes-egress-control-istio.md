# Egress Control via Kubernetes + Istio

## Idea

Run the container as a Kubernetes pod (via Rancher Desktop) instead of plain Docker, to gain declarative, enforceable egress control using Istio's service mesh.

Plain Docker makes egress control hard. Kubernetes `NetworkPolicy` + Istio solves it cleanly.

## Key design points

- **Default-deny egress** — set `outboundTrafficPolicy: REGISTRY_ONLY` on the mesh or via a `Sidecar` resource; all outbound traffic is blocked unless explicitly declared
- **FQDN-based allowlist** — `ServiceEntry` resources declare allowed external hostnames; Envoy enforces these at the sidecar level
- **Envoy access logs / Kiali for visibility** — blocked and allowed connections are visible in Envoy's access log and Kiali's graph, which drives allowlist maintenance over time
- **Hardcoded-IP exfiltration is caught** — `REGISTRY_ONLY` drops traffic to any destination not declared in a `ServiceEntry`, regardless of whether DNS was used, as long as the pod runs without `CAP_NET_ADMIN` and as a non-root user

## How enforcement works

Istio injects an Envoy sidecar proxy into the pod. All outbound traffic is redirected through Envoy via iptables rules. With `REGISTRY_ONLY`, Envoy rejects connections to undeclared destinations.

**Security boundary:** enforcement relies on iptables and the sidecar being in the traffic path. A process with root or `CAP_NET_ADMIN` could write rules that bypass it. The `claude` user in this project is non-root and has no such capabilities, so the boundary holds in practice.

## Setup on Rancher Desktop

Istio is an add-on layer and does **not** require replacing the CNI (flannel can stay). Install via Helm or `istioctl`:

```bash
istioctl install --set profile=minimal
```

Enable sidecar injection for the `claude` namespace:

```bash
kubectl label namespace claude istio-injection=enabled
```

## Mesh configuration

Set default-deny egress on the namespace:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: claude
spec:
  egress:
  - hosts:
    - istio-system/*   # allow control-plane traffic
```

Then allow specific external services via `ServiceEntry` + `outboundTrafficPolicy`:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: MeshConfig
# Alternatively set in istioctl install --set meshConfig.outboundTrafficPolicy.mode=REGISTRY_ONLY
```

## Allowlist entries (ServiceEntry per host)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: allow-anthropic
  namespace: claude
spec:
  hosts:
  - api.anthropic.com
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  resolution: DNS
  location: MESH_EXTERNAL
```

Repeat for each allowed host. Initial allowlist candidates:

- `api.anthropic.com:443`
- `registry.npmjs.org:443` (or private registry equivalent)
- `github.com:443`
- Others to be discovered via Envoy access logs during initial runs

## Observability

Stream blocked connections from the sidecar:

```bash
kubectl logs -n claude <pod-name> -c istio-proxy | grep '"response_code":"403"'
```

Or use Kiali (if installed) for a graph view of allowed and blocked flows.

## Rancher Desktop footprint

Istio requires no changes to the Lima VM configuration and leaves no files outside of normal Rancher Desktop preferences. This is a clear advantage over the Cilium alternative, which requires a persistent `override.yaml` in the Lima config directory that is easy to forget and can cause mysterious failures if left behind after uninstalling.

## Known boundaries

- Enforcement depends on the sidecar being injected and iptables rules being in place. Non-root pods without `CAP_NET_ADMIN` cannot bypass this; privileged pods could.
- DNS-over-HTTPS bypasses FQDN matching but is still blocked by `REGISTRY_ONLY` (the destination IP is unknown to Envoy).
- Hardcoded IPs with no `ServiceEntry` are blocked, since `REGISTRY_ONLY` rejects undeclared destinations.
- The Istio control plane itself needs network access; `istio-system` hosts must be reachable.

## Next steps

1. Install Istio on Rancher Desktop via `istioctl install --set profile=minimal`
2. Label the `claude` namespace for sidecar injection
3. Set `outboundTrafficPolicy: REGISTRY_ONLY` (mesh-wide or per-namespace)
4. Write a `ServiceEntry` for each initial allowlist host
5. Run Claude, observe blocked requests in Envoy access logs, iterate on allowlist
6. Keep the `ServiceEntry` manifests in this repo as the auditable record

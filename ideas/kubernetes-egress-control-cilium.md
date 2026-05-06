# Egress Control via Kubernetes + Cilium

## Idea

Run the container as a Kubernetes pod (via Rancher Desktop) instead of plain Docker, to gain declarative, enforceable egress control using Cilium network policies.

Plain Docker makes egress control hard. Kubernetes `NetworkPolicy` + Cilium solves it cleanly.

## Key design points

- **Default-deny egress** — all outbound traffic blocked unless explicitly allowed
- **FQDN-based allowlist** — Cilium intercepts DNS and dynamically tracks resolved IPs per TTL, so the allowlist stays bounded and current
- **Hubble for visibility** — `hubble observe --pod claude-sandbox --verdict DROPPED` shows what's being blocked, which drives allowlist maintenance over time
- **Hardcoded-IP exfiltration (supply-chain attacks) is caught** — default-deny drops traffic to any IP not resolved through an allowed FQDN, regardless of whether DNS was used

## CNI requirement

Rancher Desktop defaults to flannel, which does **not** enforce `NetworkPolicy`. Must switch to **Cilium**, which also provides:
- FQDN-based egress rules (`CiliumNetworkPolicy`)
- Hubble observability layer

## Rancher Desktop footprint

Cilium requires modifying the Lima VM configuration via `~/Library/Application Support/rancher-desktop/lima/_config/override.yaml`. This file persists outside the normal Rancher Desktop preferences and must be manually removed if Cilium is abandoned — easy to forget and can cause mysterious failures. The Istio alternative leaves no such footprint.

## Known boundaries

- Cilium's FQDN policy requires the pod to use cluster DNS (CoreDNS). DNS-over-HTTPS or hardcoded IPs bypass FQDN matching — but are still blocked by default-deny.
- DNS TTL expiry during a long-running connection can cause a brief interruption. Mitigated by `--tofqdns-min-ttl` if needed.

## Initial allowlist candidates

- `api.anthropic.com:443`
- `registry.npmjs.org:443` (or private registry equivalent)
- `github.com:443`
- Others to be discovered via Hubble during initial runs

## Next steps

1. Investigate switching Rancher Desktop's CNI to Cilium
2. Write a pod spec for `claude-in-container` with `hostPath` volume for the project directory
3. Write a `CiliumNetworkPolicy` with default-deny + initial allowlist
4. Run Claude, observe drops in Hubble, iterate on allowlist
5. Keep the policy file in this repo as the auditable record

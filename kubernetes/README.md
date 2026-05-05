# Kubernetes manifests

These manifests target a local [Rancher Desktop](https://rancherdesktop.io/) cluster whose API server listens on port 6443.

## Prerequisites

- Rancher Desktop installed and running, with **dockerd** selected as the container engine (Preferences → Container Engine)
- `kubectl` configured to talk to the local cluster

Rancher Desktop sets up a `rancher-desktop` context automatically. Verify it is active:

```bash
kubectl config current-context
```

If not, switch to it:

```bash
kubectl config use-context rancher-desktop
# or with kubectx
kubectx rancher-desktop
```

## Deploy

Apply all manifests in this directory:

```bash
kubectl apply -f kubernetes
```

Or apply a specific file:

```bash
kubectl apply -f kubernetes/namespace.yaml
```

## Verify

```bash
kubectl get namespace claude
```

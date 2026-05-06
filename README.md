# claude-in-container

Runs Claude Code in a Kubernetes pod, persisting your credentials, preferences, and session information in a directory on your host, separate from your home directory.

## System requirements

- [Rancher Desktop](https://rancherdesktop.io/)
  - **dockerd** or **containerd** as the container engine (Preferences → Container Engine) — `build` detects which is active and uses `docker` or `nerdctl` accordingly
  - Kubernetes enabled (Preferences → Kubernetes)
- A valid Claude subscription

## Install

1. Clone this repository in your home directory
2. Run `./build` once from the repository directory to build the image. Use `./build --force` if the Dockerfile hasn't changed but the image is missing — this happens after a Kubernetes Reset (which wipes the image store) or after switching container engine (dockerd and containerd have separate image stores)
3. Choose a directory you have in your `PATH`, such as `~/.local/bin`
4. Symlink the scripts you want into that directory, e.g.:
   ```bash
   ln -s $PWD/claude-in-container ~/.local/bin
   ln -s $PWD/shell-in-claude-container ~/.local/bin
   ln -s $PWD/show-blocked-claude-container-egress ~/.local/bin
   ```

## Adapt to your needs

Edit the [Dockerfile](./Dockerfile) and add the Debian packages or whatever tools you need in your image, then run `./build` again.

If you need to inspect or modify a running container, run `shell-in-claude-container` to exec into it.

## Run

Run `claude-in-container` from inside any project directory, the way you would usually run `claude`, with the usual flags.

On first run, Claude will prompt you to log in. Your credentials are saved into `~/.local/share/claude-in-container/home`, which is mounted as `/home/claude` inside the pod. State persists across sessions because it lives in that host directory rather than in the pod itself.

### Resuming sessions

When you exit Claude, it prints a message like:

```
Resume this session with:
claude --resume e40a1763-ab5e-4143-8ec2-be874bb4aacd
```

Since you're running inside a container, use `claude-in-container` instead:

```bash
claude-in-container --resume e40a1763-ab5e-4143-8ec2-be874bb4aacd
```

This creates a fresh pod but resumes your previous session, since session data persists in `~/.local/share/claude-in-container/home`.

## Reaching host services from inside the pod

By default the pod runs with `hostNetwork: true`, so services on the host are reachable at `localhost` or `host.docker.internal` (both resolve to the host).

When egress control is enabled (see below), `hostNetwork` is set to `false`, but `host.docker.internal` still resolves to the host and bypasses the Istio sidecar, so host services remain fully accessible.

## Egress control (optional)

You can restrict the pod's outbound network access to an explicit allowlist using [Istio](https://istio.io/). This is an opt-in hardening step that works with flannel (Rancher Desktop's default CNI) and either container engine.

### Prerequisites

Get the `istioctl` command unless you have it already:

```bash
curl -L https://istio.io/downloadIstio | sh -
```

Add `istio-<whatever_version_you_got>/bin` to your `PATH` or create an `istioctl` symlink in a directory that is in your `PATH`.

Then install Istio in your cluster with `REGISTRY_ONLY` egress mode:

```bash
istioctl install --set profile=minimal \
                 --set meshConfig.outboundTrafficPolicy.mode=REGISTRY_ONLY \
                 --set meshConfig.accessLogFile=/dev/stdout -y
```

Full getting-started guide: [istio.io/latest/docs/setup/getting-started/](https://istio.io/latest/docs/setup/getting-started/)

### Enable egress control

```bash
./setup-network-security
```

This writes Istio manifests to `~/.config/claude-in-container/manifests/`. From that point on, `claude-in-container` automatically applies them before starting each pod, injecting an Envoy sidecar that blocks all outbound traffic except an initial allowlist:

- `api.anthropic.com:443`
- `statsig.anthropic.com:443`
- `github.com:443` / `*.github.com:443`
- `registry.npmjs.org:443`

### Discovering blocked traffic

Run this in a separate terminal while Claude is active:

```bash
show-blocked-claude-container-egress
```

This streams `BlackHoleCluster` entries from the Istio sidecar access log — one line per blocked connection, including the destination hostname or IP.

To add a destination, add a `ServiceEntry` to `~/.config/claude-in-container/manifests/istio-service-entries.yaml` and a matching host to `istio-sidecar.yaml`, then re-run `setup-network-security`. Changes take effect on the next `claude-in-container` run.

## License

This repository is released under the [MIT License](LICENSE). You are free to fork, modify, and redistribute it for any purpose.

Note that Claude Code itself is proprietary software owned by Anthropic. Use of Claude Code is governed by the [Anthropic Usage Policy](https://www.anthropic.com/legal/aup) and requires a valid Claude subscription. This license covers only the files in this repository.

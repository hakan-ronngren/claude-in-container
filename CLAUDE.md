# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repo provides scripts to run Claude Code inside a Kubernetes pod on a local Rancher Desktop cluster, isolating credentials and preferences from the host system:

- `Dockerfile` — builds a Debian-based image with Node.js (system-wide via NodeSource) and Claude Code pre-installed as user `claude`
- `build` — builds the Docker image and tags it with a random 4-byte hex string, storing the tag in `~/.config/claude-in-container/tag`; only rebuilds when the Dockerfile is newer than the tag file
- `claude-in-container` — checks the tag file, creates a short-lived Kubernetes pod with the built image, and exec's `claude` inside it
- `update-claude-container-egress` — regenerates and applies Istio egress manifests from the allowlist; called automatically by `claude-in-container` and can also be run mid-session to apply allowlist changes without restarting

## How it works

`claude-in-container` sets the kubectl context to `rancher-desktop`, then creates a pod named `claude-<random>` in one of two namespaces:

- `claude` — default; egress restricted to `~/.config/claude-in-container/allowed-egresses.conf` via Istio
- `claude-insecure` — used with `--insecure`; unrestricted egress, no Istio sidecar

The pod mounts:

- `~/.local/share/claude-in-container/home` → `/home/claude` (persists Claude config and credentials across sessions)
- The caller's current working directory → `/home/claude/projects/<project-name>` (the project to work on)

Host services are reachable at `host.docker.internal`. Since egress control is active in the `claude` namespace, `localhost` refers to the pod's own loopback and cannot be used to reach host services — use `host.docker.internal` instead. When the session ends, a trap deletes the pod automatically.

## Rebuilding the image

Run `build` from the repository directory. It rebuilds only if the Dockerfile has changed since the last build. To force a full rebuild without cache:

```bash
docker build --no-cache -t claude-in-container:<tag> ~/claude-in-container
```

## For power users

- If the user needs to inspect or modify your container, they can run `shell-in-claude-container` to exec into it.
- To update the egress allowlist while a session is running, edit `~/.config/claude-in-container/allowed-egresses.conf` and run `update-claude-container-egress`.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repo provides three files to run Claude Code inside a Kubernetes pod on a local Rancher Desktop cluster, isolating credentials and preferences from the host system:

- `Dockerfile` — builds a Debian-based image with Node.js (system-wide via NodeSource) and Claude Code pre-installed as user `claude`
- `build` — builds the Docker image and tags it with a random 4-byte hex string, storing the tag in `~/.config/claude-in-container/tag`; only rebuilds when the Dockerfile is newer than the tag file
- `claude-in-container` — checks the tag file, creates a short-lived Kubernetes pod with the built image, and exec's `claude` inside it

## How it works

`claude-in-container` sets the kubectl context to `rancher-desktop`, then creates a pod named `claude-<random>` in the `claude` namespace. The pod mounts:

- `~/.local/share/claude-in-container/home` → `/home/claude` (persists Claude config and credentials across sessions)
- The caller's current working directory → `/home/claude/projects/<project-name>` (the project to work on)

The pod uses `hostNetwork: true`, so host services are reachable at `localhost` or `host.docker.internal`. When the session ends, a trap deletes the pod automatically.

## Rebuilding the image

Run `build` from the repository directory. It rebuilds only if the Dockerfile has changed since the last build. To force a full rebuild without cache:

```bash
docker build --no-cache -t claude-in-container:<tag> ~/claude-in-container
```

## Reaching host services from inside the pod

The pod runs with `hostNetwork: true`, so services on the host are reachable at `localhost` or `host.docker.internal`.

## For power users

- If the user needs to inspect or modify your container, they can run `shell-in-claude-container` to exec into it.

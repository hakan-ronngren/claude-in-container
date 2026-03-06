# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repo provides two files to run Claude Code inside a Docker container, isolating credentials and preferences from the host system:

- `Dockerfile` — builds a Debian-based image with Node.js (via nvm), pnpm, and Claude Code pre-installed as user `me`
- `claude-in-container` — a bash script that builds the image if needed, starts a named container with Docker volumes for persistence, and exec's `claude` inside it

## How it works

The script mounts the caller's current working directory into the container at `/home/me/<project-name>` and sets that as the working directory. State persists across sessions:

- Volume `claude-in-container_claude-home` — the entire `/home/me` directory (includes Claude config, nvm, credentials)

On each invocation, any existing container is removed and a new one is created. The container runs a sleep loop in the background; `docker exec` is used to attach interactively. Volumes ensure state survives container recreation.

## Setup

Place `claude-in-container` (the script) and `Dockerfile` in a directory on your PATH. The script hard-codes `DOCKERFILE_DIR="$HOME/claude-in-container"` — update this path to match where you put the files.

## Rebuilding the image

The script always runs `docker build` on each invocation, so the image is kept up to date automatically. Docker's layer cache makes this fast when nothing has changed. To force a full rebuild without cache:

```bash
docker build --no-cache -t claude-in-container ~/claude-in-container
```

## Reaching host services from inside the container

The container sets `TEST_HOST=host.docker.internal` and adds the `host-gateway` host entry, so services on the host are reachable at `host.docker.internal`.

# claude-in-container

Runs Claude Code in a Kubernetes pod, persisting your credentials, preferences, and session information in a directory on your host, separate from your home directory.

## System requirements

- [Rancher Desktop](https://rancherdesktop.io/)
  - **dockerd** selected as the container engine (Preferences → Container Engine)
  - Kubernetes enabled (Preferences → Kubernetes).
- A valid Claude subscription

## Install

1. Clone this repository in your home directory
2. Run `./build` once from the repository directory to build the image
3. Choose a directory you have in your `PATH`, such as `~/bin`
4. Run `ln -s $HOME/claude-in-container/claude-in-container ~/bin` or whichever directory you chose

## Adapt to your needs

Edit the [Dockerfile](./Dockerfile) and add the Debian packages or whatever tools you need in your image, then run `./build` again.

If you need to inspect or modify a running container, run `shell-in-claude-container` to exec into it.

## Run

Run `claude-in-container` from inside any project directory, the way you would usually run `claude`, with the usual flags.

On first run, Claude will prompt you to log in. Your credentials are saved into `~/.local/share/claude-in-container/home`, which is mounted as `/home/claude` inside the pod. State persists across sessions because it lives in that host directory rather than in the pod itself.

## Reaching host services from inside the pod

The pod runs with `hostNetwork: true`, so services on the host are reachable at `localhost` or `host.docker.internal` (both resolve to the host).

## License

This repository is released under the [MIT License](LICENSE). You are free to fork, modify, and redistribute it for any purpose.

Note that Claude Code itself is proprietary software owned by Anthropic. Use of Claude Code is governed by the [Anthropic Usage Policy](https://www.anthropic.com/legal/aup) and requires a valid Claude subscription. This license covers only the files in this repository.

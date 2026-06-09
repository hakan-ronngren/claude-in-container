# claude-in-container

Run Claude Code in a sandbox that can't touch your home directory or reach the wider internet, so you can let it work freely without watching every command. It also gives each feature its own isolated clone — a workflow Claude handles more reliably than git worktrees. Your credentials, preferences, and sessions persist between runs, kept separate from the ones on your host.

## System requirements

`claude-in-container` is built and tested on a Mac. You will need:

- A Claude subscription
- **Bash ≥ 4, installed via [Homebrew](https://brew.sh/)** (`brew install bash`). The
  scripts use features such as `globstar` that the macOS system `/bin/bash` (version
  3.2) does not support, so their shebangs point at Homebrew's bash at
  `/opt/homebrew/bin/bash` (Apple Silicon). On an Intel Mac, Homebrew installs it at
  `/usr/local/bin/bash`; update the shebang lines accordingly.
- [Rancher Desktop](https://rancherdesktop.io/)
  - **dockerd** or **containerd** as the container engine (Preferences → Container Engine) — `build` detects which is active and uses `docker` or `nerdctl` accordingly
  - Kubernetes enabled (Preferences → Kubernetes)
- [Istio](https://istio.io/) installed in your Rancher Desktop cluster (see [Egress control](#egress-control) below)

## Install

1. Clone this repository in your home directory
2. Run `./build` once from the repository directory to build the image. Use `./build --force` if the Dockerfile hasn't changed but the image is missing — this happens after a Kubernetes Reset (which wipes the image store) or after switching container engine (dockerd and containerd have separate image stores)
3. Choose a directory you have in your `PATH`, such as `~/.local/bin`
4. Symlink the scripts you want into that directory, e.g.:
   ```bash
   ln -s $PWD/claude-in-container ~/.local/bin
   ln -s $PWD/shell-in-claude-container ~/.local/bin
   ln -s $PWD/show-blocked-claude-container-egress ~/.local/bin
   ln -s $PWD/update-claude-container-egress ~/.local/bin
   ```

## Adapt to your needs

Edit the [Dockerfile](./Dockerfile) and add the Debian packages or whatever tools you need in your image, then run `./build` again.

If you need to inspect or modify a running container, run `shell-in-claude-container` to exec into it.

## Customizing the pod

You can inject extra environment variables and bind mounts by creating files in `~/.config/claude-in-container/`.

### Extra environment variables — `env.conf`

Each line sets one variable (`KEY=VALUE`). Lines starting with `#` are ignored.

```
MY_API_KEY=abc123
MY_REGION=us-east-1
```

### Extra bind mounts — `mounts.conf`

Each line adds one mount (`host-path:container-path`). `~` is expanded to your home directory. Lines starting with `#` are ignored. If the host path does not exist, the script exits with an error.

```
~/.config/gcloud/application_default_credentials.json:/home/claude/.config/gcloud/application_default_credentials.json
```

**File mounts:** Kubernetes requires the parent directory of a file mount to exist inside the container. Because `/home/claude` is itself a bind mount from `~/.local/share/claude-in-container/home`, you need to pre-create the parent there. For the example above:

```bash
mkdir -p ~/.local/share/claude-in-container/home/.config/gcloud
```

## Run

Run `claude-in-container` from inside any project directory, the way you would usually run `claude`, with the usual flags.

The pod's home directory `/home/claude` is mounted from `~/.local/share/claude-in-container/home` on your host, so its contents persist across sessions even though the pod itself is ephemeral.

On the very first run, Claude Code installs itself into `/home/claude` before starting. This takes about a minute and only happens once — subsequent runs skip straight to Claude. After installation, Claude will prompt you to log in; your credentials are stored in `/home/claude` and reused in every subsequent session.

**Tip: skip the permission prompts.** Because the pod already isolates your
credentials and controls egress, you can let Claude run tools without asking for
approval each time. Rather than passing `--dangerously-skip-permissions` on every
launch, make it the default for every session by adding a `"permissions"` block
to `~/.local/share/claude-in-container/home/.claude/settings.json`:

```json
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  },
  ... (other settings) ...
}
```

This setting lives in the container's mounted home, so it only affects sessions
inside the sandbox and never your host's Claude install. (A couple of guardrail
commands such as `rm -rf /` still prompt as a safety check.) Claude runs as the
non-root `claude` user in the pod, so bypass mode is permitted — outside a sandbox
it would be refused for root/sudo sessions.

### Feature workspaces — `--cic-feature`

When you run `claude-in-container --cic-feature <NAME>` from inside any git clone (the
current directory does not have to be the repository root), the session works in a
dedicated clone of the repository's `origin` instead of your current directory:

```bash
claude-in-container --cic-feature add-login
```

This resembles how Claude works with Git worktrees, but it works around the common
issues with Claude suddenly deciding to escape from the worktree and start working
in the main clone instead.

The clone is created at `<repo-root>/.claude/cic-features/<NAME>` within your current
repository, and it becomes the pod's working directory. The clone persists across
sessions, so re-running with the same `<NAME>` reuses the existing clone rather than
cloning again — letting you re-enter a feature workspace later. This keeps each piece
of work fully isolated in its own checkout, similar to `git worktree` but as
independent clones.

The `.claude/cic-features` directory is automatically added to `.git/info/exclude`,
so feature clones don't appear in `git status`. Since feature clones are subdirectories
of the main repository, they inherit trust from the parent — **as long as you've run
`claude-in-container` in the main clone at least once** (without `--cic-feature`, so
that the parent repository itself is trusted). Once that's done, all feature clones
will be trusted automatically.

Because the clone is made from `origin`, the repository must have an `origin` remote,
and uncommitted or unpushed local changes in your working copy are not carried over.

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

The pod always runs with `hostNetwork: false`, so `localhost` refers to the pod's own loopback — it does **not** reach the host. Use `host.docker.internal` instead. In the default (controlled) mode, `host.docker.internal` bypasses the Istio sidecar, so host services remain fully accessible.

## Egress control

`claude-in-container` runs pods in one of two Kubernetes namespaces depending on the session type:

| Mode | Namespace | Egress |
|---|---|---|
| Default | `claude` | Restricted to an explicit allowlist via Istio |
| Unrestricted | `claude-insecure` | No restrictions |

```bash
claude-in-container            # controlled egress
claude-in-container --cic-insecure # unrestricted egress
```

Use `--cic-insecure` when you need broad web access, such as open research sessions.

### Prerequisites (one-time cluster setup)

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

After this one-time setup, `claude-in-container` handles the rest automatically: it verifies the mesh configuration on each run, creates your allowlist file from the template if it doesn't exist yet, and applies the Istio manifests before starting the pod.

### Customising the allowlist

On first run, `claude-in-container` copies `allowed-egresses.conf.template` (from this repo) to `~/.config/claude-in-container/allowed-egresses.conf`. Edit the `~/.config/` copy to add or remove destinations — the template is never modified.

Each line is a hostname. Wildcards (e.g. `*.example.com`) are supported. Lines starting with `#` are ignored. Changes take effect on the next `claude-in-container` run.

### Updating the allowlist mid-session

To apply allowlist changes without restarting the pod:

1. Edit `~/.config/claude-in-container/allowed-egresses.conf`
2. Run `update-claude-container-egress`

Istio applies the new rules immediately; the running pod picks them up without interruption.

### Discovering blocked traffic

This only applies to the default (controlled egress) mode. In `--cic-insecure` mode there is no Istio sidecar, so there is no blocked-traffic log to stream.

Run this in a separate terminal while Claude is active:

```bash
show-blocked-claude-container-egress
```

This streams `BlackHoleCluster` entries from the Istio sidecar access log — one line per blocked connection, including the destination hostname or IP.

## License

This repository is released under the [MIT License](LICENSE). You are free to fork, modify, and redistribute it for any purpose.

Note that Claude Code itself is proprietary software owned by Anthropic. Use of Claude Code is governed by the [Anthropic Usage Policy](https://www.anthropic.com/legal/aup) and requires a valid Claude subscription. This license covers only the files in this repository.

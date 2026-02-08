# mcci-claude-container

A lightweight Docker container for running Claude Code with network firewall isolation. This provides the security benefits of Anthropic's devcontainer approach without the VS Code coupling or heavyweight tooling.

## Overview

This setup runs Claude Code in an isolated Docker container with:

- **Egress firewall** — default-deny iptables rules that only allow connections to whitelisted domains (GitHub, npm, Anthropic API, etc.)
- **UID/GID alignment** — container user matches your host user, avoiding file permission issues
- **Per-project isolation** — each project gets its own firewall rules, credentials, and shell history
- **Minimal footprint** — Ubuntu base with only essential packages (no zsh, oh-my-zsh, fzf, VS Code extensions, etc.)

The firewall isolation is what allows you to safely run `claude --dangerously-skip-permissions` for unattended operation, since network exfiltration is blocked at the kernel level.

## Prerequisites

- Docker (tested with Docker 28.x)
- GNU Make
- A Claude account (Pro, Max, or API key)

## Quick Start

### 1. Build the container (once per user)

```bash
cd /path/to/mcci-claude-container
make build
```

This builds a container image with your UID/GID baked in, so files created inside the container are owned by you on the host.

### 2. Set up a project

Create a project directory with this structure:

```
my-project/
├── init-firewall-extra-domains.conf # additional domains to whitelist (can be empty)
├── .context/                        # created automatically on first run
│   ├── .claude/                     # Claude credentials and history
│   ├── .claude.json                 # Claude settings (onboarding state, etc.)
│   ├── .bashrc                      # shell config (copied from host on first run)
│   ├── .bash_aliases                # shell aliases (copied from host on first run)
│   ├── .bash_history                # persistent shell history
│   └── .cache/                      # Claude marketplace plugins, etc.
└── workspace/                       # your actual project files (mounted at /workspace)
```

### 3. Run Claude

```bash
cd /path/to/my-project
make -f /path/to/mcci-claude-container/Makefile run
```

On first run:
- `.context/` and `workspace/` directories are created
- `.bashrc` and `.bash_aliases` are copied from your home directory
- Empty `init-firewall-extra-domains.conf` is created if missing
- You'll need to authenticate with Claude

Subsequent runs pick up your saved credentials and settings.

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make build` | Build the container image for your user |
| `make run` | Run Claude in the container with firewall |
| `make run-ssh` | Run with SSH agent forwarding (for git over SSH) |
| `make run-ssh-nofw` | Run with SSH agent but no firewall (debugging) |
| `make push` | Push image to a container registry (requires setting `MCCI_CLAUDE_CONTAINER_REPO`) |

## Adding Custom Domains

Edit `init-firewall-extra-domains.conf` in your project root with one domain per line:

```
supabase.com
mcp.supabase.com
my-company-api.example.com
```

These domains are resolved to IP addresses at container startup and added to the firewall whitelist.

**Note**: for simplicity of Makefile implementation, `make run` creates an empty `init-firewall-extra-domains.conf` if it doesn't already exist.

## Default Whitelisted Domains

The firewall allows connections to:

- **GitHub** — api.github.com, github.com, and all GitHub IP ranges (fetched dynamically)
- **npm** — registry.npmjs.org
- **Anthropic** — api.anthropic.com, statsig.anthropic.com
- **VS Code Marketplace** — marketplace.visualstudio.com, vscode.blob.core.windows.net, update.code.visualstudio.com
- **Monitoring** — sentry.io, statsig.com
- **Infrastructure** — DNS (UDP 53), SSH (TCP 22), localhost, Docker host network

Everything else is blocked with `REJECT --reject-with icmp-admin-prohibited` for immediate feedback.

## How It Works

### Container Startup Sequence

1. Docker starts the container with `--cap-add=NET_ADMIN --cap-add=NET_RAW`
2. Bash runs with `--init-file /usr/local/bin/read-bashrc-init-firewall.sh`
3. The init script sources `.bashrc`, then runs the firewall setup
4. `init-firewall.sh` flushes iptables, fetches GitHub IPs, resolves allowed domains, and sets up rules
5. Firewall verification tests confirm the rules work (blocks example.com, allows api.github.com)
6. You're dropped into a shell at `/workspace`

### File Mounts

| Host Path | Container Path | Mode |
|-----------|----------------|------|
| `./workspace` | `/workspace` | read-write |
| `./.context/.claude` | `~/.claude` | read-write |
| `./.context/.claude.json` | `~/.claude.json` | read-write |
| `./.context/.cache` | `~/.cache` | read-write |
| `./.context/.bashrc` | `~/.bashrc` | read-only |
| `./.context/.bash_aliases` | `~/.bash_aliases` | read-only |
| `./.context/.bash_history` | `~/.bash_history` | read-write |
| `./init-firewall-extra-domains.conf` | `/usr/local/etc/init-firewall-extra-domains.conf` | read-only |

### Security Model

The firewall uses iptables with ipset for efficient IP matching:

1. **Preserve Docker DNS** — saves and restores Docker's internal DNS NAT rules
2. **Allow infrastructure** — DNS, SSH, localhost, Docker host network
3. **Create whitelist** — ipset hash:net for allowed IP ranges
4. **Fetch GitHub IPs** — dynamic lookup from api.github.com/meta, aggregated with `aggregate`
5. **Resolve domains** — DNS A record lookup for each allowed domain
6. **Default DROP** — all chains default to DROP
7. **Allow established** — permit responses to allowed outbound connections
8. **Match whitelist** — allow outbound to ipset members
9. **Explicit REJECT** — everything else gets ICMP admin-prohibited

## Troubleshooting

### Firewall blocks a domain I need

Add it to `init-firewall-extra-domains.conf` and restart the container.

### DNS resolution fails during startup

The firewall script exits on any error. Check that you have network connectivity on the host and that the domain is valid.
### Permission denied on mounted files

Make sure you built the container with your UID/GID, and not as another user. The Makefile uses the current UID and GID
to make sure your user inside the container will be the same as you. You can override this via make settings:

```bash
make build BUILD_UID=$(id -u) BUILD_GID=$(id -g) BUILD_UNAME=$USER
```

### Claude keeps asking for login

Ensure `.context/.claude/` and `.context/.claude.json` persist between runs. Check that the mount paths in the Makefile match your project structure.

### Need to debug without firewall

Use `make run-ssh-nofw` to start the container without firewall rules.

## Customization

### Different Ubuntu version

```bash
docker build --build-arg UBUNTU_VERSION=22.04 ...
```

### Additional packages

Edit the `Dockerfile` to add packages in the `apt-get install` section.

### Different Node.js version

Edit the `Dockerfile` to change the NodeSource setup URL.

## License and Acknowledgements

Written by Terry Moore, MCCI Corporation, by referring to the standing Anthropic container [claude-code](https://github.com/anthropics/claude-code).

This repository contains code under two licenses:

- **`init-firewall.sh`** — derived from Anthropic's [claude-code](https://github.com/anthropics/claude-code) and subject to the Business Source License. See [LICENSE-init-firewall.md](LICENSE-init-firewall.md).
- **All other files** — copyright © 2026 MCCI Corporation, released under the MIT License. See [LICENSE.md](LICENSE.md).

This README was prepared with help of Claude, and I used Claude for code review and debugging advice.

Copyright © 2026 MCCI Corporation. See LICENSE.md file.

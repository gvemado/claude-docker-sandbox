# Claude Code Docker Sandbox

This repository provides a Docker sandbox launcher for [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview). It runs Claude with permission prompts disabled inside an isolated, host-side Git worktree.

## What it does

- Builds a Claude Code image from `docker/sandbox-templates:copilot`, retaining the development tools supplied by the existing sandbox template
- Installs Claude Code as the unprivileged `agent` user
- Starts every Claude session with `--dangerously-skip-permissions`, so Claude does not ask to approve commands or file changes
- Creates or reuses one managed worktree per branch, allowing concurrent sandbox sessions on separate branches
- Keeps the current subdirectory when it exists on the selected branch
- Mounts the worktree and the repository's common Git directory at identical absolute paths, so Git works normally in the container
- Mounts `~/.claude` and, when present, `~/.claude.json` into the container to persist Claude credentials, settings, memory, and user MCP configuration
- Mounts host SSH and GPG configuration only as needed for Git access; SSH keys are copied into the container and the host SSH agent is forwarded through a container-local relay
- Retains `uv`, `uvx`, the MySQL MCP server, the AWS DocumentDB MCP server, and the DocumentDB TLS certificate from the original sandbox

The container is disposable, but the selected Git worktree and your Claude configuration are persistent. The worktree is removed automatically after a clean session; it is preserved whenever it contains uncommitted changes.

## Prerequisites

- Docker Desktop or Docker Engine
- Git
- A Claude Code account or another supported Claude Code authentication method
- Network access from the container to Anthropic's API endpoints

The image installs the Claude CLI during `docker build`; its first build therefore needs access to npm. On first launch, complete `/login` in the Claude terminal if your host `~/.claude` does not already contain credentials.

## Usage

Run the launcher from anywhere inside a Git repository:

```bash
/Users/gvemado/Projects/claude-sandbox/claude-sandbox
```

The launcher prompts for a branch name. It reuses an idle managed worktree for an existing branch, creates a worktree for another existing branch, or creates a branch and worktree when the branch does not yet exist.

To invoke it by name, put it on your `PATH`:

```bash
ln -s /Users/gvemado/Projects/claude-sandbox/claude-sandbox /usr/local/bin/claude-sandbox
```

Then use it from any repository:

```bash
cd /path/to/project
claude-sandbox
```

Skip the branch prompt:

```bash
claude-sandbox --branch feature/my-task
```

Forward Claude Code options after `--`:

```bash
claude-sandbox --branch feature/my-task -- --continue
claude-sandbox --branch feature/my-task -- --model opus
```

The launcher appends `--dangerously-skip-permissions` after all forwarded arguments. This deliberately enforces Claude's no-prompt mode for the session.

## Configuration

- `CLAUDE_SANDBOX_BRANCH` supplies a default branch.
- `CLAUDE_SANDBOX_WORKTREE_ROOT` overrides the worktree location. The default is `~/.local/share/claude-sandbox/worktrees`.
- `CLAUDE_SANDBOX_IMAGE` overrides the generated image tag.
- `--rebuild` rebuilds the image, which also picks up the latest Claude Code release available from npm.
- A live host `SSH_AUTH_SOCK` is forwarded automatically. `~/.ssh` and `~/.gnupg` are mounted only when present.

## Security model

`--dangerously-skip-permissions` grants Claude unrestricted access to the container. That is intentional for this launcher, but it should be used only for repositories and prompts you trust. In this setup Claude can modify the selected worktree, use the network, invoke the installed development tools, and use the mounted Git credentials to fetch, sign, or push according to their normal permissions.

The sandbox does not bind-mount your full home directory: its project filesystem access is limited to the selected worktree, the repository Git metadata, and the explicitly mounted Claude, SSH, and GPG configuration. Claude Code itself documents that `--dangerously-skip-permissions` skips permission prompts and should be used with caution: [CLI reference](https://docs.anthropic.com/en/docs/claude-code/cli-usage).

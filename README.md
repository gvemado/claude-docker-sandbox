# Copilot Docker Sandbox

This repo contains a small Docker sandbox launcher for GitHub Copilot CLI.

## What it does

- Builds from `docker/sandbox-templates:copilot`
- Starts quickly by bind-mounting a host-side git worktree instead of rebuilding a project snapshot every run
- Creates or reuses one managed worktree per branch, so you can run multiple containers on different branches at the same time
- Preserves your current subdirectory when that same path exists in the target branch
- Mounts the worktree and the repo's common git directory at the same absolute paths inside the container so git commands keep working
- Bind-mounts `~/.copilot` into `/home/agent/.copilot` so your Copilot settings are shared, not baked into the image
- Mounts your host `~/.ssh` read-only and stages `id_rsa` into `/home/agent/.ssh` for GitHub SSH access inside the container
- Installs the OpenSSH client so Git can use your staged SSH key for fetch/push operations
- Mounts your host `~/.gnupg` read-only and stages it into `/home/agent/.gnupg` so GPG signing can use your existing keys
- Exposes both `uv` and `uvx` inside the container for tools like `uvx mcp-atlassian`
- Starts `copilot --yolo` inside the container

## Usage

Run the launcher from anywhere inside a git repository:

```bash
/Users/gvemado/Projects/copilot-sandbox/copilot-yolo-sandbox
```

The script prompts for a branch name. If the branch already has a managed worktree and no container is using it, it reuses it. If the branch does not exist yet, it creates a new branch and a new worktree for it.

If you want to call it by name from anywhere, put it on your `PATH`, for example:

```bash
ln -s /Users/gvemado/Projects/copilot-sandbox/copilot-yolo-sandbox /usr/local/bin/copilot-yolo-sandbox
```

Then use it from any repo:

```bash
cd /path/to/project
copilot-yolo-sandbox
```

You can also skip the prompt:

```bash
copilot-yolo-sandbox --branch feature/my-task
```

Any extra arguments are forwarded to `copilot` after `--yolo`:

```bash
copilot-yolo-sandbox --branch feature/my-task -- --continue
```

## Notes

- Worktrees are stored under `~/.local/share/copilot-yolo/worktrees` by default. Override that with `COPILOT_SANDBOX_WORKTREE_ROOT` if you want them somewhere else.
- When the container exits, the launcher removes the managed worktree automatically if it is clean. If it still has uncommitted changes, the worktree is left in place to avoid losing work.
- The image is rebuilt only when it does not exist yet, or when you pass `--rebuild`.
- The launcher requires that you run it inside a git repository.
- `~/.copilot` is mounted from your host machine, so login state and settings are reused.
- Set `COPILOT_SANDBOX_IMAGE` if you want to override the generated image tag.

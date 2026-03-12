---
name: restart-dev-3000
description: Resolve local Next.js dev startup conflicts by freeing port 3000, terminating stale `next dev` processes in the current project, clearing stale `.next/dev/lock`, and starting `npm run dev`. Use when the user asks things like "3000で起動して", "lock エラーを直して", "port 3000 is in use", "Unable to acquire lock", or requests automatic dev-server restart.
---

# Restart Dev 3000

## Overview

Recover local dev startup quickly by cleaning conflicting processes and lock files, then launching `npm run dev` in the current project.

## Workflow

1. Run `scripts/restart_dev.sh` from the target project directory.
2. Confirm that the script kills listeners on `PORT` (default `3000`) and stale `next dev` processes tied to the current directory.
3. Confirm that the script removes stale `.next/dev/lock` only when no related process remains.
4. Let the script execute `npm run dev` (or a custom command).

## Commands

Run default behavior (port `3000`, command `npm run dev`):

```bash
~/.codex/skills/restart-dev-3000/scripts/restart_dev.sh
```

Run with explicit port:

```bash
~/.codex/skills/restart-dev-3000/scripts/restart_dev.sh --port 3000
```

Run with custom dev command:

```bash
~/.codex/skills/restart-dev-3000/scripts/restart_dev.sh -- npm run dev
```

## Notes

- Run inside the project directory that should be started.
- Prefer this script before manually repeating `npm run dev` when lock errors appear.
- Expect this script to terminate existing dev servers in the same project and any process listening on the target port.

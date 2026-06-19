# Codex external editor issue

Date: 2026-06-15

## Event

Codex showed the following error when trying to open an external editor:

```text
Cannot open external editor: set $VISUAL or $EDITOR before starting Codex.
```

## Cause

Codex requires either `VISUAL` or `EDITOR` to be set before Codex starts.
In this environment, neither variable was set early enough for every Codex launch path.

The first fix added the variables to `.zshrc` and `.bashrc`, which works for interactive shells.
However, Codex can be started from a login/non-interactive zsh command such as `zsh -lc`.
That path does not read `.zshrc`, so Codex could still start without the editor variables.

## Fix

The WSL shell startup files were updated to set both variables.

The primary zsh fix is:

- `wsl/.zshenv`

This file is linked to:

- `~/.zshenv`

The installer was also updated to link `wsl/.zshenv` on future machines.

Interactive shell coverage remains in:

- `wsl/.bashrc`

The configured editor is:

```sh
VISUAL=nvim
EDITOR=nvim
```

If `nvim` is not available, the configuration falls back to `vim`.

## Policy Check

This matches the current dotfiles policy because the repository keeps real configuration files under `wsl/` and links them into the home directory.

`.zshenv` is appropriate for variables that must exist before `.zshrc` is loaded.
This is important for Codex because the editor process inherits the environment from the Codex process at Codex startup time.

## Verification

Clean zsh startup paths were checked:

```text
VISUAL=nvim
EDITOR=nvim
```

Verified paths:

- `env -i ... zsh -lc ...`
- `env -i ... zsh -ic ...`

## Operational Note

An already-running Codex process will not pick up the new environment variables.
Exit Codex completely and start it again from a new shell.

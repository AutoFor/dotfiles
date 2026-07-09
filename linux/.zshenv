# Environment variables that must exist before shell startup files such as
# .zshrc are loaded.
if command -v nvim >/dev/null 2>&1; then
  export VISUAL=nvim
  export EDITOR=nvim
elif command -v vim >/dev/null 2>&1; then
  export VISUAL=vim
  export EDITOR=vim
fi

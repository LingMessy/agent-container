function proxyenv() {
  local proxyfile="$HOME/set-proxy.sh"

  if [[ ! -f "$proxyfile" ]]; then
    echo "proxyenv: set-proxy.sh not found: $proxyfile" >&2
    return 1
  fi

  bash -c '
    set -a
    source "$1"
    set +a
    exec "${@:2}"
  ' _ "$proxyfile" "$@"
}

# 解决 corepack 的 pnpm setup 报错
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac

alias codex-api='CODEX_HOME="$HOME/.codex-api" proxyenv codex'

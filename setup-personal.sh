#!/usr/bin/env bash
# ============================================================
#  setup-personal.sh
#  Bootstraps a personal machine for working with Flow DS.
#  Installs: mise, Node.js (via mise), npm, Claude Code, and
#  Flow Builder skills.
#  Supports: macOS and Linux.
#
#  Usage:
#    curl -fsSL <url>/setup-flow.sh | bash
#    # or
#    bash setup-flow.sh
# ============================================================

# -- Config --------------------------------------------------

NODE_VERSION="${NODE_VERSION:-lts}"

# -- Helpers -------------------------------------------------

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
info() { printf "\033[36m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[33m!!\033[0m %s\n" "$*"; }
ok()   { printf "\033[32mok\033[0m %s\n" "$*"; }
die()  { printf "\033[31mxx\033[0m %s\n" "$*" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      die "Unsupported OS: $(uname -s). This script supports macOS and Linux." ;;
  esac
}

detect_shell_rc() {
  case "$(basename "${SHELL:-bash}")" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash)
      if [[ "$(uname -s)" == "Darwin" ]]; then echo "$HOME/.bash_profile"
      else echo "$HOME/.bashrc"; fi
      ;;
    fish) echo "$HOME/.config/fish/config.fish" ;;
    *)    echo "$HOME/.profile" ;;
  esac
}

# -- Steps ---------------------------------------------------

install_prereqs_macos() {
  if ! has brew; then
    info "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if   [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew    ]]; then eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    ok "Homebrew already installed"
  fi
  has git  || brew install git
  has curl || brew install curl
}

install_prereqs_linux() {
  if has apt-get; then
    info "Installing prerequisites via apt"
    sudo apt-get update -y
    sudo apt-get install -y curl git build-essential ca-certificates
  elif has dnf; then
    sudo dnf install -y curl git gcc-c++ make ca-certificates
  elif has pacman; then
    sudo pacman -Sy --noconfirm curl git base-devel ca-certificates
  else
    warn "No known package manager found. Ensure curl and git are installed."
  fi
}

install_mise() {
  if has mise; then
    ok "mise already installed ($(mise --version))"
  else
    info "Installing mise"
    if [[ "$(detect_os)" == "macos" ]] && has brew; then
      brew install mise
    else
      curl -fsSL https://mise.run | sh
      export PATH="$HOME/.local/bin:$PATH"
    fi
  fi

  # Put shims on PATH for this session
  export PATH="$HOME/.local/share/mise/shims:$PATH"

  # Add shell activation to rc file if missing
  local rc shell_name activate_line
  rc="$(detect_shell_rc)"
  shell_name="$(basename "${SHELL:-bash}")"

  if [[ "$shell_name" == "fish" ]]; then
    activate_line="mise activate fish | source"
  else
    activate_line="eval \"\$(mise activate ${shell_name})\""
  fi

  if [[ -f "$rc" ]] && ! grep -q "mise activate" "$rc"; then
    info "Adding mise activation to $rc"
    printf '\n# mise\n%s\n' "$activate_line" >> "$rc"
  fi
}

install_node() {
  info "Installing Node.js ($NODE_VERSION) via mise"
  mise use -g "node@${NODE_VERSION}"
  ok "Node $(mise exec -- node -v) / npm $(mise exec -- npm -v)"
}

install_claude_code() {
  info "Installing/updating Claude Code"
  mise exec -- npm install -g @anthropic-ai/claude-code
  ok "Claude Code ready"
}

configure_flow_registry() {
  info "Configuring npm registry for @flow/* packages"
  mise exec -- npm config set @flow:registry https://sgts.gitlab-dedicated.com/api/v4/projects/60257/packages/npm/

  local registry
  registry="$(mise exec -- npm config get @flow:registry 2>/dev/null || echo '')"
  if [[ "$registry" == "https://sgts.gitlab-dedicated.com/api/v4/projects/60257/packages/npm/" ]]; then
    ok "@flow/* packages will be fetched from ${registry}"
  else
    warn "Registry was set but could not be verified — got: ${registry:-empty}"
  fi
}

install_flow_skills() {
  info "Installing Flow Builder skills for Claude Code"
  info "This installs skills to ~/.claude/ so they work across all your projects."

  if ! mise exec -- npx -y @flow/builder@latest install --user </dev/null; then
    if ! mise exec -- npm ping --registry https://sgts.gitlab-dedicated.com/api/v4/projects/60257/packages/npm/ &>/dev/null 2>&1; then
      die "Could not install Flow Builder — the @flow registry is not reachable. Check your network connection and try again."
    else
      die "Flow Builder installer exited with an error. Try manually: npx -y @flow/builder@latest install --user"
    fi
  fi

  # Verify expected outputs
  local verify_pass=true

  if [[ -d "$HOME/.claude/skills/flow-build" && -d "$HOME/.claude/skills/flow-setup" ]]; then
    ok "Skills installed to ~/.claude/skills/"
  else
    warn "Skill folders not found at ~/.claude/skills/ — the installer may have failed silently."
    verify_pass=false
  fi

  if [[ -f "$HOME/.claude.json" ]] && node -e "
    const c = JSON.parse(require('fs').readFileSync('$HOME/.claude.json','utf8'));
    process.exit(c.mcpServers && c.mcpServers['flow-builder'] ? 0 : 1);
  " 2>/dev/null; then
    ok "MCP server configured in ~/.claude.json"
  else
    warn "MCP server entry 'flow-builder' not found in ~/.claude.json"
    verify_pass=false
  fi

  if [[ "$verify_pass" == false ]]; then
    info "The installer ran but some expected outputs are missing."
    info "Open Claude Code and type /flow-build to check if skills loaded correctly."
  fi
}

post_install_hint() {
  bold ""
  bold "Done."
  cat <<EOF

Next steps:

  1. Open a new terminal (or: source $(detect_shell_rc)) so mise shims are on PATH.
  2. Run \`claude\` to authenticate and start Claude Code.
  3. Use \`/flow-setup\` and \`/flow-build\` inside Claude Code to start building.
  4. Verify: \`node -v\`, \`npm -v\`, \`claude --version\`, \`mise ls\`.

EOF
}

# -- Main ----------------------------------------------------

main() {
  set -euo pipefail

  bold "Flow setup: mise + Node + Claude Code"
  OS="$(detect_os)"
  info "Detected OS: $OS"

  case "$OS" in
    macos) install_prereqs_macos ;;
    linux) install_prereqs_linux ;;
  esac

  install_mise
  install_node
  install_claude_code
  configure_flow_registry
  install_flow_skills
  post_install_hint
}

main "$@"

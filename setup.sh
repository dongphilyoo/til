#!/bin/bash
# setup.sh — One-time setup for TIL
set -euo pipefail

TIL_REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.til"
CONFIG_FILE="$CONFIG_DIR/config"

echo "📝 TIL Setup"
echo "============"
echo ""

# --- Check dependencies ---
MISSING=()

if ! command -v claude &>/dev/null; then
  MISSING+=("claude CLI (install from https://docs.anthropic.com/en/docs/claude-code)")
fi

if ! command -v brew &>/dev/null; then
  MISSING+=("Homebrew (install from https://brew.sh)")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "❌ Missing required dependencies:"
  for dep in "${MISSING[@]}"; do
    echo "   - $dep"
  done
  echo ""
  echo "Install these first, then re-run setup.sh"
  exit 1
fi

echo "✅ claude CLI found"
echo "✅ Homebrew found"

# --- Install yt-dlp ---
if command -v yt-dlp &>/dev/null; then
  echo "✅ yt-dlp already installed"
else
  echo "📦 Installing yt-dlp..."
  brew install yt-dlp
  echo "✅ yt-dlp installed"
fi

# --- Install trafilatura ---
if command -v trafilatura &>/dev/null; then
  echo "✅ trafilatura already installed"
else
  echo "📦 Installing trafilatura..."
  if command -v pipx &>/dev/null; then
    pipx install trafilatura
  else
    echo "   pipx not found, installing via Homebrew first..."
    brew install pipx
    pipx ensurepath
    pipx install trafilatura
  fi
  echo "✅ trafilatura installed"
fi

# --- Create config ---
echo ""
if [ -f "$CONFIG_FILE" ]; then
  echo "⚙️  Config already exists at $CONFIG_FILE"
  source "$CONFIG_FILE"
  echo "   VAULT_DIR=$VAULT_DIR"
  echo "   TIL_FOLDER=${TIL_FOLDER:-3-Resources/TIL}"
  read -rp "Overwrite? [y/N] " OVERWRITE
  if [[ ! "$OVERWRITE" =~ ^[Yy] ]]; then
    echo "   Keeping existing config."
    SKIP_CONFIG=true
  fi
fi

if [ "${SKIP_CONFIG:-}" != "true" ]; then
  echo "⚙️  Setting up config..."
  echo ""

  # Find Obsidian vaults in the default iCloud location
  ICLOUD_OBSIDIAN="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
  if [ -d "$ICLOUD_OBSIDIAN" ]; then
    echo "   Found Obsidian vaults in iCloud:"
    VAULTS=()
    while IFS= read -r -d '' vault; do
      VAULTS+=("$vault")
      echo "   $((${#VAULTS[@]})) $(basename "$vault")"
    done < <(find "$ICLOUD_OBSIDIAN" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    echo ""
  fi

  read -rp "   Vault path (paste full path or pick a number above): " VAULT_INPUT

  # Handle numeric selection
  if [[ "$VAULT_INPUT" =~ ^[0-9]+$ ]] && [ -n "${VAULTS:-}" ] && [ "$VAULT_INPUT" -le "${#VAULTS[@]}" ] && [ "$VAULT_INPUT" -ge 1 ]; then
    VAULT_DIR="${VAULTS[$((VAULT_INPUT - 1))]}"
  else
    VAULT_DIR="$VAULT_INPUT"
  fi

  # Expand ~ if present
  VAULT_DIR="${VAULT_DIR/#\~/$HOME}"

  if [ ! -d "$VAULT_DIR" ]; then
    echo "   ⚠️  Directory doesn't exist: $VAULT_DIR"
    read -rp "   Create it? [Y/n] " CREATE
    if [[ "$CREATE" =~ ^[Nn] ]]; then
      echo "   Aborting."
      exit 1
    fi
    mkdir -p "$VAULT_DIR"
  fi

  read -rp "   TIL folder within vault [3-Resources/TIL]: " TIL_FOLDER
  TIL_FOLDER="${TIL_FOLDER:-3-Resources/TIL}"

  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_FILE" <<EOF
# TIL config
VAULT_DIR="$VAULT_DIR"
TIL_FOLDER="$TIL_FOLDER"
EOF

  echo "✅ Config saved to $CONFIG_FILE"
fi

# --- Add bin to PATH ---
BIN_DIR="$TIL_REPO_DIR/bin"
SHELL_RC="$HOME/.zshrc"

if grep -q "$BIN_DIR" "$SHELL_RC" 2>/dev/null; then
  echo "✅ $BIN_DIR already in PATH"
else
  echo "" >> "$SHELL_RC"
  echo "# TIL" >> "$SHELL_RC"
  echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC"
  echo "✅ Added $BIN_DIR to PATH in ~/.zshrc"
  echo "   Run 'source ~/.zshrc' or open a new terminal to use 'til'"
fi

# --- Verify ---
echo ""
echo "🎉 Setup complete!"
echo ""
echo "Usage:"
echo "  til                          Copy a URL, then run til"
echo "  til <youtube-url>            YouTube video"
echo "  til <article-url>            Web article"
echo "  til -t \"Title\"               Text from clipboard"
echo ""
echo "Notes will be saved to: $VAULT_DIR/$TIL_FOLDER/"

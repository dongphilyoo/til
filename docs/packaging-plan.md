# Packaging TIL for Distribution

## Goal
Share the `til` workflow with wife and coworkers who use Claude Pro/Max + Obsidian on Mac.

## Scope
- **Not** a public open source product for wide adoption
- Small audience: ~5-20 people, all on Mac, all Claude subscribers, all Obsidian users
- Public GitHub repo for easy access (nothing sensitive in the code)

## Done

### 1. Standalone repo
TIL extracted from cortex into its own repo (`dongphilyoo/til`). Cortex remains the personal second brain base.

### 2. Config file (~/.til/config)
Extracted hardcoded values so each user sets their own:
- `VAULT_DIR` — path to Obsidian vault
- `TIL_FOLDER` — folder within vault (default: `3-Resources/TIL`)

### 3. setup.sh
One-time install script that:
- Checks for `claude` CLI and Homebrew
- Installs `yt-dlp` via Homebrew
- Installs `trafilatura` via pipx
- Auto-discovers Obsidian vaults in iCloud
- Creates `~/.til/config` interactively
- Adds `til/bin` to PATH

### 4. GitHub repo structure
```
til/
├── bin/
│   └── til
├── til.sh
├── setup.sh
├── docs/
│   ├── obsidian-primer.md
│   └── packaging-plan.md
├── CLAUDE.md
├── README.md
├── LICENSE            ← MIT
└── .gitignore
```

### 5. README.md
- What it does (one paragraph)
- Prerequisites: Mac, Claude Pro or higher, Obsidian
- Install: clone + run setup.sh
- Usage: `til` commands with examples
- Note format explanation

## What Stays the Same
- Bash — no rewrite needed for this scope
- macOS only (pbpaste)
- Claude Code CLI (`claude -p`) for summarization
- yt-dlp + trafilatura for content extraction

## Dependencies
All installable via the setup script:
- `claude` CLI (user must have Pro or higher subscription + be logged in)
- `yt-dlp` (Homebrew)
- `trafilatura` (pipx)
- `python3` (pre-installed on macOS)

## Not Doing (Yet)
- Cross-platform support
- Multi-LLM support
- Homebrew tap / npm package
- Configurable note templates
- Team shared vaults

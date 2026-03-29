# TIL

> Read less. Remember more. Your Obsidian knowledge engine.

Turn YouTube videos, articles, and text into structured notes in your Obsidian vault — powered by Claude.

<div align="center">

https://github.com/user-attachments/assets/17fcf06c-46c5-4dba-8267-a8a0b90b7e98

</div>

Copy a URL, run `til`, and get a detailed TIL note with a TL;DR, key takeaways, concepts, connections, and relevant external links — ready to browse in Obsidian. Works with videos of any length — long transcripts are automatically chunked and summarized using map-reduce.

## Prerequisites

- **Mac** (macOS)
- **Claude Pro or higher** — uses the `claude` CLI, no API key needed
- **Obsidian** — notes are saved as markdown files in your vault

## Install

```bash
git clone https://github.com/dongphilyoo/til.git
cd til
./setup.sh
```

The setup script will:
- Install `yt-dlp` (YouTube transcripts, English & Korean) and `trafilatura` (article extraction) via Homebrew
- Ask for your Obsidian vault path
- Add `til` to your PATH

After setup, restart your terminal or run `source ~/.zshrc`.

## Usage

```bash
# Auto-detect — copy a URL to clipboard, then:
til

# YouTube video
til https://www.youtube.com/watch?v=dQw4w9WgXcQ

# Web article
til https://example.com/interesting-article

# Text from clipboard (manual title)
til -t "Meeting Notes"

# Text from clipboard (auto-generated title)
til -t

# Text from file
til -t "Research Paper" < paper.txt
```

## Note Format

Each note is saved to your vault's TIL folder with this structure:

1. **TL;DR** — 2-3 sentence summary
2. **Key Takeaways** — the important bits
3. **Key Concepts** — main ideas with explanations
4. **Connections** — Obsidian `[[wikilinks]]` to related topics
5. **Detailed Summary** — thorough deep-dive
6. **Source Notes** — quotes, timestamps, references, and relevant external links

Notes include frontmatter with metadata (source, date with timezone, type, tags) for Obsidian's graph view and search.

## Config

Config lives at `~/.til/config` (created by `setup.sh`):

```bash
VAULT_DIR="/path/to/your/obsidian/vault"
TIL_FOLDER="3-Resources/TIL"
```

### Finding your vault path

Your Obsidian vault is just a folder on your Mac. If you use iCloud sync (the default), it's at:

```
~/Library/Mobile Documents/iCloud~md~obsidian/Documents/<Your Vault Name>/
```

For example, if your vault is called "Notes":
```bash
VAULT_DIR="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notes"
```

> `setup.sh` auto-detects iCloud vaults and lets you pick one — you don't need to type this manually.

If your vault isn't in iCloud, right-click the vault name in Obsidian's sidebar → "Reveal in Finder" to find the path.

### Vault folder structure

TIL saves notes to `VAULT_DIR/TIL_FOLDER/`. You can set `TIL_FOLDER` to any subfolder — it will be created automatically if it doesn't exist.

**Example: Simple vault**
```
My Notes/           ← VAULT_DIR
└── TIL/            ← TIL_FOLDER="TIL"
```

**Example: PARA method** (recommended for building a second brain)
```
My Notes/           ← VAULT_DIR
├── 0-Inbox/        ← quick captures, unsorted
├── 1-Projects/     ← active projects with deadlines
├── 2-Areas/        ← ongoing life areas (health, career, finance)
├── 3-Resources/    ← reference material
│   └── TIL/        ← TIL_FOLDER="3-Resources/TIL"
├── 4-Archive/      ← completed/inactive
└── Templates/
```

The default `TIL_FOLDER` is `3-Resources/TIL` (PARA style). If you just want a top-level `TIL/` folder, set:

```bash
TIL_FOLDER="TIL"
```

### What TIL notes look like in Obsidian

Each note has YAML frontmatter that Obsidian reads as metadata:

```yaml
---
title: "How Transformers Work"
source: https://www.youtube.com/watch?v=...
channel: 3Blue1Brown
date: 2026-03-29T10:30:00+09:00
published: 2026-03-15
type: youtube
tags: [machine-learning, transformers, neural-networks]
---
```

This enables:
- **Search** by type, tags, date, or source
- **Graph view** — `[[wikilinks]]` in the Connections section link your notes together
- **Dataview queries** (optional plugin) — e.g., "show all YouTube TILs from this week"

## License

MIT

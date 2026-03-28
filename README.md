# TIL

> Read less. Remember more. Your Obsidian knowledge engine.

Turn YouTube videos, articles, and text into structured notes in your Obsidian vault — powered by Claude.

<div align="center">
  <video src="https://github.com/dongphilyoo/til/releases/download/v0.1.0/demo.mp4" width="720"></video>
</div>

Copy a URL, run `til`, and get a detailed TIL note with a TL;DR, key takeaways, concepts, and connections, ready to browse in Obsidian.

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
- Install `yt-dlp` (YouTube transcripts) and `trafilatura` (article extraction) via Homebrew
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
6. **Source Notes** — quotes, timestamps, references

Notes include frontmatter with metadata (source, date, type, tags) for Obsidian's graph view and search.

## Config

Config lives at `~/.til/config`:

```bash
VAULT_DIR="/path/to/your/obsidian/vault"
TIL_FOLDER="3-Resources/TIL"    # folder within vault for TIL notes
```

## License

MIT

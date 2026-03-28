# TIL

CLI tool that turns YouTube videos, articles, and text into structured Obsidian notes using Claude.

## Structure
```
til/
├── bin/
│   └── til              ← wrapper on PATH, handles zsh & in URLs
├── til.sh               ← main TIL pipeline script
├── setup.sh             ← one-time install script
├── .transcripts/        ← temp transcript storage (auto-cleaned)
└── docs/
    ├── obsidian-primer.md
    └── packaging-plan.md
```

## Config
- Lives at `~/.til/config`
- `VAULT_DIR` — path to user's Obsidian vault
- `TIL_FOLDER` — folder within vault for TIL notes (default: `3-Resources/TIL`)

## TIL Command
- `til` — auto-detect clipboard URL (YouTube or article)
- `til <video-id>` — YouTube by video ID
- `til <url>` — YouTube or article (auto-detected)
- `til -t "Title"` — clipboard text (manual)
- `til -t "Title" < file.txt` — text from file
- Uses `claude -p` (CLI, no API cost) for summarization
- Uses `yt-dlp` for YouTube transcripts
- Uses `trafilatura` for article content extraction

## Note Format (priority order for reading)
1. TL;DR
2. Key Takeaways
3. Key Concepts
4. Connections (wikilinks)
5. --- (divider)
6. Detailed Summary (deep dive, read if needed)
7. Source Notes

## Frontmatter Properties
- YouTube notes: title, source, channel, date, video_date (Date type), type: youtube, tags
- Article notes: title, source, date, article_date (Date type, "unknown" if unavailable), type: article, tags
- Text notes: title, source (manual), date, type: note, tags

## Principles
- Claude Code is the summarization engine — no API usage, everything runs through the CLI
- Notes should be detailed and academically rigorous, but written in plain, accessible language
- Obsidian-native: use wikilinks, tags, and folder structure that Obsidian understands
- Minimize friction: commands should be fast to type with sensible defaults

# Obsidian Primer

## What Obsidian Is

Obsidian is a note-taking app where **your vault is just a folder of markdown files**. No database, no proprietary format. Every note is a `.md` file on your filesystem. This is why it pairs so well with Claude Code — we can read, write, search, and organize your notes directly.

## Core Concepts

### 1. Vault = Folder
Your vault at `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Cortex/` is literally a folder (synced via iCloud). Every subfolder becomes a folder in Obsidian's file explorer. You can organize however you want:

```
Cortex/                     ← iCloud-synced vault
├── .obsidian/              ← settings, plugins, themes (auto-managed)
├── 0-Inbox/                ← quick captures, unsorted notes
├── 1-Projects/             ← active projects with deadlines
├── 2-Areas/                ← ongoing life areas (health, career, finance)
├── 3-Resources/            ← reference material
│   └── TIL/                ← YouTube/article summaries
├── 4-Archive/              ← completed/inactive projects
├── Journal/                ← daily notes, reflections
└── Templates/              ← reusable note templates
```

### 2. Markdown + Extras
Notes are standard markdown with Obsidian-specific extensions:
- **Wikilinks**: `[[Note Name]]` links to another note. This is how you build connections.
- **Tags**: `#tag` anywhere in a note, or in frontmatter as `tags: [til, physics]`
- **Frontmatter**: YAML at the top of a note between `---` fences. Obsidian reads this as metadata.

```markdown
---
title: How Gravity Works
tags: [til, physics, youtube]
source: https://youtube.com/...
date: 2026-03-28
---

# How Gravity Works

Content here. Link to [[General Relativity]] for deeper reading.
```

### 3. Graph View (The Visual Superpower)
Every wikilink creates a connection. Obsidian visualizes these as an interactive **graph** — nodes are notes, edges are links. For a visual learner, this is where it clicks: you literally *see* how your knowledge connects across subjects.

The more you link notes to each other, the richer this graph becomes.

### 4. Tags vs Folders vs Links

| Method | Best for | Example |
|--------|----------|---------|
| **Folders** | Broad categories, workflow stages | `TIL/`, `Projects/`, `Journal/` |
| **Tags** | Cross-cutting topics, searchability | `#physics`, `#machine-learning` |
| **Links** | Meaningful connections between ideas | `[[General Relativity]]` mentioned in a quantum gravity note |

**Rule of thumb**: folders for *where* a note lives, tags for *what* it's about, links for *how* ideas connect.

### 5. Templates
Obsidian has a core Templates plugin. You put template files in a `Templates/` folder, then insert them into new notes. We'll create templates for TIL notes, project notes, etc.

### 6. Daily Notes
A built-in feature that creates one note per day (e.g., `2026-03-28.md`). Great for journaling, logging what you learned, or capturing fleeting ideas.

### 7. Community Plugins (Optional, Later)
Obsidian has a plugin ecosystem. Some relevant ones:
- **Dataview**: query your notes like a database (e.g., "show all TIL notes tagged #physics from this month")
- **Calendar**: visual calendar linked to daily notes
- **Templater**: advanced templates with dynamic variables

Don't install anything yet — start with the basics and add plugins when you feel a real need.

## How Claude Code Interacts With Your Vault

Since the vault is just files:
- **Create notes**: Write markdown files directly
- **Search notes**: Grep through your vault for any topic
- **Update notes**: Edit existing notes to add links, fix tags
- **Organize**: Move files between folders, batch-rename, restructure
- **Analyze**: Read your graph of connections and suggest missing links

No API, no plugins needed. Just file operations.

## Recommended Starting Structure

For your second brain, the **PARA method** (Projects, Areas, Resources, Archive) is a proven framework:

This is already set up in your Cortex vault (iCloud-synced). See the folder structure at the top of this document.

This is just a starting point — we'll adapt it to how you actually work.

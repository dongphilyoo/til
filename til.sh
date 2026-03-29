#!/bin/bash
# til — Capture knowledge into Obsidian from YouTube videos or text
#
# Usage:
#   til <youtube-url>                          ← YouTube video
#   til -t ["Title"] [--url <source>]           ← paste text interactively, ctrl+D to finish
#   pbpaste | til -t ["Title"] [--url <source>] ← from clipboard
#   til -t ["Title"] < file.txt                 ← from file

set -euo pipefail

# --- Load config ---
TIL_CONFIG="${TIL_CONFIG:-$HOME/.til/config}"
if [ ! -f "$TIL_CONFIG" ]; then
  echo "❌ Config not found: $TIL_CONFIG"
  echo "   Run setup.sh first, or create ~/.til/config with:"
  echo "     VAULT_DIR=/path/to/your/obsidian/vault"
  echo "     TIL_FOLDER=3-Resources/TIL"
  exit 1
fi
source "$TIL_CONFIG"

# Validate required config
if [ -z "${VAULT_DIR:-}" ]; then
  echo "❌ VAULT_DIR not set in $TIL_CONFIG"
  exit 1
fi

TIL_FOLDER="${TIL_FOLDER:-3-Resources/TIL}"
TIL_DIR="$VAULT_DIR/$TIL_FOLDER"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TRANSCRIPT_DIR="$SCRIPT_DIR/.transcripts"
TODAY=$(date +%Y-%m-%dT%H:%M:%S%z | sed 's/\(..\)$/:\1/')
TODAY_DATE=$(date +%Y-%m-%d)

mkdir -p "$TIL_DIR" "$TRANSCRIPT_DIR"

# --- Progress UI ---
# Estimated durations per step (seconds) — used to fake smooth progress
# YouTube: metadata=8, transcript=15, summarize=60, save=1
# Text: summarize=45, save=1
SPINNER_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
BAR_WIDTH=20
PROGRESS_PID=""

# Start an animated progress bar for a step
# Usage: progress_start "Step label" <estimated_seconds>
progress_start() {
  local msg=$1
  local est=$2

  # Stop previous bar if running
  progress_stop

  printf "\n⏳ %s\n" "$msg"

  # Background process: animate bar from 0% to ~90% over estimated time, then hold
  (
    start=$(date +%s)
    i=0
    while true; do
      now=$(date +%s)
      elapsed=$((now - start))
      # Ease towards 90% over estimated time, never hit 100%
      if [ "$elapsed" -ge "$est" ]; then
        pct=90
      else
        pct=$((elapsed * 90 / est))
      fi
      filled=$((pct * BAR_WIDTH / 100))
      empty=$((BAR_WIDTH - filled))
      bar=$(printf '█%.0s' $(seq 1 $filled 2>/dev/null))
      [ "$empty" -gt 0 ] && bar="${bar}$(printf '░%.0s' $(seq 1 $empty))"
      spinner="${SPINNER_CHARS:$((i % ${#SPINNER_CHARS})):1}"
      printf "\r\033[K  [%s] %d%%  %s %ds" "$bar" "$pct" "$spinner" "$elapsed"
      sleep 0.15
      i=$((i + 1))
    done
  ) &
  PROGRESS_PID=$!
}

# Stop the progress bar and show 100% complete
# Usage: progress_stop ["Done message"]
progress_stop() {
  if [ -n "$PROGRESS_PID" ] && kill -0 "$PROGRESS_PID" 2>/dev/null; then
    kill "$PROGRESS_PID" 2>/dev/null
    wait "$PROGRESS_PID" 2>/dev/null || true
    PROGRESS_PID=""
  fi
}

progress_complete() {
  local msg=${1:-"Done"}
  progress_stop
  local bar=$(printf '█%.0s' $(seq 1 $BAR_WIDTH))
  printf "\r\033[K  [%s] 100%% ✓\n" "$bar"
}

# Cleanup on exit
trap 'progress_stop' EXIT

# --- Helper: clean claude output ---
# Strips code fences and any preamble/postamble that claude sometimes adds
clean_claude_output() {
  local file="$1"
  python3 -c "
import re, sys
text = open(sys.argv[1]).read()
# Extract content from markdown code fence if present
m = re.search(r'\`\`\`(?:markdown)?\s*\n(.*?)\n\`\`\`', text, re.DOTALL)
if m:
    text = m.group(1)
# Strip anything before the first --- (frontmatter start)
m = re.search(r'^(---\s*\n.*)', text, re.DOTALL | re.MULTILINE)
if m:
    text = m.group(1)
open(sys.argv[1], 'w').write(text.strip() + '\n')
" "$file"
}

# --- Helper: extract video ID from various YouTube URL formats ---
extract_video_id() {
  local input="$1"
  local vid=""
  # Already a bare ID
  if [[ "$input" =~ ^[a-zA-Z0-9_-]{8,15}$ ]]; then
    vid="$input"
  # https://www.youtube.com/watch?v=ID or https://youtube.com/watch?v=ID
  elif echo "$input" | grep -qE '(youtube\.com|youtu\.be)'; then
    vid=$(echo "$input" | sed -nE 's/.*[?&]v=([a-zA-Z0-9_-]+).*/\1/p')
    # https://youtu.be/ID
    if [ -z "$vid" ]; then
      vid=$(echo "$input" | sed -nE 's/.*youtu\.be\/([a-zA-Z0-9_-]+).*/\1/p')
    fi
  fi
  echo "$vid"
}

# --- Parse args ---
MODE=""
TITLE=""
SOURCE_URL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--text)
      MODE="text"
      # Title is optional — if next arg looks like a flag or is missing, skip it
      if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
        TITLE="$2"
        shift 2
      else
        TITLE=""
        shift 1
      fi
      ;;
    --url)
      SOURCE_URL="$2"
      shift 2
      ;;
    -h|--help)
      echo "til — Capture knowledge into your Obsidian vault"
      echo ""
      echo "Usage:"
      echo "  til                                          Auto-detect clipboard URL (YouTube or article)"
      echo "  til <video-id>                               YouTube by video ID"
      echo "  til <url>                                    YouTube or article (auto-detected)"
      echo "  til -t \"Title\"                               Text from clipboard (manual)"
      echo "  til -t                                       Text from clipboard (auto-title)"
      echo "  til -t \"Title\" < file.txt                    Text from file"
      echo ""
      echo "Options:"
      echo "  -t, --text [title]   Text mode — reads from clipboard by default. Title auto-generated if omitted"
      echo "  -h, --help           Show this help"
      echo ""
      echo "Examples:"
      echo "  til                                          Copy any URL, then just run til"
      echo "  til pzUn9wTCgcw                              YouTube video ID"
      echo "  til https://example.com/some-article         Article URL"
      echo "  til -t \"Meeting Notes\"                       Clipboard text, manual title"
      echo "  til -t                                       Clipboard text, auto-generated title"
      echo "  til -t \"Research Paper\" < paper.txt          Text file"
      echo ""
      echo "Notes are saved to: $TIL_DIR/"
      exit 0
      ;;
    *)
      # Check if it's a YouTube video ID or URL
      VIDEO_ID=$(extract_video_id "$1")
      if [ -n "$VIDEO_ID" ]; then
        MODE="youtube"
        SOURCE_URL="https://www.youtube.com/watch?v=$VIDEO_ID"
      # Non-YouTube URL — treat as article
      elif [[ "$1" =~ ^https?:// ]]; then
        MODE="article"
        SOURCE_URL="$1"
      else
        echo "❌ Unrecognized argument: $1"
        echo "   Run 'til --help' for usage."
        exit 1
      fi
      shift
      ;;
  esac
done

# If no mode set, try clipboard for a URL (YouTube or article)
if [ -z "$MODE" ]; then
  CLIPBOARD=$(pbpaste 2>/dev/null)
  VIDEO_ID=$(extract_video_id "$CLIPBOARD")
  if [ -n "$VIDEO_ID" ]; then
    MODE="youtube"
    SOURCE_URL="https://www.youtube.com/watch?v=$VIDEO_ID"
  elif [[ "$CLIPBOARD" =~ ^https?:// ]]; then
    MODE="article"
    SOURCE_URL="$CLIPBOARD"
  else
    echo "❌ No input provided and clipboard doesn't contain a URL."
    echo "   Run 'til --help' for usage."
    exit 1
  fi
fi

# --- YouTube mode ---
if [ "$MODE" = "youtube" ]; then
  progress_start "Fetching video metadata..." 8
  TITLE=$(yt-dlp --no-download --print "%(title)s" "$SOURCE_URL" 2>/dev/null)
  CHANNEL=$(yt-dlp --no-download --print "%(channel)s" "$SOURCE_URL" 2>/dev/null)
  VIDEO_DATE_RAW=$(yt-dlp --no-download --print "%(upload_date)s" "$SOURCE_URL" 2>/dev/null)
  VIDEO_DATE=$(echo "$VIDEO_DATE_RAW" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3/')
  VIDEO_ID=$(yt-dlp --no-download --print "%(id)s" "$SOURCE_URL" 2>/dev/null)
  DESCRIPTION=$(yt-dlp --no-download --print "%(description)s" "$SOURCE_URL" 2>/dev/null)
  progress_complete

  echo "📺 $TITLE — $CHANNEL"
  read -rp "Proceed? [Y/n] " CONFIRM
  if [[ "$CONFIRM" =~ ^[Nn] ]]; then
    echo "Cancelled."
    exit 0
  fi

  progress_start "Fetching transcript..." 15
  # Try each language separately — yt-dlp aborts all downloads if any one language fails
  # Use -orig variants first (original language subs are higher quality than auto-translated)
  for _lang in "ko-orig" "en-orig" "ko" "en"; do
    yt-dlp --write-subs --write-auto-subs --sub-langs "$_lang" \
      --skip-download --output "$TRANSCRIPT_DIR/${VIDEO_ID}" "$SOURCE_URL" >/dev/null 2>&1
    SUB_FILE=$(find "$TRANSCRIPT_DIR" -name "${VIDEO_ID}*" -type f | head -1)
    [ -n "$SUB_FILE" ] && break
  done

  if [ -z "$SUB_FILE" ]; then
    progress_stop
    echo ""
    echo "❌ No transcript found for this video (tried Korean and English)."
    exit 1
  fi

  # Strip VTT/SRT formatting to plain text
  TRANSCRIPT_FILE="$TRANSCRIPT_DIR/${VIDEO_ID}.txt"
  sed -E '/^WEBVTT/d; /^Kind:/d; /^Language:/d; /^[0-9]{2}:[0-9]{2}/d; /^$/d; /^[0-9]+$/d; /-->/d' "$SUB_FILE" \
    | awk '!seen[$0]++' > "$TRANSCRIPT_FILE"
  find "$TRANSCRIPT_DIR" -name "${VIDEO_ID}*" ! -name "*.txt" -delete 2>/dev/null
  progress_complete

  SAFE_TITLE=$(echo "$TITLE" | sed 's/[\/\\:*?"<>|]/-/g' | sed 's/  */ /g' | head -c 100)
  NOTE_PATH="$TIL_DIR/${TODAY_DATE}-${SAFE_TITLE}.md"

  TRANSCRIPT_SIZE=$(wc -c < "$TRANSCRIPT_FILE")
  MAX_CHUNK=100000

  if [ "$TRANSCRIPT_SIZE" -le "$MAX_CHUNK" ]; then
    # --- Single-call path (short transcripts) ---
    progress_start "Summarizing with Claude Code..." 60

    claude -p --tools "" <<__TIL_EOF__ > "$NOTE_PATH"
You are creating a TIL (Today I Learned) note for an Obsidian vault.

VIDEO METADATA:
- Title: $TITLE
- Channel: $CHANNEL
- Upload Date: $VIDEO_DATE
- URL: $SOURCE_URL

VIDEO DESCRIPTION:
$DESCRIPTION

TRANSCRIPT:
$(cat "$TRANSCRIPT_FILE")

---

Create a detailed, academically rigorous yet easy-to-understand TIL note in this exact format:

---
title: "$TITLE"
source: $SOURCE_URL
channel: $CHANNEL
date: $TODAY
published: $VIDEO_DATE
type: youtube
tags: [til, youtube, <add 2-4 relevant topic tags>]
---

# <concise descriptive title>

## TL;DR
<2-3 sentence plain-language summary that anyone could understand>

## Key Takeaways
<numbered list of the most important things to remember>

## Key Concepts
<bullet points of the main ideas/concepts covered, with brief explanations>

## Connections
<suggest 2-3 related topics or questions this connects to, formatted as Obsidian wikilinks like [[Topic Name]]. These help build the knowledge graph>

---

## Detailed Summary
<thorough walkthrough of the video's content, organized by topic. Use subheadings (###) if the video covers multiple distinct topics. Be detailed and precise but explain jargon in parentheses when first used>

## Source Notes
<any notable quotes, timestamps, or references mentioned in the video.
Also include any relevant external links from the video description or transcript.
Include: tools, libraries, papers, documentation, related articles, GitHub repos, datasets.
Exclude: sponsor links, course/product ads, social media profiles, subscription/newsletter links, affiliate/merch links.
Format links as: - [descriptive title](URL) — one-line context>

CRITICAL: Output ONLY the raw markdown note starting with --- frontmatter. Do NOT add any commentary before or after the note. Just print the markdown.
__TIL_EOF__

  else
    # --- Map-reduce path (long transcripts) ---
    NUM_CHUNKS=$(( (TRANSCRIPT_SIZE + MAX_CHUNK - 1) / MAX_CHUNK ))
    echo "📏 Large transcript ($(( TRANSCRIPT_SIZE / 1000 ))K chars) — splitting into $NUM_CHUNKS chunks"

    # Split transcript into chunks
    CHUNK_DIR="$TRANSCRIPT_DIR/${VIDEO_ID}_chunks"
    mkdir -p "$CHUNK_DIR"
    split -b ${MAX_CHUNK} "$TRANSCRIPT_FILE" "$CHUNK_DIR/chunk_"

    # Map: summarize each chunk
    SUMMARIES_FILE="$TRANSCRIPT_DIR/${VIDEO_ID}_summaries.txt"
    > "$SUMMARIES_FILE"
    CHUNK_NUM=0
    CHUNK_FILES=("$CHUNK_DIR"/chunk_*)

    for CHUNK_FILE in "${CHUNK_FILES[@]}"; do
      CHUNK_NUM=$((CHUNK_NUM + 1))
      progress_start "Summarizing chunk $CHUNK_NUM/$NUM_CHUNKS..." 30

      claude -p --tools "" <<__TIL_EOF__ >> "$SUMMARIES_FILE"
You are summarizing part $CHUNK_NUM of $NUM_CHUNKS of a video transcript.

VIDEO: $TITLE by $CHANNEL

TRANSCRIPT CHUNK $CHUNK_NUM/$NUM_CHUNKS:
$(cat "$CHUNK_FILE")

---

Extract ALL key information from this chunk. Include:
- Main topics and arguments discussed
- Important concepts, definitions, or frameworks introduced
- Specific examples, tools, or techniques mentioned
- Notable quotes or statements
- Any actionable advice or recommendations
- Any external URLs or links mentioned

Be thorough and detailed. This summary will be combined with other chunks to create a final note.
Output ONLY the summary content, no preamble.
__TIL_EOF__

      printf "\n\n---CHUNK_BOUNDARY---\n\n" >> "$SUMMARIES_FILE"
      progress_complete
    done

    # Reduce: combine all chunk summaries into final note
    progress_start "Combining into final note..." 45

    claude -p --tools "" <<__TIL_EOF__ > "$NOTE_PATH"
You are creating a TIL (Today I Learned) note for an Obsidian vault.
The note is based on summaries from a long video, split into $NUM_CHUNKS parts.

VIDEO METADATA:
- Title: $TITLE
- Channel: $CHANNEL
- Upload Date: $VIDEO_DATE
- URL: $SOURCE_URL

VIDEO DESCRIPTION:
$DESCRIPTION

CHUNK SUMMARIES:
$(cat "$SUMMARIES_FILE")

---

Synthesize ALL the chunk summaries above into a single, cohesive TIL note. Make sure no key information is lost. Use this exact format:

---
title: "$TITLE"
source: $SOURCE_URL
channel: $CHANNEL
date: $TODAY
published: $VIDEO_DATE
type: youtube
tags: [til, youtube, <add 2-4 relevant topic tags>]
---

# <concise descriptive title>

## TL;DR
<2-3 sentence plain-language summary that anyone could understand>

## Key Takeaways
<numbered list of the most important things to remember>

## Key Concepts
<bullet points of the main ideas/concepts covered, with brief explanations>

## Connections
<suggest 2-3 related topics or questions this connects to, formatted as Obsidian wikilinks like [[Topic Name]]. These help build the knowledge graph>

---

## Detailed Summary
<thorough walkthrough of the video's content, organized by topic. Use subheadings (###) for each major topic. Be detailed and precise but explain jargon in parentheses when first used. Cover ALL topics from ALL chunks.>

## Source Notes
<any notable quotes, timestamps, or references mentioned.
Also include any relevant external links from the video description or chunk summaries.
Include: tools, libraries, papers, documentation, related articles, GitHub repos, datasets.
Exclude: sponsor links, course/product ads, social media profiles, subscription/newsletter links, affiliate/merch links.
Format links as: - [descriptive title](URL) — one-line context>

CRITICAL: Output ONLY the raw markdown note starting with --- frontmatter. Do NOT add any commentary before or after the note. Just print the markdown.
__TIL_EOF__

    # Cleanup temp files
    rm -rf "$CHUNK_DIR" "$SUMMARIES_FILE"
  fi

  clean_claude_output "$NOTE_PATH"
  progress_complete
  rm -f "$TRANSCRIPT_FILE"

# --- Article mode ---
elif [ "$MODE" = "article" ]; then
  progress_start "Fetching article..." 10
  ARTICLE_JSON=$(trafilatura -u "$SOURCE_URL" --json 2>/dev/null)

  if [ -z "$ARTICLE_JSON" ]; then
    progress_stop
    echo ""
    echo "❌ Could not extract content from: $SOURCE_URL"
    echo "   The page might be paywalled, JavaScript-only, or empty."
    exit 1
  fi

  ARTICLE_CONTENT=$(echo "$ARTICLE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('text',''))" 2>/dev/null)
  ARTICLE_TITLE=$(echo "$ARTICLE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('title',''))" 2>/dev/null)
  ARTICLE_DATE=$(echo "$ARTICLE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('date',''))" 2>/dev/null)
  ARTICLE_LINKS=$(echo "$ARTICLE_JSON" | python3 -c "
import sys, json, re
data = json.load(sys.stdin)
text = data.get('text', '')
urls = list(dict.fromkeys(re.findall(r'https?://[^\s)\]>\"]+', text)))
print('\n'.join(urls))
" 2>/dev/null)

  # Fallback: extract title and date from HTML meta tags / body if trafilatura missed them
  if [ -z "$ARTICLE_TITLE" ] || [ -z "$ARTICLE_DATE" ]; then
    PAGE_HTML=$(curl -sL "$SOURCE_URL" 2>/dev/null)
    if [ -z "$ARTICLE_TITLE" ]; then
      ARTICLE_TITLE=$(echo "$PAGE_HTML" | grep -oE 'og:title"[^"]*content="[^"]*"' | sed -E 's/.*content="([^"]*)".*/\1/' | head -1 || true)
    fi
    if [ -z "$ARTICLE_DATE" ]; then
      # Try article:published_time meta tag first
      ARTICLE_DATE=$(echo "$PAGE_HTML" | grep -oE 'article:published_time"[^"]*content="[^"]*"' | sed -E 's/.*content="([^"]*)".*/\1/' | head -1 | cut -c1-10 || true)
    fi
    if [ -z "$ARTICLE_DATE" ]; then
      # Try common date patterns in body text
      # "Mar 24, 2026", "March 24, 2026", "24 Mar 2026" (arXiv), "2026-03-24"
      ARTICLE_DATE=$(echo "$PAGE_HTML" | grep -oE '[0-9]{1,2} [A-Z][a-z]{2,8} [0-9]{4}|[A-Z][a-z]{2,8} [0-9]{1,2},? [0-9]{4}' | head -1 || true)
      # Convert to YYYY-MM-DD
      if [ -n "$ARTICLE_DATE" ]; then
        ARTICLE_DATE=$(python3 -c "
from datetime import datetime
d='$ARTICLE_DATE'
for fmt in ['%d %b %Y','%d %B %Y','%b %d, %Y','%b %d %Y','%B %d, %Y','%B %d %Y']:
    try:
        print(datetime.strptime(d,fmt).strftime('%Y-%m-%d')); break
    except: pass
" 2>/dev/null)
      fi
    fi
  fi

  if [ -z "$ARTICLE_TITLE" ]; then
    ARTICLE_TITLE=$(echo "$SOURCE_URL" | sed -E 's|https?://[^/]+/||; s|[/-]| |g; s|\.html?||g' | head -c 80)
  fi
  progress_complete

  CHAR_COUNT=${#ARTICLE_CONTENT}
  PREVIEW=$(echo "$ARTICLE_CONTENT" | head -c 80)
  echo "📄 $ARTICLE_TITLE"
  echo "   $CHAR_COUNT chars from: $SOURCE_URL"
  read -rp "Proceed? [Y/n] " CONFIRM
  if [[ "$CONFIRM" =~ ^[Nn] ]]; then
    echo "Cancelled."
    exit 0
  fi

  SAFE_TITLE=$(echo "$ARTICLE_TITLE" | sed 's/[\/\\:*?"<>|]/-/g' | sed 's/  */ /g' | head -c 100)
  NOTE_PATH="$TIL_DIR/${TODAY_DATE}-${SAFE_TITLE}.md"

  progress_start "Summarizing with Claude Code..." 45

  claude -p --tools "" <<__TIL_EOF__ > "$NOTE_PATH"
You are creating a knowledge note for an Obsidian vault.

METADATA:
- Title: $ARTICLE_TITLE
- Source URL: $SOURCE_URL
- Article Date: ${ARTICLE_DATE:-unknown}
- Date: $TODAY

LINKS FOUND IN ARTICLE:
$ARTICLE_LINKS

ARTICLE CONTENT:
$ARTICLE_CONTENT

---

Create a detailed, academically rigorous yet easy-to-understand note in this exact format:

---
title: "$ARTICLE_TITLE"
source: $SOURCE_URL
date: $TODAY
published: ${ARTICLE_DATE:-unknown}
type: article
tags: [<add 2-5 relevant topic tags>]
---

# $ARTICLE_TITLE

## TL;DR
<2-3 sentence plain-language summary>

## Key Takeaways
<numbered list of the most important things to remember>

## Key Concepts
<bullet points of the main ideas/concepts, with brief explanations>

## Connections
<suggest 2-3 related topics formatted as Obsidian wikilinks like [[Topic Name]]>

---

## Detailed Summary
<thorough walkthrough organized by topic. Use subheadings (###) if it covers multiple distinct topics. Be detailed and precise but explain jargon in parentheses when first used>

## Source Notes
<any notable quotes or references from the article.
Also include any relevant external links found in the article.
Include: tools, libraries, papers, documentation, related articles, GitHub repos, datasets.
Exclude: sponsor links, course/product ads, social media profiles, subscription/newsletter links, affiliate/merch links.
Format links as: - [descriptive title](URL) — one-line context>

CRITICAL: Output ONLY the raw markdown note starting with --- frontmatter. Do NOT add any commentary before or after the note. Just print the markdown.
__TIL_EOF__

  clean_claude_output "$NOTE_PATH"
  progress_complete

# --- Text mode ---
elif [ "$MODE" = "text" ]; then
  if [ -t 0 ]; then
    # No piped input — read from clipboard
    INPUT=$(pbpaste)
    if [ -z "$INPUT" ]; then
      echo "❌ Clipboard is empty. Copy some text first."
      exit 1
    fi
    # Check if clipboard has a YouTube URL instead of article text
    ACCIDENTAL_ID=$(extract_video_id "$INPUT")
    if [ -n "$ACCIDENTAL_ID" ] && [ ${#INPUT} -lt 200 ]; then
      echo "⚠️  Clipboard looks like a YouTube URL. Did you mean to run 'til' instead?"
      read -rp "Continue as text anyway? [y/N] " CONFIRM
      if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
        echo "Cancelled. Run 'til' for YouTube mode."
        exit 0
      fi
    fi
    CHAR_COUNT=${#INPUT}
    PREVIEW=$(echo "$INPUT" | head -c 80)
    echo "📋 Read $CHAR_COUNT chars from clipboard: \"${PREVIEW}...\""
    read -rp "Proceed? [Y/n] " CONFIRM
    if [[ "$CONFIRM" =~ ^[Nn] ]]; then
      echo "Cancelled."
      exit 0
    fi
  else
    # Piped input
    INPUT=$(cat)
  fi

  if [ -z "$INPUT" ]; then
    echo "❌ No text provided."
    exit 1
  fi

  SOURCE_LINE=""
  if [ -n "$SOURCE_URL" ]; then
    SOURCE_LINE="- Source URL: $SOURCE_URL"
  fi

  # Build title-related prompt parts
  if [ -n "$TITLE" ]; then
    TITLE_META="- Title: $TITLE"
    TITLE_FRONTMATTER="title: \"$TITLE\""
    TITLE_HEADING="# $TITLE"
  else
    TITLE_META="- Title: NONE PROVIDED — you must generate a concise, descriptive title from the content"
    TITLE_FRONTMATTER="title: \"GENERATE_TITLE_HERE\""
    TITLE_HEADING="# GENERATE_TITLE_HERE"
  fi

  # Write to temp file first if we need to extract the title
  if [ -n "$TITLE" ]; then
    SAFE_TITLE=$(echo "$TITLE" | sed 's/[\/\\:*?"<>|]/-/g' | sed 's/  */ /g' | head -c 100)
    NOTE_PATH="$TIL_DIR/${TODAY_DATE}-${SAFE_TITLE}.md"
  else
    NOTE_PATH="$TIL_DIR/${TODAY_DATE}-til-note-$$.md"
  fi

  progress_start "Summarizing with Claude Code..." 45

  claude -p --tools "" <<__TIL_EOF__ > "$NOTE_PATH"
You are creating a knowledge note for an Obsidian vault.

METADATA:
$TITLE_META
- Date: $TODAY
$SOURCE_LINE

SOURCE TEXT:
$INPUT

---

Create a detailed, academically rigorous yet easy-to-understand note in this exact format:

---
$TITLE_FRONTMATTER
source: ${SOURCE_URL:-manual}
date: $TODAY
type: ${SOURCE_URL:+article}${SOURCE_URL:-note}
tags: [<add 2-5 relevant topic tags>]
---

$TITLE_HEADING

## TL;DR
<2-3 sentence plain-language summary>

## Key Takeaways
<numbered list of the most important things to remember>

## Key Concepts
<bullet points of the main ideas/concepts, with brief explanations>

## Connections
<suggest 2-3 related topics formatted as Obsidian wikilinks like [[Topic Name]]>

---

## Detailed Summary
<thorough walkthrough organized by topic. Use subheadings (###) if it covers multiple distinct topics. Be detailed and precise but explain jargon in parentheses when first used>

CRITICAL: Output ONLY the raw markdown note starting with --- frontmatter. Do NOT add any commentary before or after the note. Just print the markdown.
__TIL_EOF__

  clean_claude_output "$NOTE_PATH"
  progress_complete

  # If title was auto-generated, extract it and rename the file
  if [ -z "$TITLE" ]; then
    TITLE=$(sed -n 's/^title: *"\(.*\)"/\1/p' "$NOTE_PATH" | head -1)
    if [ -n "$TITLE" ]; then
      SAFE_TITLE=$(echo "$TITLE" | sed 's/[\/\\:*?"<>|]/-/g' | sed 's/  */ /g' | head -c 100)
      NEW_PATH="$TIL_DIR/${TODAY_DATE}-${SAFE_TITLE}.md"
      mv "$NOTE_PATH" "$NEW_PATH"
      NOTE_PATH="$NEW_PATH"
    fi
  fi
fi

echo ""
echo "✅ Note created: $NOTE_PATH"

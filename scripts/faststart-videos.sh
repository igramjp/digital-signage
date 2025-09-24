#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob

VID_DIR="static/videos"

echo "[faststart] Processing MP4 files in ${VID_DIR} ..."

count=0
updated=0

for f in "${VID_DIR}"/*.mp4; do
  [ -e "$f" ] || continue
  count=$((count+1))
  base=$(basename "$f")
  tmp="${f}.faststart.tmp.mp4"
  bak="${f}.bak"

  echo "[faststart] -> ${base}"
  # Re-mux with moov at head, copy streams to avoid re-encode
  ffmpeg -v error -stats -y -i "$f" -c copy -movflags +faststart "$tmp"

  # Basic sanity: ensure tmp was written and is non-empty
  if [ -s "$tmp" ]; then
    cp -p "$f" "$bak" || true
    mv -f "$tmp" "$f"
    updated=$((updated+1))
    echo "[faststart] Updated ${base} (backup: ${bak})"
  else
    echo "[faststart] Skipped ${base} (no output)"
    rm -f "$tmp" || true
  fi
done

echo "[faststart] Done. Files found: ${count}, updated: ${updated}."


#!/usr/bin/env bash
set -euo pipefail

# Clean build artifacts to reduce repo size.
# Usage:
#   bash scripts/clean.sh            # interactive confirm
#   bash scripts/clean.sh --dry-run  # show what would be removed
#   bash scripts/clean.sh -y         # remove without prompt
#   bash scripts/clean.sh -y --node-modules  # also remove node_modules

DRY_RUN=false
ASSUME_YES=false
CLEAN_NODE_MODULES=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      ;;
    -y|--yes)
      ASSUME_YES=true
      ;;
    --node-modules)
      CLEAN_NODE_MODULES=true
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

targets=(
  "build"
  ".svelte-kit"
  "src-tauri/target"
)

# Include backup directories if present
for d in src-tauri.bak-*; do
  if [ -d "$d" ]; then
    targets+=("$d")
  fi
done

if [ "$CLEAN_NODE_MODULES" = true ] && [ -d node_modules ]; then
  targets+=("node_modules")
fi

if [ ${#targets[@]} -eq 0 ]; then
  echo "Nothing to clean."
  exit 0
fi

echo "The following paths will be removed if you proceed:"
for t in "${targets[@]}"; do
  if [ -e "$t" ]; then
    size=$(du -sh "$t" 2>/dev/null | awk '{print $1}')
    printf "  - %s\t(%s)\n" "$t" "${size:-unknown}"
  fi
done

if [ "$DRY_RUN" = true ]; then
  echo "Dry run only. No changes made."
  exit 0
fi

if [ "$ASSUME_YES" != true ]; then
  read -r -p "Proceed with deletion? [y/N] " reply
  case "$reply" in
    [yY][eE][sS]|[yY]) ;;
    *) echo "Aborted."; exit 0 ;;
  esac
fi

for t in "${targets[@]}"; do
  if [ -e "$t" ]; then
    echo "Removing $t ..."
    rm -rf "$t"
  fi
done

echo "Cleanup complete."


#!/usr/bin/env bash
# paint.sh — Render a 7×52 grid as backdated commits to a GitHub private repo.
#
# Usage:
#   bash paint.sh <year> <grid.json>    # Paint a grid
#   bash paint.sh <year> --clear        # Clear a year
#
# Required env vars:
#   GITHUB_TOKEN        GitHub PAT with repo scope
#   GIT_AUTHOR_NAME     Commit author name
#   GIT_AUTHOR_EMAIL    Must be noreply format: <id>+<user>@users.noreply.github.com
#   HEATMAP_REPO        Repo name (default: heatmap-art)
#
# Why this script exists:
#   GitHub silently drops contributions when >1000 commits are pushed at once.
#   This script batches pushes every 500 commits. It also handles year boundary
#   filtering (skips dates outside the target year) and noreply email formatting.
#   Do not improvise these git operations — the edge cases are subtle.

set -euo pipefail

YEAR="${1:?Usage: paint.sh <year> <grid.json|--clear>}"
GRID_ARG="${2:?Usage: paint.sh <year> <grid.json|--clear>}"
REPO="${HEATMAP_REPO:-heatmap-art}"
BATCH_SIZE=500

# Resolve credentials with sensible fallbacks
GITHUB_TOKEN="${GITHUB_TOKEN:-$(gh auth token 2>/dev/null || true)}"
GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-$(git config user.name 2>/dev/null || true)}"
GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-$(git config user.email 2>/dev/null || true)}"

: "${GITHUB_TOKEN:?No GitHub token found. Set GITHUB_TOKEN or install gh CLI and run 'gh auth login'.}"
: "${GIT_AUTHOR_NAME:?No author name found. Set GIT_AUTHOR_NAME or run 'git config --global user.name \"Your Name\"'.}"
: "${GIT_AUTHOR_EMAIL:?No author email found. Set GIT_AUTHOR_EMAIL or run 'git config --global user.email \"you@example.com\"'.}"

# Resolve GitHub username
USERNAME=$(curl -sf -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user | python3 -c "import json,sys; print(json.load(sys.stdin)['login'])")

REMOTE="https://${GITHUB_TOKEN}@github.com/${USERNAME}/${REPO}.git"
LOCAL="/tmp/heatmap-${USERNAME}-${REPO}"

# Ensure remote repo exists
if ! curl -sf -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/${USERNAME}/${REPO}" > /dev/null 2>&1; then
  curl -sf -X POST -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -d "{\"name\":\"${REPO}\",\"private\":true,\"description\":\"Heatmap art\"}" \
    https://api.github.com/user/repos > /dev/null
  echo "Created private repo ${USERNAME}/${REPO}"
fi

# Init or sync local clone
if [ ! -d "$LOCAL/.git" ]; then
  mkdir -p "$LOCAL"
  cd "$LOCAL"
  git init -q
  git config user.name "$GIT_AUTHOR_NAME"
  git config user.email "$GIT_AUTHOR_EMAIL"
  echo "# heatmap-art" > README.md
  git add README.md
  GIT_AUTHOR_DATE="2020-01-01T12:00:00+00:00" \
  GIT_COMMITTER_DATE="2020-01-01T12:00:00+00:00" \
  git commit -q -m "chore: init heatmap repo"
  git remote add origin "$REMOTE"
else
  cd "$LOCAL"
  git config user.name "$GIT_AUTHOR_NAME"
  git config user.email "$GIT_AUTHOR_EMAIL"
  git remote set-url origin "$REMOTE"
  git fetch -q origin main 2>/dev/null && git reset -q --hard origin/main 2>/dev/null || true
fi

# Commit levels: how many commits per intensity 0-4
LEVELS=(0 2 5 8 12)

force_push() {
  git push -q --force origin HEAD:main 2>/dev/null || git push -q --force origin HEAD:main
}

# --- CLEAR MODE ---
if [ "$GRID_ARG" = "--clear" ]; then
  # Collect non-target-year heatmap commits
  KEEP_FILE=$(mktemp)
  git log --format="%aI||%s" --grep="feat: heatmap update" 2>/dev/null | \
    grep -v "\[${YEAR}/" > "$KEEP_FILE" || true

  REMOVED=$(git log --oneline --grep="feat: heatmap update \[${YEAR}/" 2>/dev/null | wc -l | tr -d ' ')

  if [ "$REMOVED" = "0" ]; then
    echo "No heatmap commits for ${YEAR} — nothing to clear."
    rm -f "$KEEP_FILE"
    exit 0
  fi

  # Reset to init commit
  INIT=$(git log --format="%H" --grep="chore: init heatmap repo" --reverse 2>/dev/null | head -1)
  if [ -z "$INIT" ]; then
    echo "Error: no init commit found. Delete $LOCAL and retry." >&2
    exit 1
  fi

  git reset -q --hard "$INIT"
  GIT_AUTHOR_NAME="$GIT_AUTHOR_NAME" GIT_AUTHOR_EMAIL="$GIT_AUTHOR_EMAIL" \
  GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL" \
  git commit -q --amend --reset-author --no-edit

  # Re-apply other years' commits in batches
  COUNT=0
  # Reverse file (oldest first) — portable across macOS and Linux
  REVERSED=$(mktemp)
  awk '{a[NR]=$0} END{for(i=NR;i>=1;i--)print a[i]}' "$KEEP_FILE" > "$REVERSED"
  COUNT=0
  while IFS='||' read -r DATE MSG; do
    [ -z "$DATE" ] && continue
    GIT_AUTHOR_DATE="$DATE" GIT_COMMITTER_DATE="$DATE" \
    git commit -q --allow-empty -m "$MSG"
    COUNT=$((COUNT + 1))
    if [ $((COUNT % BATCH_SIZE)) -eq 0 ]; then
      force_push
    fi
  done < "$REVERSED"

  force_push
  rm -f "$KEEP_FILE" "$REVERSED"
  echo "Cleared ${REMOVED} heatmap commits for ${YEAR}."
  exit 0
fi

# --- PAINT MODE ---
GRID_FILE="$GRID_ARG"
if [ ! -f "$GRID_FILE" ]; then
  echo "Error: grid file not found: $GRID_FILE" >&2
  exit 1
fi

# Validate grid dimensions and values
python3 -c "
import json, sys
grid = json.load(open('${GRID_FILE}'))
errors = []
if not isinstance(grid, list):
    errors.append('Grid must be a JSON array of arrays')
elif len(grid) != 7:
    errors.append(f'Grid must have exactly 7 rows, got {len(grid)}')
else:
    for r, row in enumerate(grid):
        if not isinstance(row, list):
            errors.append(f'Row {r} is not an array')
            continue
        if len(row) != 52:
            errors.append(f'Row {r} must have 52 columns, got {len(row)}')
        for c, v in enumerate(row):
            if not isinstance(v, int) or v < 0 or v > 4:
                errors.append(f'Invalid intensity {v} at row {r}, col {c} (must be 0-4)')
if errors:
    print('Grid validation failed:', file=sys.stderr)
    for e in errors:
        print(f'  - {e}', file=sys.stderr)
    sys.exit(1)
" || exit 1

# Calculate the Sunday on or before Jan 1
JAN1_DOW=$(python3 -c "import datetime; print(datetime.date(${YEAR},1,1).weekday())")
# Python weekday: Mon=0..Sun=6. Convert to days-to-subtract (Sun=0 offset)
DAYS_BACK=$(python3 -c "
from datetime import date
jan1 = date(${YEAR}, 1, 1)
dow = jan1.isoweekday() % 7  # Sun=0, Mon=1..Sat=6
print(dow)
")
START=$(python3 -c "
from datetime import date, timedelta
jan1 = date(${YEAR}, 1, 1)
dow = jan1.isoweekday() % 7
print((jan1 - timedelta(days=dow)).isoformat())
")

YEAR_START="${YEAR}-01-01"
NEXT_YEAR_START="$((YEAR + 1))-01-01"

# Parse grid and generate commits
COMMITS_CREATED=0
SINCE_PUSH=0

while IFS= read -r LINE; do
  COL=$(echo "$LINE" | cut -d' ' -f1)
  ROW=$(echo "$LINE" | cut -d' ' -f2)
  INTENSITY=$(echo "$LINE" | cut -d' ' -f3)

  NUM_COMMITS=${LEVELS[$INTENSITY]}
  [ "$NUM_COMMITS" -eq 0 ] && continue

  # Calculate date
  OFFSET_DAYS=$(( COL * 7 + ROW ))
  CELL_DATE=$(python3 -c "
from datetime import date, timedelta
start = date.fromisoformat('${START}')
d = start + timedelta(days=${OFFSET_DAYS})
print(d.isoformat())
")

  # Skip dates outside target year
  [[ "$CELL_DATE" < "$YEAR_START" ]] && continue
  [[ "$CELL_DATE" > "${YEAR}-12-31" ]] && continue

  for (( i=0; i<NUM_COMMITS; i++ )); do
    MINUTES=$(( i * 50 / NUM_COMMITS ))
    ISO="${CELL_DATE}T12:$(printf '%02d' $MINUTES):00+00:00"

    GIT_AUTHOR_DATE="$ISO" GIT_COMMITTER_DATE="$ISO" \
    git commit -q --allow-empty -m "feat: heatmap update [${YEAR}/${COL}/${ROW}/${i}]"

    COMMITS_CREATED=$((COMMITS_CREATED + 1))
    SINCE_PUSH=$((SINCE_PUSH + 1))

    if [ "$SINCE_PUSH" -ge "$BATCH_SIZE" ]; then
      force_push
      SINCE_PUSH=0
      echo "  pushed batch (${COMMITS_CREATED} commits so far)"
    fi
  done
done < <(python3 -c "
import json, sys
grid = json.load(open('${GRID_FILE}'))
for col in range(52):
    for row in range(7):
        v = grid[row][col]
        if v > 0:
            print(f'{col} {row} {v}')
")

# Final push
if [ "$SINCE_PUSH" -gt 0 ]; then
  force_push
fi

echo "Painted ${COMMITS_CREATED} commits for ${YEAR}. View: https://github.com/${USERNAME}/${REPO}"

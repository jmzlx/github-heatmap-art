---
name: painting-github-heatmaps
description: Paints pixel art on GitHub contribution graphs using backdated commits to a private repo. Use when asked to create, modify, or design GitHub heatmap art, contribution graph designs, or profile customization. Handles the 52x7 grid model, intensity levels, design composition, and the git plumbing for rendering.
compatibility: Requires git and a GitHub account with a personal access token (repo scope).
---

# Painting GitHub Heatmaps

GitHub's contribution graph is a 52×7 grid (weeks × days). Each cell shows commit activity as a green shade. By backdating commits to a private repo, you turn it into a pixel canvas.

## Canvas Model

- **52 columns** (weeks, left to right) × **7 rows** (Sunday=0 at top, Saturday=6 at bottom)
- **5 intensity levels:** 0 (gray/empty), 1 (light green), 2, 3, 4 (darkest green)
- One canvas per year (2008–current). Year boundaries start on the Sunday before Jan 1.
- A grid is a JSON array: `[[col0..col51], ...7 rows]` — each value 0–4.

## Workflow

**Always follow this order. Rendering creates real commits — expensive to undo.**

1. **Compose** — build a 7×52 grid in code (Python, JS, whatever)
2. **Preview** — print it as ASCII art. Verify it looks right.
3. **Render** — `bash {baseDir}/scripts/paint.sh <year> <grid.json>` (low freedom — run exactly this)

## Composing Grids

You compose grids yourself. A grid is just a 7×52 array of integers 0–4.

```python
import json
grid = [[0]*52 for _ in range(7)]

# Draw a heart at column 5
heart = [
    [0,4,4,0,4,4,0],
    [4,4,4,4,4,4,4],
    [4,4,4,4,4,4,4],
    [0,4,4,4,4,4,0],
    [0,0,4,4,4,0,0],
    [0,0,0,4,0,0,0],
    [0,0,0,0,0,0,0],
]
for r in range(7):
    for c in range(len(heart[r])):
        if heart[r][c]: grid[r][5+c] = heart[r][c]

# Save for paint.sh
with open('/tmp/grid.json', 'w') as f:
    json.dump(grid, f)
```

Text, sprites, patterns, image conversions — write code for whatever you need. The grid is your only interface to `paint.sh`.

## Previewing

Always preview before rendering. Print ASCII art from your grid:

```python
symbols = [' ', '░', '▒', '▓', '█']
for row in grid:
    print(''.join(symbols[v] for v in row))
```

If you can't tell what the design is from the preview, it won't work on GitHub either.

## Rendering

**Low freedom — run exactly this, do not improvise git commands:**

```bash
bash {baseDir}/scripts/paint.sh <year> <path-to-grid.json>
```

Required environment variables:
- `GITHUB_TOKEN` — personal access token with `repo` scope
- `GIT_AUTHOR_NAME` — your name
- `GIT_AUTHOR_EMAIL` — must be your GitHub noreply email: `<id>+<user>@users.noreply.github.com`
- `HEATMAP_REPO` — private repo name (default: `heatmap-art`)

The script handles: repo creation, backdated commits, batched pushing (500/batch to avoid GitHub's silent drop limit), year boundary filtering, force push.

## Clearing a Year

```bash
bash {baseDir}/scripts/paint.sh <year> --clear
```

This removes all heatmap commits for the given year while preserving other years.

## Design Rules

Read [design-guide.md]({baseDir}/references/design-guide.md) before designing. The critical rules:

1. **Binary contrast wins** — design with level 0 (gray) and level 4 (dark green). Levels 1–3 look nearly identical on GitHub.
2. **Recognizability is #1** — if it needs a caption, redesign it.
3. **2px minimum thickness** — single-pixel lines vanish on the real heatmap.
4. **Geometric patterns and iconic shapes work.** Abstract art and gradients don't.

## Recovery

If `paint.sh` fails with ENOBUFS or the repo gets corrupted:
```bash
# Nuclear reset — delete local cache and remote repo
rm -rf /tmp/heatmap-*
gh repo delete <user>/<repo> --yes
gh repo create <repo> --private
# Then re-render
```

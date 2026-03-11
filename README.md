# GitHub Heatmap Art

An [AgentSkill](https://agentskills.io) that turns GitHub's contribution graph into a pixel art canvas.

Tell your AI agent to paint pixel art on your GitHub profile. It handles the design — the skill handles the git plumbing.

## What It Does

Your GitHub contribution graph is a 52×7 grid of green squares. This skill teaches AI agents how to paint on it by creating backdated commits to a private repo. The art shows up on your profile.

## Quick Start

Drop this folder into your project or global skills directory:

```bash
# Claude Code / Cursor / VS Code
cp -r painting-github-heatmaps .agents/skills/

# Or clone directly
git clone https://github.com/jmzlx/github-heatmap-art .agents/skills/painting-github-heatmaps
```

The script auto-detects your git config and `gh` CLI credentials. If you have `git` configured and `gh auth login` done, **zero setup needed**.

Optional overrides:
```bash
export GITHUB_TOKEN="ghp_..."                                    # if no gh CLI
export GIT_AUTHOR_NAME="Your Name"                               # if no git config
export GIT_AUTHOR_EMAIL="12345+you@users.noreply.github.com"    # noreply recommended
export HEATMAP_REPO="heatmap-art"                                # default works
```

Then ask your agent:
> "Paint a heart on my 2020 GitHub heatmap"

## How It Works

1. **Agent composes** a 7×52 grid of intensities (0–4) — it writes code to build the grid
2. **Agent previews** as ASCII art — verifies the design looks right
3. **Script renders** — `scripts/paint.sh` creates backdated commits and pushes in batches

The agent handles all creative work (design, sprites, text, patterns). The script handles all git plumbing (backdating, batching, year boundaries).

## Compatible Agents

Works with any [AgentSkills-compatible](https://agentskills.io) tool:

Claude Code · Cursor · Gemini CLI · VS Code Copilot · GitHub Copilot · OpenClaw · Goose · OpenHands · Amp · Junie · OpenCode · Mux · Firebender · Letta · Autohand

## Files

```
painting-github-heatmaps/
├── SKILL.md                    # Agent instructions (<5000 tokens)
├── scripts/paint.sh            # Git plumbing (batch commits + push)
├── references/design-guide.md  # What works on real heatmaps
└── README.md                   # This file
```

## Why Not MCP?

This was originally an MCP server with 12 typed tools. We killed it. A coding agent doesn't need structured tools to create a 7×52 array — it just needs to know the domain and have a script for the git plumbing. The skill approach is simpler, works with more agents, and costs zero context tokens until you actually need it.

## License

MIT

#!/usr/bin/env bash
# Installs grepjob-autofill into Claude Code:
#   - Copies the bundled MCP to ~/.grepjob-autofill/mcp.mjs so the repo can be
#     moved or deleted after install without breaking anything.
#   - Registers the local autofill MCP with Claude (pointing at that copy).
#   - Registers the remote grepjob search MCP with Claude.
#   - Installs the auto-apply skill at ~/.claude/skills/auto-apply.
#   - Prints Chrome extension install instructions (the one step that can't
#     be automated from the terminal).
#
# Re-running this is safe. It overwrites existing state with whatever is in
# the repo right now. To update: `git pull && ./install.sh`.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.grepjob-autofill"
SKILL_DIR="$HOME/.claude/skills/auto-apply"

# ── Prereqs ─────────────────────────────────────────────────────────────────

if ! command -v claude >/dev/null 2>&1; then
  echo "error: 'claude' CLI not found. Install Claude Code from https://claude.com/claude-code first." >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "error: 'node' not found. Install Node.js 18+ from https://nodejs.org first." >&2
  exit 1
fi

NODE_MAJOR=$(node -p 'process.versions.node.split(".")[0]')
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo "error: Node 18+ required (you have $(node --version))." >&2
  exit 1
fi

# ── 1. Copy the bundled MCP to a stable location ────────────────────────────

mkdir -p "$INSTALL_DIR"
cp "$REPO_DIR/mcp/mcp.mjs" "$INSTALL_DIR/mcp.mjs"
echo "✓ Copied MCP to $INSTALL_DIR/mcp.mjs"

# ── 2. Register the local MCP with Claude ───────────────────────────────────

# Name must be 'grepjob-autofill' — the skill calls the tools as
# `mcp__grepjob-autofill__fill_application`, `mcp__grepjob-autofill__read_form`, etc.
# Remove-then-add because `claude mcp add` errors if the name already exists.
claude mcp remove grepjob-autofill --scope user >/dev/null 2>&1 || true
# Also clean up the old name from pre-rename installs.
claude mcp remove autofill --scope user >/dev/null 2>&1 || true
claude mcp add grepjob-autofill --scope user -- node "$INSTALL_DIR/mcp.mjs"
echo "✓ Registered local MCP 'grepjob-autofill'"

# ── 3. Register the remote grepjob search MCP ───────────────────────────────

claude mcp remove grepjob --scope user >/dev/null 2>&1 || true
claude mcp add grepjob --scope user --transport http https://wzishhuxscpbsvxosipt.supabase.co/functions/v1/mcp
echo "✓ Registered remote MCP 'grepjob'"

# ── 4. Install the skill ────────────────────────────────────────────────────

mkdir -p "$HOME/.claude/skills"
rm -rf "$SKILL_DIR"
cp -R "$REPO_DIR/skill" "$SKILL_DIR"
echo "✓ Installed skill at $SKILL_DIR"

# ── 5. Chrome extension (manual step) ───────────────────────────────────────

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Two manual steps left:

 1. Install the Chrome extension (load unpacked from this repo)

    a. Open chrome://extensions in Chrome
    b. Toggle "Developer mode" on (top-right)
    c. Click "Load unpacked"
    d. Select: $REPO_DIR/chrome-extension

 2. Authenticate the grepjob search MCP

    The first time you run the skill, Claude will open a browser tab
    asking you to authenticate with grepjob.com. Log in or sign up,
    approve the connection, and you're done.

    To check MCP status at any time, run the /mcp command inside
    Claude Code — it lists each server and lets you re-authenticate
    if a token expires.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 Then in Claude Code, type:  /auto-apply

 The skill's first-run setup will ask for your resume and walk you
 through the rest. Your data is stored at ~/.auto-apply/.

EOF

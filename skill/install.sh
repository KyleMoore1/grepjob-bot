#!/usr/bin/env bash
# One-shot installer for the auto-apply Claude skill.
#
# Usage:
#   ./install.sh                    # install to ~/.claude/skills/auto-apply
#   ./install.sh --path <dir>       # install to a custom skill directory
#   ./install.sh --seed-config      # also seed ~/.auto-apply/ with defaults (optional)

set -euo pipefail

SKILL_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DEST="$HOME/.claude/skills/auto-apply"
SEED_CONFIG=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      SKILL_DEST="$2"
      shift 2
      ;;
    --seed-config)
      SEED_CONFIG=true
      shift
      ;;
    -h|--help)
      head -n 7 "$0" | tail -n 6 | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

mkdir -p "$(dirname "$SKILL_DEST")"

if [[ -d "$SKILL_DEST" ]]; then
  echo "Skill already installed at $SKILL_DEST — replacing."
  rm -rf "$SKILL_DEST"
fi

cp -R "$SKILL_SRC" "$SKILL_DEST"

# Make scripts executable
chmod +x "$SKILL_DEST/scripts/"*.py "$SKILL_DEST/install.sh" 2>/dev/null || true

echo "✓ Installed skill to $SKILL_DEST"

if [[ "$SEED_CONFIG" == true ]]; then
  python3 "$SKILL_DEST/scripts/init.py"
  echo
  echo "✓ Seeded default config at ~/.auto-apply/"
  echo "  Edit ~/.auto-apply/profile.json with your real info before running the skill."
fi

echo
echo "Next steps:"
echo "  1. Make sure the three required MCP servers are configured:"
echo "     - grepjob (job discovery)"
echo "     - autofill (autofill Chrome extension bridge)"
echo "     - claude-in-chrome (browser navigation)"
echo "  2. Restart Claude Code (or reload the skill directory) so it picks up the new skill."
echo "  3. In Claude, type: /auto-apply"
echo "     (or just say 'help me apply to jobs' — the skill's description should trigger it)"

# grepjob-autofill

Auto-fill software engineering job applications across Greenhouse, Lever, and Ashby from inside Claude Code. Tell Claude "apply to some backend roles in NYC," and it searches, fills the forms, verifies each submission lands on a confirmation page, and logs every application to a CSV you control.

## What you get

- A **Chrome extension** that drives form filling on job application pages.
- A **local MCP server** that bridges Claude to the extension over a localhost WebSocket.
- A **remote MCP** (`grepjob`) for searching jobs matching your preferences.
- An **auto-apply skill** that ties it all together: walks you through first-run setup (reading your resume PDF to pre-fill most of your profile), searches jobs, fills applications, verifies submissions, and tracks them in `~/.auto-apply/applications.csv`.

## Install

**Requirements:** [Claude Code](https://claude.com/claude-code), Node.js 18+, Chrome.

```bash
git clone https://github.com/KyleMoore1/grepjob-autofill
cd grepjob-autofill
./install.sh
```

`install.sh` registers both MCPs with Claude, installs the skill, and prints Chrome extension install instructions for the last manual step.

Then in Claude Code, type:

```
/auto-apply
```

On first run, the skill asks for your resume PDF and pre-fills most of your profile from it. You'll only need to answer 5 questions that resumes never have (pronouns, visa status, EEO preferences, optional address, referral source).

## What it looks like in Claude

```
you: find me some backend roles in NYC and apply to the good ones

claude (auto-apply skill):
  → searches the grepjob MCP with your saved preferences
  → filters out jobs already in applications.csv and companies on your
    avoid list
  → presents a table: company, role, comp, why it's a match
  → you approve / veto
  → for each approved job: navigates to the URL, reads the form,
    fills every field from your profile, attaches your resume,
    submits, verifies a confirmation page rendered
  → appends each successful application to applications.csv
  → reports: "7 applied, 1 failed, 1 skipped"
```

## Supported ATS platforms

The extension's content script runs on:

- `jobs.ashbyhq.com/*`
- `boards.greenhouse.io/*`, `job-boards.greenhouse.io/*`
- `boards.eu.greenhouse.io/*`, `job-boards.eu.greenhouse.io/*`
- `jobs.lever.co/*`, `jobs.eu.lever.co/*`

Companies that host their application on their own domain (e.g. `asana.com/jobs/apply/...`, `mongodb.com/careers/...`) route through Greenhouse but the extension can't fill them. These are flagged `status=skipped, notes="custom domain"` in your applications log.

## Where things go

After `./install.sh` and the first-run setup:

- `~/.grepjob-autofill/mcp.mjs` — the bundled MCP server
- `~/.claude/skills/auto-apply/` — the skill Claude loads
- `~/.auto-apply/profile.json` — info used to fill forms
- `~/.auto-apply/preferences.json` — job search criteria
- `~/.auto-apply/applications.csv` — application history, one row per submission

## Update

```bash
git pull
./install.sh
```

Re-running `install.sh` overwrites `~/.grepjob-autofill/mcp.mjs` and `~/.claude/skills/auto-apply/` with the latest versions. Your personal data in `~/.auto-apply/` is never touched.

## Uninstall

```bash
claude mcp remove autofill --scope user
claude mcp remove grepjob --scope user
rm -rf ~/.claude/skills/auto-apply ~/.grepjob-autofill
```

Then remove the Chrome extension from `chrome://extensions`. Your `~/.auto-apply/` data is preserved unless you delete it manually.

## Troubleshooting

**Skill doesn't trigger on `/auto-apply`** — restart Claude Code after running `install.sh`. Confirm `ls ~/.claude/skills/auto-apply/SKILL.md` shows the file.

**"Could not read profile at ~/.auto-apply/profile.json"** — the skill's first-run setup hasn't run yet. Type `/auto-apply` in Claude; it'll walk you through creating the profile from your resume.

**"Content script not loaded" when filling forms** — the Chrome extension isn't installed or isn't enabled. Check `chrome://extensions` and confirm "GrepJob Autofill Bridge" is present and toggled on.

**Autofill succeeds but the application doesn't actually submit** — the skill should detect this and retry, but some pages are non-standard. Check the page for validation errors (missing "I agree" checkbox, GDPR consent, etc.). The skill's `references/ats-quirks.md` covers the common ones.

**Port 9876 already in use** — something else is bound to the autofill MCP's port. Usually this means an older copy of the MCP is still running; `pkill -f 'mcp.mjs'` and restart Claude Code.

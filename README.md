# grepjob-autofill

Auto-fill software engineering job applications across Greenhouse, Lever, and Ashby from inside Claude Code. Tell Claude "apply to some backend roles in NYC," and it searches, fills the forms, verifies each submission lands on a confirmation page, and logs every application to a CSV you control.

**Everything lives in this repo.** Clone it, open Claude inside it, run the skill. Your profile, search settings, resume, and application log all stay in the clone on your machine — nothing is installed globally, nothing is uploaded.

## What you get

- An **auto-apply skill** (`/auto-apply`) — onboards you from your resume, finds jobs, fills + submits applications, verifies each one, and tracks them.
- A **local MCP server** (`mcp/mcp.mjs`) — bridges Claude to the Chrome extension over a localhost WebSocket and stores/validates your profile and application log.
- A **Chrome extension** (`chrome-extension/`) — fills the form fields on the application page.
- A **remote MCP** (`grepjob`) — searches jobs matching your saved parameters.

## Requirements

[Claude Code](https://claude.com/claude-code), **Node.js 18+**, and **Chrome**. No Python, no global installs.

Optional but recommended: the **Claude in Chrome** browser extension, which lets Claude open each job page for you. Without it, the skill just asks you to open each page yourself before it fills.

## Setup

```bash
git clone https://github.com/KyleMoore1/grepjob-autofill
cd grepjob-autofill
claude
```

When Claude starts inside the folder it detects the project's `.mcp.json` and asks you to approve two MCP servers — **`grepjob-autofill`** and **`grepjob`**. Approve both.

Then load the Chrome extension once:

1. Open `chrome://extensions`
2. Turn on **Developer mode** (top-right)
3. Click **Load unpacked** → select this repo's **`chrome-extension/`** folder

Finally, in Claude:

```
/auto-apply
```

On first run it checks your setup and walks you through onboarding: point it at your resume PDF and it pre-fills most of your profile from it, then asks the handful of things resumes never contain (pronouns, work authorization, EEO preferences, optional address, referral source). It saves everything into the repo and verifies the setup before you apply.

Want to confirm your install at any time? Run `node doctor.mjs`.

## What it looks like in Claude

```
you: find me some backend roles in NYC and apply to the good ones

claude (auto-apply skill):
  → searches the grepjob MCP with your saved parameters
  → filters out jobs already in applications.csv and companies on your
    avoid list
  → presents a table: company, role, comp, why it's a match
  → you approve / veto
  → for each approved job: opens the URL, reads the form,
    fills every field from your profile, attaches your resume,
    submits, verifies a confirmation page rendered
  → appends each successful application to applications.csv
  → reports: "7 applied, 1 failed, 1 skipped"
```

## Where everything lives (all inside the clone)

| Path | What | In git? |
|---|---|---|
| `config/profile.json` | your info, used to fill forms | no — gitignored |
| `config/search.yml` | your persistent search parameters | no — gitignored |
| `config/resume.pdf` | your resume | no — gitignored |
| `data/applications.csv` | one row per application | no — gitignored |
| `config/profile.example.json`, `config/search.example.yml` | the documented templates | yes |

Your personal files are all gitignored — they never get committed and never leave your machine. See [PRIVACY.md](PRIVACY.md).

## Tuning your search

Open `config/search.yml` any time and edit it by hand — locations, seniority, sub-categories, tech stack, salary floor, H-1B filter, companies to avoid, and reusable answers for common application questions. Every field is documented inline (start from `config/search.example.yml`). The skill reads it fresh on each "find jobs" run.

## Supported ATS platforms

The extension's content script runs on:

- `jobs.ashbyhq.com/*`
- `boards.greenhouse.io/*`, `job-boards.greenhouse.io/*`
- `boards.eu.greenhouse.io/*`, `job-boards.eu.greenhouse.io/*`
- `jobs.lever.co/*`, `jobs.eu.lever.co/*`

Companies that host their application on their own domain (e.g. `asana.com/jobs/apply/...`, `mongodb.com/careers/...`) route through Greenhouse but the extension can't fill them. These are flagged `status=skipped, notes="custom domain"` in your applications log.

## Update

```bash
git pull
```

Pulling refreshes the skill, the MCP bundle, and the extension code. Your gitignored data in `config/` and `data/` is never touched. If the extension code changed, re-load it from `chrome://extensions`; if the MCP bundle changed, restart Claude so it picks up the new `mcp/mcp.mjs`.

## Uninstall

Delete the clone and remove the extension from `chrome://extensions`. There's nothing else on your system — no global MCP registration, no `~/.claude` skill copy, no home-directory data.

## Troubleshooting

Run **`node doctor.mjs`** first — it checks Node, your profile, resume, search params, and the MCP bridge, and prints the exact fix for anything wrong.

**`/auto-apply` says the project MCP servers aren't enabled** — quit Claude and run `claude` again from inside this folder, approving the two servers when prompted.

**"Chrome extension not connected" when filling** — confirm "GrepJob Autofill Bridge" is present and enabled at `chrome://extensions`, loaded from this repo's `chrome-extension/` folder, and that a job application page is open.

**"Profile not found …"** — onboarding hasn't run yet. Type `/auto-apply`; it builds your profile from your resume.

**Autofill succeeds but the application doesn't submit** — the skill detects this and retries, but some pages are non-standard. Look for validation errors (missing "I agree" checkbox, GDPR consent). `.claude/skills/auto-apply/references/ats-quirks.md` covers the common ones.

**Port 9876 already in use** — an older copy of the MCP is still running. `pkill -f 'mcp.mjs'` and restart Claude.

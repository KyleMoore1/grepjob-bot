# grepjob-bot

Auto-fill software engineering job applications across Greenhouse, Lever, and Ashby from inside Claude Code. Tell Claude "apply to some backend roles in NYC," and it searches, fills the forms, verifies each submission lands on a confirmation page, and logs every application to a CSV you control.

**Everything lives in this repo.** Clone it, open Claude inside it, run the skill. Your profile, search settings, resume, and application log all stay in the clone on your machine — nothing is installed globally, nothing is uploaded.

## What you get

- A **grepjob-bot skill** (`/grepjob-bot`) — onboards you from your resume, finds jobs, fills + submits applications, verifies each one, and tracks them.
- A **local MCP server** (`mcp/mcp.mjs`) — bridges Claude to the Chrome extension over a localhost WebSocket and stores/validates your profile and application log.
- A **Chrome extension** (`chrome-extension/`) — fills the form fields on the application page.
- A **remote MCP** (`grepjob`) — searches jobs matching your saved parameters. It's hosted and needs a one-time sign-in; free accounts get 25 searches, a [GrepJob](https://grepjob.com) subscription lifts the cap.

## Requirements

[Claude Code](https://claude.com/claude-code), **Node.js 18+**, and **Chrome**. No Python, no global installs.

Optional but recommended: the **Claude in Chrome** browser extension, which lets Claude open each job page for you. Without it, the skill just asks you to open each page yourself before it fills.

## Setup

```bash
git clone https://github.com/KyleMoore1/grepjob-bot
cd grepjob-bot
claude
```

When Claude starts inside the folder it detects the project's `.mcp.json` and asks you to approve two MCP servers — **`grepjob-autofill`** and **`grepjob`**. Approve both.

The `grepjob` server is behind a sign-in. The skill hands you a login link the first time it needs to search (you can also do it up front with `/mcp` → `grepjob` → authenticate). Onboarding and applying to a pasted URL work without it.

Then load the Chrome extension once:

1. Open `chrome://extensions`
2. Turn on **Developer mode** (top-right)
3. Click **Load unpacked** → select this repo's **`chrome-extension/`** folder

Finally, in Claude:

```
/grepjob-bot
```

On first run it checks your setup and walks you through onboarding: point it at your resume PDF and it pre-fills most of your profile from it, then asks the handful of things resumes never contain (pronouns, work authorization, EEO preferences, optional address, referral source). It also asks what you're actually looking for — a couple of sentences in your own words — which it uses to rank every future search, keeping the hard filters deliberately wide. It saves everything into the repo and verifies the setup before you apply.

Want to confirm your install at any time? Run `node doctor.mjs`.

## What it looks like in Claude

```
you: find me some backend roles in NYC and apply to the good ones

claude (grepjob-bot skill):
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

Open `config/search.yml` any time and edit it by hand — your intent and dealbreakers paragraphs, locations, seniority, sub-categories, tech stack, salary floor, H-1B filter, company size and funding stage, companies to avoid, and reusable answers for common application questions. Every field is documented inline (start from `config/search.example.yml`). The skill reads it fresh on each "find jobs" run.

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

**`/grepjob-bot` says the project MCP servers aren't enabled** — quit Claude and run `claude` again from inside this folder, approving the two servers when prompted.

**Searching says it needs to authenticate / only `authenticate` shows under `grepjob`** — the hosted search API requires a sign-in. Run `/mcp`, pick `grepjob`, and complete the login in your browser; `search_jobs` appears once it finishes. "You've used all 25 free searches" means the free quota is spent — subscribe at grepjob.com or wait for the skill to search more narrowly.

**Search fails with an enum/validation error on `sub_category` or `tech_stack_filters`** — a value in `config/search.yml` isn't in GrepJob's current vocabulary (e.g. `AI & ML` was retired; `Kafka` is `Apache Kafka`). `node doctor.mjs` flags the retired one; the full lists are in `config/search.example.yml`.

**"Chrome extension not connected" when filling** — confirm "GrepJob Autofill Bridge" is present and enabled at `chrome://extensions`, loaded from this repo's `chrome-extension/` folder, and that a job application page is open.

**"Profile not found …"** — onboarding hasn't run yet. Type `/grepjob-bot`; it builds your profile from your resume.

**Autofill succeeds but the application doesn't submit** — the skill detects this and retries, but some pages are non-standard. Look for validation errors (missing "I agree" checkbox, GDPR consent). `.claude/skills/grepjob-bot/references/ats-quirks.md` covers the common ones.

**Port 9876 already in use** — an older copy of the MCP is still running. `pkill -f 'mcp.mjs'` and restart Claude.

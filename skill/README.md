# auto-apply

A Claude skill that finds and auto-fills software engineering job applications across Greenhouse, Lever, and Ashby — and tracks every application in a CSV you can audit.

```
User: find me some senior backend roles in NYC and apply to the good ones

Claude (auto-apply skill):
  → Loads your preferences from ~/.auto-apply/preferences.json
  → Searches GrepJob for matches
  → Filters out jobs you've already applied to
  → Shows a table for you to approve
  → For each approved job: navigates, fills, attaches your resume, submits
  → Verifies every submission lands on a "Thank you" confirmation page
  → Appends a row to ~/.auto-apply/applications.csv
  → Reports: "10 applied, 1 failed, 1 skipped"
```

## Prerequisites

You need three MCP servers connected to Claude before this skill will work:

1. **[grepjob](https://grepjob.com) search MCP** — discovers jobs matching your preferences.
2. **autofill MCP** — a local server that relays commands to a Chrome extension. See [grepjob-autofill](https://github.com/KyleMoore1/GrepJob-App/tree/main/mcp-autofill) for the setup.
3. **claude-in-chrome** — the official browser automation MCP from Anthropic.

Plus the **GrepJob autofill Chrome extension** installed in your browser (see [chrome-extension/](https://github.com/KyleMoore1/GrepJob-App/tree/main/chrome-extension)).

## Install

```bash
# Clone or download this skill, then:
cd auto-apply
./install.sh
```

That copies the skill to `~/.claude/skills/auto-apply/`. Restart Claude Code (or reload your skills) so it picks up the new skill.

To also seed `~/.auto-apply/` with default config files you can edit by hand:

```bash
./install.sh --seed-config
```

Otherwise, Claude will walk you through setup the first time you run the skill.

## First run

In Claude, type:

```
/auto-apply
```

Or just say something that triggers the skill's description:

```
help me apply to some jobs
```

On first run, Claude asks for your **resume PDF**, parses it, and pre-fills most of your profile from it:

```
You: ~/Downloads/my-resume.pdf

Claude: Here's what I pulled from your resume:
  • Name: Kyle Moore
  • Email: kylem70698@gmail.com
  • Phone: +1 206-595-6734
  • LinkedIn: linkedin.com/in/kyle-moore1
  • GitHub: github.com/KyleMoore1
  • Current role: Software Engineer II at Microsoft
  • Years of experience: ~5
  • Education: BS Computer Science, Santa Clara University
  Anything wrong?

You: looks good

Claude: Five quick questions for the stuff that's not on your resume:
  1. Pronouns?
  2. Are you a US citizen / will you need visa sponsorship?
  3. Decline all the optional EEO questions, or fill them out?
  4. Want to provide a street address and zip, or leave blank?
  5. Default referral source? (most use LinkedIn)
```

Then it asks for your **search preferences** (locations, seniority, sub-categories, tech stack, salary floor, companies to avoid), seeded with reasonable guesses from the resume.

Everything gets written to `~/.auto-apply/`. You can edit the JSON files directly anytime.

If your resume is in DOCX or RTF, export it to PDF first (Word and Google Docs both have an "Export as PDF" option).

## What the skill does

Three workflows, triggered by phrasing:

| You say | It does |
|---|---|
| "find jobs", "search for roles", "what's new" | Searches GrepJob, filters already-applied + companies-to-avoid, presents a table |
| "apply to these", "go", specific URLs | Navigates to each, reads the form, fills it from your profile, attaches your resume, submits, verifies the confirmation, logs to CSV |
| "what have I applied to", "show history", "status" | Prints `~/.auto-apply/applications.csv` |

The skill verifies every submission landed before logging it. This matters — ATS forms silently reject on unchecked GDPR boxes, missing terms checkboxes, and stuck EEO dropdowns. If the verification fails, the skill looks for a recoverable error (e.g. "This field is required" next to a terms box), fixes it, and retries once.

## File layout

```
~/.auto-apply/
  ├── profile.json        # Your personal info used to fill forms
  ├── preferences.json    # What jobs you're looking for
  └── applications.csv    # Every application you've submitted
                          # columns: date_applied, company, role, url, ats,
                          #          location, salary_min, salary_max, status, notes
```

Back these up. `profile.json` has your PII; don't share it. `applications.csv` is your application history and prevents the skill from applying to the same job twice.

## Supported ATS

Only these URL patterns work:

- `jobs.ashbyhq.com/*`
- `boards.greenhouse.io/*`, `job-boards.greenhouse.io/*`
- `boards.eu.greenhouse.io/*`, `job-boards.eu.greenhouse.io/*`
- `jobs.lever.co/*`, `jobs.eu.lever.co/*`

Companies that run Greenhouse but host the form on their own domain (Asana at asana.com, MongoDB at mongodb.com, Stripe at stripe.com, etc.) will be **skipped** — the Chrome extension doesn't inject on those domains. The skill notes this with `status=skipped, notes="custom domain"`.

## Customize it

The skill files live at `~/.claude/skills/auto-apply/` after install. Edit:

- `SKILL.md` — the main instructions Claude loads
- `references/field-mapping.md` — how profile fields map to form questions
- `references/ats-quirks.md` — known gotchas per ATS
- `templates/profile.json` — the template used on first-run

If you want defaults different from mine (e.g. always decline EEO with `"Prefer not to say"` instead of `"Decline to self-identify"`), edit the template.

## Reset / reconfigure

```
/auto-apply reconfigure profile
/auto-apply reset preferences
```

Or just edit `~/.auto-apply/*.json` directly.

## Troubleshooting

**Skill doesn't trigger on `/auto-apply`** — restart Claude Code, and confirm the skill is at `~/.claude/skills/auto-apply/SKILL.md`.

**"MCP server not available"** — double-check the three MCPs are configured in your Claude settings. Try `ls ~/.claude/settings.json` and confirm `mcp__grepjob-autofill__*`, `mcp__grepjob__*`, and `mcp__claude-in-chrome__*` tools appear in the tool list.

**Autofill fails on every job with "content script not loaded"** — the Chrome extension isn't installed or isn't running. Open Chrome, check `chrome://extensions/` for the GrepJob autofill extension.

**Submissions silently fail** — check the verify step's output. Usually a missing "I agree" checkbox or GDPR consent box. The skill should catch and retry, but some forms have non-standard selectors.

## License

Source-available under the [PolyForm Noncommercial License 1.0.0](../LICENSE). Free for personal and noncommercial use; commercial use requires a separate license.

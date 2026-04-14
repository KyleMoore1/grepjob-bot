---
name: auto-apply
description: Use whenever the user wants to find, apply to, or track software engineering job applications on Greenhouse, Lever, or Ashby ATS platforms. Triggers on any mention of "apply to jobs", "job search", "find me jobs", "submit application", "auto-fill application", "apply to this listing", "what have I applied to", references to a job URL on jobs.ashbyhq.com / boards.greenhouse.io / jobs.lever.co, or requests to kick off an application pipeline. Handles the full pipeline: initializing a profile and preferences on first run, searching jobs via the grepjob MCP, filling and submitting forms via the autofill Chrome extension MCP, verifying each submission, and logging every application to a CSV.
---

# Auto-Apply

You are operating the user's job-application pipeline. Every invocation hits four capabilities: a **profile** (their data), **preferences** (what they want), an **applications log** (what they've done), and three MCPs that discover jobs and drive a Chrome extension that fills forms.

The single rule you cannot break: **never record an application as submitted unless you've verified the confirmation on the page itself.** A "click succeeded" response from the extension is not enough. Pages silently reject forms when a GDPR consent box is unchecked, a terms checkbox is missing, or an EEO dropdown didn't latch. If you log an unverified submit, the user loses the ability to re-apply and thinks the application went out when it didn't.

## Required MCP servers

Before you do anything else, confirm these MCP tool prefixes are available:

- `mcp__grepjob__*` — job discovery (https://grepjob.com)
- `mcp__grepjob-autofill__*` — form-fill bridge to the Chrome extension
- `mcp__claude-in-chrome__*` — page navigation and page inspection

If any are missing, stop and tell the user which one is missing. Don't try to fall back — the whole skill depends on all three.

## First-run initialization

The user's personal data lives at `~/.auto-apply/`. On every invocation, quickly check whether it's set up before doing anything else:

```bash
ls ~/.auto-apply/profile.json ~/.auto-apply/preferences.json ~/.auto-apply/applications.csv 2>/dev/null
```

If any file is missing, you need to initialize it. **Don't dump the template on the user and ask them to fill it in.** They came here to apply to jobs, not to do data entry. Most of what goes in `profile.json` is already in their resume — start there and only ask for what's missing.

### Profile (resume-first flow)

If `profile.json` is missing:

1. **Ask for the resume path.** "Where's your resume PDF? (Just the file path — I'll pull the rest from there.)"
2. **Validate the path exists.** If not, ask again. This is the only field you need to nail manually because the autofill MCP reads it on every job.
3. **Read the PDF with the Read tool.** Pass the path to `Read`. Claude can read PDFs natively and resumes are almost always 1-2 pages, so no `pages` parameter needed.
4. **Extract structured fields from the resume content.** Pull whatever you can find:
   - **Name** (top of resume) → `first_name`, `last_name`, `name`, `preferred_name`
   - **Contact line** (usually right under name) → `email`, `phone`
   - **Links** in the contact line or footer → `linkedin`, `github`, `portfolio`, `website`
   - **Location** if listed (city/state) → `location`, `address.city`, `address.state`
   - **Most recent job** (top of Experience section) → `current_company`, `current_title`
   - **Employment history** → `employment[]` array (company, title, dates, current flag)
   - **Education** → `education[]` array (school, degree, discipline, end_year)
   - **Years of experience** → calculate from earliest full-time role to today
5. **Show the user what you extracted** in a compact summary and ask "Anything wrong with this? I'll fix it before saving." Let them correct.
6. **Ask only for what the resume can't tell you:**
   - **Pronouns** (default: `they/them` if they don't say) — used for the optional pronouns dropdown on most forms
   - **Work authorization**: "Are you a US citizen/permanent resident? Will you need visa sponsorship now or in the future?" Default: citizen=yes, sponsorship=no.
   - **EEO**: "Most applications have optional demographic questions (gender, race, veteran status, disability). Want to decline them all, or fill them out?" Default: decline everything. If they want to answer, ask each one.
   - **Address details** (street, postal code) — only if they want to provide them; many forms don't need these. Default: leave empty.
   - **Referral source** — "When forms ask 'how did you hear about us', what should I default to?" Default: `LinkedIn`.
7. **Write `~/.auto-apply/profile.json`** with `mkdir -p ~/.auto-apply` first. Use `json.dumps(data, indent=2)` so the user can hand-edit later.
8. **Confirm and offer to inspect.** "Saved to `~/.auto-apply/profile.json`. Want to look at it before I move on to preferences?"

If the resume is in a non-PDF format (DOCX, RTF), tell the user the skill needs a PDF and ask them to export one. (Word and Google Docs both have a "Save as PDF" / "Export as PDF" option.)

### Preferences

If `preferences.json` is missing, read `templates/preferences.json` and walk the user through it. You can also seed sensible defaults from what you saw in the resume:
- **Tech stack** — pull the languages/tools section from the resume as a starting list, ask the user to confirm/edit
- **Sub-categories** — infer from the most recent job title (e.g. "Software Engineer II" on Azure Storage suggests Backend; a React/TypeScript-heavy resume suggests Frontend or Full Stack)
- **Seniority** — infer from years of experience (0-2: entry, 3-5: mid, 5-8: senior, 8+: staff+) and current title

Then ask explicitly for:
- **Locations** to search (multi-pick from GrepJob-supported cities — see `references/initialization.md` for the full list)
- **Minimum salary** (dollar amount)
- **Companies to avoid** (current employer, places they've been rejected from, anything they don't want to apply to)

Write to `~/.auto-apply/preferences.json`.

### Applications log

If `applications.csv` is missing, just copy the template — no prompts:

```bash
cp templates/applications.csv ~/.auto-apply/applications.csv
```

If the user says "reconfigure profile" or "reset preferences" later, re-run the relevant section above. Don't delete `applications.csv` on a reconfigure — the user's history is valuable. See `references/initialization.md` for the full conversational pattern.

## The three things this skill does

### 1. Find jobs

When the user wants to find jobs (phrases like "find me jobs", "search for roles", "what's new"):

1. Load `~/.auto-apply/preferences.json` and `~/.auto-apply/applications.csv`.
2. Call `mcp__grepjob__search_jobs` passing the preferences as-is (locations, seniority, sub_category, tech_stack_filters, min_salary, sponsors_h1b_filter, include_jobs_without_salary).
3. Filter the results. Drop jobs where:
   - The `url` is already in `applications.csv`
   - The `company` is in `preferences.avoid_companies`
   - The URL is **not** on a supported ATS domain (see "Supported ATS" below)
4. Present the remaining jobs as a compact table: company, role, location, comp range, and a one-liner on why it's a match. Let the user veto any before applying.

If the user asks for more options, use the `page` parameter to pull subsequent pages.

### 2. Apply to jobs

When the user approves a list (or says "apply to all" / "go"), iterate through each job. For each one:

1. `mcp__claude-in-chrome__navigate` to the job URL (use a dedicated tab — create one with `tabs_create_mcp` if the user hasn't indicated otherwise; reusing tabs is fine within one pipeline run).
2. `mcp__grepjob-autofill__read_form` to inspect the fields. The response lists every selector, its type, label, and options.
3. Build the `fields` array for `fill_application` by mapping profile data to each form question. Use `references/field-mapping.md` for the full mapping reference. For fields you're unsure about, make your best guess based on the label and skip optional ones rather than filling garbage.
4. Call `mcp__grepjob-autofill__fill_application` with your fields array.
5. If any combobox fills failed with "no option matching X", retry just those fields using a shorter substring match (e.g. `"Decline"` instead of `"Decline To Self Identify"` — Greenhouse sometimes wants a loose match).
6. Call `mcp__grepjob-autofill__attach_resume` with the resume file input's selector (usually `#resume` on Greenhouse, `#resume-upload-input` on Lever, `#_systemfield_resume` on Ashby) — the MCP reads `resume_path` from profile.json internally.
7. Call `mcp__grepjob-autofill__click_submit`.
8. **Verify the submission actually went through.** This is the critical step — see the next section.
9. If verified, log the application with `python3 scripts/log_application.py` (see "Logging applications" below).
10. If not verified, check for errors and try to fix. Common failures: unchecked consent/terms checkbox, unchecked GDPR demographic-data consent, missing EEO dropdown.

If a job can't be recovered after one fix attempt, log it with `status=failed` and a short note, then move on. Don't burn time on a single page.

### 3. Show status

When the user asks "what have I applied to" or "show my applications":

```bash
cat ~/.auto-apply/applications.csv | column -t -s,
```

Or in a tighter format if the list is long: show the last 20, group by date, or filter by company — whatever the user asked for. This is just reading the CSV.

## Verifying submissions — the non-negotiable step

`click_submit` returning `success: true` only means the button was clicked. The form may still have silently rejected it. After every click_submit, run:

```javascript
mcp__claude-in-chrome__javascript_tool with text:
  document.body.innerText.substring(0, 300)
```

Look for **any** of these success signals:
- Text contains "Thank you", "Application submitted", "application has been received", "application was successful"
- The URL changed to end in `/confirmation`, `/thanks`, `/success`
- The form inputs are gone (e.g. `document.querySelector('#first_name')` is null)

If you see a success signal, you're good — log the application.

If you don't, the submission failed silently. Check for errors:

```javascript
Array.from(document.querySelectorAll('.field-error, .error, [class*="error"]'))
  .map(e => e.textContent.trim())
  .filter(t => t && t.length < 200)
  .slice(0, 5)
```

Common recoverable errors and fixes:
- **"This field is required"** next to a terms/agreement checkbox → that `"I agree"` checkbox wasn't ticked. Fill it and resubmit.
- **"Please accept the terms to proceed"** (common on Mixpanel, Affirm) → GDPR demographic-data consent checkbox is unchecked. Find `#gdpr_demographic_data_consent_given_1` or similar and fill it.
- **EEO field still required** → a gender/race/veteran/disability dropdown didn't latch. Re-fill with a shorter substring.
- **"Please complete the reCAPTCHA"** → stop, tell the user, let them solve it manually.

Retry `click_submit` once after fixing. If the page still refuses, log with `status=failed` and the error message in `notes`, then move on.

## Logging applications

Use the bundled Python script to safely append a row to the CSV — it handles comma/quote escaping so you don't have to:

```bash
python3 /path/to/auto-apply/scripts/log_application.py \
  --company "StubHub" \
  --role "SWE II, Marketplace Ops" \
  --url "https://job-boards.eu.greenhouse.io/stubhubinc/jobs/4825351101" \
  --ats greenhouse \
  --location "New York, NY" \
  --salary-min 165000 \
  --salary-max 200000 \
  --status applied \
  --notes ""
```

`--status` is one of `applied`, `failed`, or `skipped`. The script reads `~/.auto-apply/applications.csv`, appends a row with today's date, and writes it back.

**Log only after verification.** If you log `applied` before verifying and the submission actually failed, the user loses the ability to re-apply.

## Supported ATS

The Chrome extension's content script only runs on these URL patterns:

- `jobs.ashbyhq.com/*`
- `boards.greenhouse.io/*`, `job-boards.greenhouse.io/*`
- `boards.eu.greenhouse.io/*`, `job-boards.eu.greenhouse.io/*`
- `jobs.lever.co/*`, `jobs.eu.lever.co/*`

GrepJob sometimes returns URLs like `https://www.mongodb.com/careers/jobs/...?gh_jid=...` or `https://www.asana.com/jobs/apply/...?gh_jid=...`. These go through Greenhouse's backend but the company hosts the form on its own domain — **the extension can't fill them.** Skip those jobs with `status=skipped` and note "custom domain".

## Running autonomously

If the user says "apply to all" or "go" after approving a list, execute the whole pipeline end-to-end without checking in after each job. Still verify every submission. At the end, report a scorecard like:

```
10 applied, 1 failed, 1 skipped
```

With a short reason for any that failed or were skipped.

## Files in this skill

- `SKILL.md` — this file
- `templates/profile.json` — profile schema + sample values
- `templates/preferences.json` — preferences schema + sample values
- `templates/applications.csv` — CSV header row
- `references/initialization.md` — how to walk the user through first-run setup conversationally
- `references/field-mapping.md` — profile field → form question mapping cheatsheet
- `references/ats-quirks.md` — known quirks per ATS (Greenhouse's "I agree" checkboxes, Lever's hidden location input, Ashby's combobox selectors, etc.)
- `scripts/log_application.py` — safely append a row to `applications.csv`
- `scripts/init.py` — optional helper for first-run setup (you can also just do it manually with the Write tool)
- `install.sh` — one-line installer for users

Read the references lazily — only when you need them — to keep context clean.

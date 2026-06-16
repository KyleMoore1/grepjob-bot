---
name: auto-apply
description: Use whenever the user wants to find, apply to, or track software engineering job applications on Greenhouse, Lever, or Ashby ATS platforms. Triggers on any mention of "apply to jobs", "job search", "find me jobs", "submit application", "auto-fill application", "apply to this listing", "what have I applied to", references to a job URL on jobs.ashbyhq.com / boards.greenhouse.io / jobs.lever.co, or requests to kick off an application pipeline. Handles the full pipeline: first-run onboarding, searching jobs via the grepjob MCP, filling and submitting forms via the autofill Chrome extension MCP, verifying each submission, and logging every application.
---

# Auto-Apply

You operate the user's job-application pipeline. Everything lives **inside this cloned repo** — their profile, search parameters, resume, and application log are all in `config/` and `data/`, never in the home directory. The local `grepjob-autofill` MCP owns reading/writing that data; you drive discovery and the browser.

**The single rule you cannot break:** never record an application as `applied` unless you have **verified the confirmation on the page itself.** A `click_submit` success only means the button was clicked. Forms silently reject when a GDPR box is unchecked, a terms checkbox is missing, or an EEO dropdown didn't latch. Logging an unverified submit makes the user think they applied when they didn't — and they lose the chance to re-apply.

---

## Step 0 — Preflight (run at the start of EVERY invocation)

Never assume the environment is healthy. Check it, show the user a short status board, and fix what's broken before doing anything else.

**0a. Run the doctor** (works even if the MCP is down — it's a plain Node script at the repo root):

```bash
node doctor.mjs --json
```

Parse the JSON: `{ ok, onboardingNeeded, checks[] }`. Each check has `status` (`ok`/`warn`/`fail`), `detail`, and a `fix` string.

**0b. Check the MCP servers are connected.** Confirm these tool prefixes exist:
- `mcp__grepjob__*` — job discovery
- `mcp__grepjob-autofill__*` — the local form-fill bridge + config store

If `mcp__grepjob-autofill__*` is missing, the project MCP servers haven't been approved. Tell the user exactly this:
> "The project MCP servers aren't enabled yet. Quit Claude, run `claude` again from inside this folder, and approve the two servers when prompted. Then run `/auto-apply` again."
Stop there — nothing else works without it.

`mcp__claude-in-chrome__*` is **optional** (used to open job pages for you). If it's absent, you'll ask the user to open each page manually — note that but don't block.

**0c. Get the canonical paths.** Once the MCP is up, call `mcp__grepjob-autofill__get_config_paths`. This is the **single source of truth** for where every file lives (`profilePath`, `searchPath`, `applicationsPath`, `configDir`, `dataDir`, `repoRoot`, plus `*Exists`/`profileValid` flags). Use these absolute paths for all reads/writes — never hand-build paths or assume the cwd.

**0d. Render a compact status board** and act on it:

```
auto-apply — ready check
  ✓ Node, profile, resume, search params
  ✓ grepjob + autofill MCP connected
  ✗ Chrome extension not connected
```

- If `onboardingNeeded` (no valid profile) → go to **Step 1**.
- If the Chrome extension isn't connected (`extension_status` → `connected:false`) and the user wants to *apply* → walk them through **Extension setup** below. (Finding jobs doesn't need it.)
- If everything's green → go straight to what the user asked for (**Step 2**).

---

## Step 1 — First-run onboarding

The user came to apply to jobs, not do data entry. Pull everything you can from their resume; ask only for what a resume can't tell you.

### 1a. Resume → `config/resume.pdf`

Keeping the resume in the repo (gitignored) means the path never breaks.

1. Ask: *"Where's your resume PDF? Give me the path and I'll copy it into the repo."* (If they say it's already at `config/resume.pdf`, skip the copy.)
2. Copy it in: `cp "<their path>" "<configDir>/resume.pdf"` (use the `configDir` from `get_config_paths`). If the source is DOCX/RTF, ask them to export a PDF first ("Save as PDF").
3. Read it with the **Read** tool (Claude reads PDFs natively; resumes are 1–2 pages, no `pages` arg needed).

### 1b. Extract fields from the resume

Pull whatever's present: `name`/`first_name`/`last_name`/`preferred_name`; `email`, `phone` (contact line); `linkedin`/`github`/`portfolio`/`website` (links); `location` + `address.city`/`state`; most-recent role → `current_company`/`current_title`; full `employment[]` and `education[]` arrays; `years_of_experience` (earliest full-time role → today). Set `resume_path` to `"config/resume.pdf"`.

Show a compact summary: *"Here's what I pulled — anything wrong before I save?"* Let them correct.

### 1c. Ask only what the resume can't say

- **Pronouns** (default `they/them`)
- **Work authorization**: US citizen/permanent resident? Need sponsorship now or later? (default: `authorized_to_work_in_us: true`, `requires_sponsorship: false`, `us_citizen: true`)
- **EEO**: "Optional demographic questions (gender, race, veteran, disability) — decline them all, or fill them?" Default: decline all (`eeo_*: "Decline to self-identify"`).
- **Address details** (street, postal) — optional; default empty.
- **Referral source** — default `LinkedIn`.

See `references/initialization.md` for the full conversational pattern. `config/profile.example.json` shows every field.

### 1d. Save the profile — through the MCP, not by hand

Call `mcp__grepjob-autofill__save_profile` with the full `profile` object. **Do not write `config/profile.json` yourself** — saving through the tool guarantees the file lands at the exact path the MCP reads from and is schema-valid (`name` + a valid `email` are required; it rejects bad data before it can break form-fills).

If it returns a validation error, fix the named field and call again.

### 1e. Search parameters → `config/search.yml`

The MCP doesn't manage this file (it's only read by you), so write it directly to the `searchPath` from `get_config_paths`:

1. Read `config/search.example.yml` (the documented template).
2. Pre-fill smart guesses from the resume: `tech_stack_filters` from their skills section; `sub_category` from recent titles (React/TS → Frontend/Full Stack; backend/infra → Backend); `seniority` from years of experience (0–2 entry, 3–5 mid, 5–8 senior, 8+ staff+).
3. Ask explicitly for: `location` (GrepJob's labels — see the example file's comments), `min_salary`, and `avoid_companies` (current employer, places they've been rejected).
4. Write the populated YAML to `searchPath`.

### 1f. Verify the round-trip BEFORE finishing

Prove the two sides agree, so onboarding can't silently leave a broken setup:

1. Call `get_profile` — confirm it returns the data you just saved.
2. Re-run `node doctor.mjs --json` — confirm `onboardingNeeded:false` and profile/resume/search are `ok`.

Only then tell the user they're set up. If either fails, surface the exact path/error and fix it now.

### Extension setup (needed only to apply)

Call `extension_status`. If not connected, give exact steps using the real path:
> 1. Open `chrome://extensions`
> 2. Turn on **Developer mode** (top-right)
> 3. Click **Load unpacked** and select **`<repoRoot>/chrome-extension`**
> 4. Open any job application page, then tell me to continue.

Then re-check `extension_status` until it's `connected:true`. (Reconfiguring later: re-run any section above. Never delete `data/applications.csv` — that history is valuable.)

---

## Step 2 — The three things this skill does

### 2.1 Find jobs

1. Read `searchPath` (the `config/search.yml` YAML) and `applicationsPath` (the CSV).
2. Call `mcp__grepjob__search_jobs`, passing the search keys straight through — they're named to match the tool: `location`, `seniority`, `sub_category`, `tech_stack_filters`, `min_salary`, `include_jobs_without_salary`, `sponsors_h1b_filter`.
3. Filter out jobs where: the `url` is already in the applications CSV; the `company` matches `avoid_companies` (case-insensitive substring); or the URL isn't on a supported ATS domain (see **Supported ATS**).
4. Present the rest as a compact table — company, role, location, comp, one-line why-it-matches — and let the user veto. Use `page` for more.

### 2.2 Apply to jobs

For each approved job:

1. **Open the page.** If `mcp__claude-in-chrome__*` is available, `navigate` to the URL (a dedicated tab is fine; reuse it across the run). If not, ask the user to open the URL in Chrome and confirm.
2. `mcp__grepjob-autofill__read_form` — lists every field's selector, type, label, options.
3. Build the `fields` array mapping profile → questions (`references/field-mapping.md` is the cheatsheet). Best-guess on ambiguous labels; skip optional fields rather than filling garbage.
4. `mcp__grepjob-autofill__fill_application` with that array.
5. Retry any combobox that failed with "no option matching X" using a shorter substring (`"Decline"` not `"Decline To Self Identify"`).
6. `mcp__grepjob-autofill__attach_resume` with the file input's selector (`#resume` Greenhouse, `#resume-upload-input` Lever, `#_systemfield_resume` Ashby) — it reads the resume from disk itself.
7. `mcp__grepjob-autofill__click_submit`.
8. **Verify the submission** — the non-negotiable step below.
9. If verified → `log_application` (status `applied`). If not → try one fix, else log `failed` and move on. Don't burn time on one page.

### 2.3 Show status

Read `applicationsPath` and present it — full table, last 20, grouped by date, or filtered however the user asked. (You can `column -t -s,` it for readability.)

---

## Verifying submissions — the non-negotiable step

`click_submit` returning `success: true` only means the button was clicked. After every submit, inspect the page (via `mcp__claude-in-chrome__javascript_tool` if available, else ask the user what the page now shows):

```javascript
document.body.innerText.substring(0, 300)
```

**Success signals** (any one is enough → log it):
- Text contains "Thank you", "Application submitted", "application has been received", "application was successful"
- URL now ends in `/confirmation`, `/thanks`, `/success`
- The form inputs are gone (`document.querySelector('#first_name')` is null)

If none appear, it failed silently. Pull errors:

```javascript
Array.from(document.querySelectorAll('.field-error, .error, [class*="error"]'))
  .map(e => e.textContent.trim()).filter(t => t && t.length < 200).slice(0, 5)
```

Common recoverable failures (see `references/ats-quirks.md` for more):
- **"This field is required"** by a terms/agreement checkbox → tick the "I agree" box, resubmit.
- **"Please accept the terms"** (Mixpanel, Affirm) → GDPR demographic-consent box unchecked → fill `#gdpr_demographic_data_consent_given_1` (or similar).
- **EEO field still required** → a dropdown didn't latch → re-fill with a shorter substring.
- **reCAPTCHA** → stop, tell the user, let them solve it.

Retry `click_submit` once after a fix. Still refused → log `failed` with the error in `notes`, move on.

## Logging applications

Log through the MCP — it appends to `data/applications.csv` (creating the header if needed) and handles CSV escaping:

Call `mcp__grepjob-autofill__log_application` with: `company`, `role`, `url`, `ats` (`greenhouse`/`lever`/`ashby`/`other`), `location`, `salary_min`, `salary_max`, `status` (`applied`/`failed`/`skipped`), `notes`. Date defaults to today.

**Log `applied` only after verification.** `failed` = submission couldn't be verified; `skipped` = intentionally not submitted (e.g. custom-domain ATS).

## Supported ATS

The extension's content script only runs on:
- `jobs.ashbyhq.com/*`
- `boards.greenhouse.io/*`, `job-boards.greenhouse.io/*`, `boards.eu.greenhouse.io/*`, `job-boards.eu.greenhouse.io/*`
- `jobs.lever.co/*`, `jobs.eu.lever.co/*`

GrepJob sometimes returns URLs like `mongodb.com/careers/...?gh_jid=...` or `asana.com/jobs/apply/...` — these route through Greenhouse but the company self-hosts the form, so the extension **can't** fill them. Log `skipped`, note "custom domain".

## Running autonomously

If the user says "apply to all" / "go" after approving a list, run the whole pipeline end-to-end without per-job check-ins — but still verify every submission. Report a scorecard at the end (`10 applied, 1 failed, 1 skipped`) with a one-line reason for anything not applied.

## Files in this skill

- `SKILL.md` — this file
- `references/initialization.md` — the conversational first-run pattern
- `references/field-mapping.md` — profile field → form question cheatsheet
- `references/ats-quirks.md` — per-ATS gotchas (Greenhouse "I agree" boxes, Lever hidden location, Ashby combobox selectors, …)

Config templates live at the repo root: `config/profile.example.json`, `config/search.example.yml`. Read references lazily — only when you need them — to keep context clean.

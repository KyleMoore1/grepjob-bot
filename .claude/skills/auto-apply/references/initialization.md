# Initialization — the conversational flow

When there's no valid profile (the preflight's `get_config_paths` shows `profileExists:false` or `profileValid:false`, and `doctor.mjs` reports `onboardingNeeded:true`), run this. **Don't dump the template on the user and ask them to fill it out** — they came to apply to jobs, not do data entry. Most of the profile lives in their resume; start there, parse aggressively, and only ask for what the resume can't tell you.

All paths come from `get_config_paths` (the single source of truth): `configDir`, `profilePath`, `searchPath`, `applicationsPath`, `repoRoot`. Never hand-build them.

## Profile (resume-first)

### Step 1: Get the resume into the repo

Keeping the resume inside the repo (gitignored) means its path can never break later.

> "Where's your resume PDF? Give me the path and I'll copy it into the repo."

Copy it to `<configDir>/resume.pdf`:

```bash
cp "<their path>" "<configDir>/resume.pdf"
```

If they already put it at `config/resume.pdf`, skip the copy. If it's a `.docx`/`.rtf`:

> "I can only parse PDFs. Open it in Word/Google Docs, export as PDF, and tell me the path."

### Step 2: Read the PDF

Use the `Read` tool on `config/resume.pdf`. Resumes are 1–2 pages so no `pages` parameter is needed — Claude reads the PDF natively.

### Step 3: Extract everything you can

| Profile field | Where to look |
|---|---|
| `name`, `first_name`, `last_name`, `preferred_name` | Top of the resume (largest text). Split on whitespace. |
| `email` | Contact line under the name. Look for `@`. |
| `phone` | Contact line. Normalize to `+1 XXX-XXX-XXXX` for US numbers. |
| `linkedin` | Look for `linkedin.com/in/...` |
| `github` | Look for `github.com/...` |
| `portfolio`, `website` | Any other URL in the contact line that isn't LinkedIn/GitHub |
| `location` | City, State if present (near the name or in the contact line) |
| `current_company` | Most recent entry under "Experience" |
| `current_title` | Title of most recent role |
| `employment[]` | Every job under Experience: company, title, start_date, end_date, current flag |
| `education[]` | Every entry under Education: school, degree, discipline, end_year |
| `years_of_experience` | Today minus the start date of the earliest full-time role (whole years) |

Always set `resume_path` to `"config/resume.pdf"`. If a field isn't on the resume, leave it for Step 5.

### Step 4: Confirm what was extracted

Show a compact summary, not the full JSON:

> Here's what I pulled from your resume:
> - **Name:** Kyle Moore
> - **Email:** kylem70698@gmail.com
> - **Phone:** +1 206-595-6734
> - **LinkedIn:** linkedin.com/in/kyle-moore1
> - **Current role:** Software Engineer II at Microsoft (Azure Storage), since June 2023
> - **Years of experience:** ~5
> - **Education:** BS Computer Science, Santa Clara University (2021)
>
> Anything wrong with this?

Wait for confirm/correct. Update your in-memory draft; don't re-show the whole summary unless asked.

### Step 5: Ask only for what's NOT on the resume

1. **Pronouns** — default `they/them` if they don't say.
2. **Work authorization** — "US citizen or permanent resident? Need visa sponsorship now or later?" Default: `us_citizen:true`, `authorized_to_work_in_us:true`, `requires_sponsorship:false`.
3. **EEO preferences** — "Optional demographic questions (gender, race, veteran, disability) — decline them all, or fill them?" Default: decline all (`eeo_*: "Decline to self-identify"`). If they fill, ask each.
4. **Address details** — street + zip; default empty (city/state already known).
5. **Referral source** — "When forms ask 'how did you hear about us', what's the default?" Default: `LinkedIn`.

### Step 6: Save through the MCP

Call `mcp__grepjob-autofill__save_profile` with the full `profile` object. **Do not write `config/profile.json` directly** — saving through the tool guarantees it lands at the exact path the MCP reads and is schema-valid (`name` + valid `email` required). If it returns a validation error, fix the named field and retry.

Then: "Saved. Want to peek at it before I set up your search parameters?"

### Resume can't be parsed

If the PDF is an image-only scan / encrypted / badly laid out:

> "I couldn't extract structured data from this PDF — it might be a scanned image. I'll ask you for each field instead."

Then ask for: name, email, phone, LinkedIn, GitHub (optional), location, current company, current title, years of experience, education — plus the five non-resume questions from Step 5 — and `save_profile`.

## Search parameters

The MCP doesn't manage `search.yml` (only the skill reads it), so write it yourself to the `searchPath` from `get_config_paths`. Start from `config/search.example.yml` (fully documented), seed guesses from the resume, and surface them as suggestions:

> Based on your resume I'd guess:
> - **Tech stack:** TypeScript, React, Python, Go (from your skills section)
> - **Sub-categories:** Backend, Full Stack
> - **Seniority:** mid level → senior (5 years as a SWE II)
>
> Sound right? And:
> - **Where do you want to work?** (pick multiple)
> - **Minimum salary?**
> - **Any companies to avoid?** (current employer, places that rejected you)

Keep the YAML keys exactly as in the example (`location`, `seniority`, `sub_category`, `tech_stack_filters`, `min_salary`, `include_jobs_without_salary`, `sponsors_h1b_filter`, plus `avoid_companies`, `preferred_companies`, `default_application_answers`, `notes_for_autofill`) — the first seven pass straight through to `mcp__grepjob__search_jobs`. The valid value vocabularies are listed in the example file's comments. Write the populated YAML to `searchPath`.

## Applications log

Nothing to do — the first `log_application` call creates `data/applications.csv` with its header automatically.

## Verify before finishing

1. `get_profile` → confirm it returns what you just saved.
2. `node doctor.mjs --json` → confirm `onboardingNeeded:false` and profile/resume/search are `ok`.

Only then tell the user onboarding is complete.

## Reconfigure flow

If the user says "reconfigure profile" / "redo my search" / "reset everything":

- Re-run the relevant section (resume-first for profile; re-write `search.yml` for search).
- **Never delete `data/applications.csv` unless they explicitly ask** — that history prevents re-applying to the same job.

## Updating the resume later

New resume? Either replace `config/resume.pdf` in place (the MCP uses the new file on next attach — `resume_path` stays `config/resume.pdf`), or re-run profile init to re-parse it if their title/employment changed. Don't re-parse on every run — only when asked or when the profile is missing.

# Initialization — the conversational flow

When `~/.auto-apply/profile.json` is missing, **don't dump the template on the user and ask them to fill it out.** They came to apply to jobs, not do data entry. Most of profile lives in their resume — start there, parse aggressively, and only ask for what the resume can't tell you.

## Profile (resume-first)

### Step 1: Get the resume

> "Where's your resume PDF? (Just paste the file path — I'll pull most of the profile straight from there.)"

Validate the path exists:

```bash
ls "$RESUME_PATH"
```

If the file doesn't exist, ask again. If it's a `.docx` or `.rtf`, tell the user:

> "I can only parse PDFs. Open it in Word/Google Docs and export as PDF, then send me the new path."

### Step 2: Read the PDF

Use the `Read` tool with the file path. Resumes are 1-2 pages so no `pages` parameter is needed. Claude reads the PDF natively.

### Step 3: Extract everything you can

Pull these from the resume content:

| Profile field | Where to look |
|---|---|
| `name`, `first_name`, `last_name`, `preferred_name` | Top of the resume (largest text). Split on whitespace. |
| `email` | Contact line under the name. Look for `@`. |
| `phone` | Contact line. Normalize to `+1 XXX-XXX-XXXX` for US numbers. |
| `linkedin` | Look for `linkedin.com/in/...` |
| `github` | Look for `github.com/...` |
| `portfolio`, `website` | Any other URL in the contact line that isn't LinkedIn/GitHub |
| `location` | City, State if present (often near the name or in the contact line) |
| `current_company` | Most recent entry under "Experience" (top of that section) |
| `current_title` | Title of most recent role |
| `employment[]` | Every job under Experience: company, title, start_date, end_date, current flag |
| `education[]` | Every entry under Education: school, degree, discipline, end_year |
| `years_of_experience` | Today minus the start date of the earliest full-time role (round to whole years) |

If a field isn't on the resume, leave it for Step 5.

### Step 4: Confirm what was extracted

Show the user a compact summary, not the full JSON:

> Here's what I pulled from your resume:
>
> - **Name:** Kyle Moore
> - **Email:** kylem70698@gmail.com
> - **Phone:** +1 206-595-6734
> - **LinkedIn:** linkedin.com/in/kyle-moore1
> - **GitHub:** github.com/KyleMoore1
> - **Location:** Microsoft is in NYC — should I use New York, NY?
> - **Current role:** Software Engineer II at Microsoft (Azure Storage), since June 2023
> - **Years of experience:** ~5
> - **Education:** BS Computer Science, Santa Clara University (2021)
>
> Anything wrong with this?

Wait for the user to confirm or correct. If they correct, update your in-memory draft and move on — don't re-show the full summary unless they ask.

### Step 5: Ask only for what's NOT on the resume

These never appear on resumes:

1. **Pronouns** — "What pronouns should I use? (he/him, she/her, they/them, etc.)"
   - Default if they don't say: `they/them`. It's the safest neutral default.

2. **Work authorization** — "Are you a US citizen or permanent resident? Will you need visa sponsorship now or in the future?"
   - Default: citizen=yes, sponsorship=no, authorized_to_work_in_us=yes.
   - If they need sponsorship: set `requires_sponsorship=true` and the autofill will answer accordingly.

3. **EEO preferences** — "Most applications have optional demographic questions (gender, race, veteran, disability). Want to decline them all, or fill them out?"
   - Default: decline everything (`eeo_gender = "Decline to self-identify"`, etc.).
   - If they want to answer, ask each: gender, race/ethnicity, veteran status, disability status, hispanic/latino. Most users decline all.

4. **Address details** — "Some forms ask for street and zip. You can leave those blank or fill them in. Want to provide them?"
   - Default: leave `address.street` and `address.postal_code` empty.
   - The city/state we already have from the resume (or the location they confirmed in step 4).

5. **Referral source** — "When forms ask 'how did you hear about us', what's the default? Most people use LinkedIn."
   - Default: `LinkedIn`.

That's it. Five quick questions vs. the 11+ in the old flow.

### Step 6: Save

```bash
mkdir -p ~/.auto-apply
```

Write the JSON to `~/.auto-apply/profile.json` with 2-space indent:

```python
import json
with open(os.path.expanduser("~/.auto-apply/profile.json"), "w") as f:
    json.dump(profile, f, indent=2)
```

Tell the user: "Saved. Want to peek at it before I move on?" Then move to preferences.

### Resume can't be parsed

If the PDF is unreadable (image-only scan, encrypted, badly formatted), fall back gracefully:

> "I couldn't extract structured data from this PDF — it might be a scanned image or have a complex layout. I'll ask you for each field instead."

Then ask for: name, email, phone, LinkedIn, GitHub (optional), location, current company, current title, years of experience, education (school/degree/discipline/year). Plus the five non-resume questions from Step 5.

## Preferences

Load `templates/preferences.json` as a starting point. You can seed defaults from what you learned about the user in the resume parse — surface these as suggestions, not silent defaults:

> Based on your resume I'd guess:
> - **Tech stack:** TypeScript, React, Python, Go (from your skills section)
> - **Sub-categories:** Backend, Full Stack (you mostly do backend at Azure but also web stuff)
> - **Seniority:** mid-level → senior (5 years experience as a SWE II)
>
> Sound right? And:
> - **Where do you want to work?** (you can pick multiple)
> - **Minimum salary?**
> - **Any companies to avoid?** (current employer, places that already rejected you, etc.)

### Locations

GrepJob's supported locations (multi-pick from this list):

```
Remote (US), New York NY, San Francisco CA, Seattle WA, Boston MA, Chicago IL,
Denver CO, Los Angeles CA, Atlanta GA, Austin TX, Washington DC, San Mateo CA,
Mountain View CA, Bellevue WA, Phoenix AZ, Tempe AZ, Santa Clara CA,
Menlo Park CA, Dallas TX, Miami FL, Redmond WA, Charlotte NC, San Jose CA,
Portland OR, Minneapolis MN
```

### Seniority

Options: `intern`, `entry level`, `mid level`, `senior`, `staff+`. Multi-pick.

### Sub-categories

Options: Backend, AI & ML, DevOps, Full Stack, Data Engineering, Security, Data Science, Frontend, Testing, Embedded, Mobile, Gaming. Multi-pick.

### Tech stack (optional)

The grepjob MCP supports a fixed enum — see its tool definition for the full list. Most users skip this filter or pick 2-3 core technologies. Don't overconstrain.

### Save

Write to `~/.auto-apply/preferences.json` with 2-space indent.

## Applications CSV

No prompting needed — copy the template:

```bash
cp <skill-dir>/templates/applications.csv ~/.auto-apply/applications.csv
```

Or if `cp` isn't convenient, just create an empty file with the header row:

```
date_applied,company,role,url,ats,location,salary_min,salary_max,status,notes
```

## Reconfigure flow

If the user says "reconfigure profile" or "redo my preferences" or "reset everything":

- Back up the existing file: `cp ~/.auto-apply/profile.json ~/.auto-apply/profile.json.bak.$(date +%s)`
- Re-run the relevant section above (resume-first for profile).
- **Don't delete `applications.csv` unless they explicitly ask** — their history is valuable and prevents re-applying to the same job.

## Updating the resume later

If the user gets a new version of their resume, they can either:

1. Just update `profile.resume_path` to the new file (the autofill MCP will use the new file on next attach), or
2. Re-run profile init to re-parse the new resume — useful if their employment/title changed.

Don't re-parse on every run — only when explicitly asked or when the profile file is missing.

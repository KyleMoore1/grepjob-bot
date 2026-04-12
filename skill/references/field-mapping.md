# Field mapping — profile → form question

`read_form` returns a field's `label`. This reference maps common labels to the profile field you should use. Match on lowercase substring, not exact string — `"First Name"`, `"Legal First Name"`, and `"first_name"` all map to `profile.first_name`.

When a label doesn't match anything here, use judgment: a text field asking about your company → `current_company`; a question about AI use or recent projects → pull from `preferences.notes_for_autofill` and/or `profile.current_title` + project name.

## Identity

| Label contains | Profile field |
|---|---|
| first name, legal first, preferred first | `first_name` or `preferred_name` |
| last name, family name, surname | `last_name` |
| full name, legal name, full legal | `name` |
| preferred name, name you go by, nickname | `preferred_name` |
| pronouns | `pronouns` (also map to EEO pronoun dropdown) |
| name pronunciation | leave empty, it's optional |

## Contact

| Label contains | Profile field |
|---|---|
| email | `email` |
| phone, telephone, mobile | `phone` (strip the `+1 ` prefix if the form has a separate country code) |
| phone country code | `phone_country_code` → usually "United States" in the dropdown |

## Links

| Label contains | Profile field |
|---|---|
| linkedin | `linkedin` |
| github | `github` |
| portfolio, personal website | `portfolio` or `website` |
| twitter, x.com | `twitter` |
| website | `website` |
| other links | leave empty |

## Location

| Label contains | Profile field |
|---|---|
| current location, where are you located, city | `location` (e.g. `"New York, NY"`) |
| location (city) — combobox | type the city name, let autocomplete match |
| state, province, where do you reside | `address.state` (often use the state full name like `"New York"`) |
| postal code, zip code | `address.postal_code` |
| street address | `address.street` (often leave empty, some required) |
| country | `"United States"` for US applicants |

**Lever quirk:** the location input has a hidden `selectedLocation` field that autocomplete populates. Our `fill_application` handles this but if a submit fails with "location required", re-fill the location field.

**Ashby quirk:** location is usually `input[placeholder="Start typing..."]`. Just fill it as a text field; the form accepts it.

## Work authorization

| Label contains | Profile field |
|---|---|
| authorized to work, legally authorized, work authorization | `authorized_to_work_in_us` → `"Yes"` / `"No"` |
| require sponsorship, visa sponsorship, H-1B, H1B, immigration sponsorship | `requires_sponsorship` → `"Yes"` / `"No"` |
| US citizen | `us_citizen` → `"Yes"` / `"No"` |

Most users: authorized yes, sponsorship no.

## Current role

| Label contains | Profile field |
|---|---|
| current company, current employer, where do you work | `current_company` |
| current title, current role, job title | `current_title` |
| years of experience, how many years | `years_of_experience` (or the matching bucket like `"4 - 6 Years"` from `preferences.default_application_answers.years_of_experience_bucket`) |
| salary expectations, compensation expectations, desired salary | `salary_expectations` |

## Referral

| Label contains | Profile field |
|---|---|
| how did you hear, how did you find, referral source | `referral_source` — typically `"LinkedIn"` |

## EEO / demographic

These are almost always optional. Default to declining unless the user has set them otherwise in profile.

| Label contains | Profile field |
|---|---|
| gender | `eeo_gender` |
| race, ethnicity | `eeo_race` |
| veteran | `eeo_veteran` |
| disability | `eeo_disability` |
| hispanic, latino | `eeo_hispanic_latino` |

**Decline value variations** — the same "decline" option is worded differently on different forms. Try shorter substrings if an exact match fails:
- `"Decline To Self Identify"` (Greenhouse)
- `"Decline to self-identify"` (Ashby)
- `"I don't wish to answer"` (some Greenhouse veteran/disability)
- `"I do not want to answer"` (some Greenhouse disability)
- `"Prefer not to say"` (Lever surveys, Notion radio)
- `"Prefer not to disclose"` (some Spotify radios)

When a fill fails with "no option matching", retry with `"Decline"` or `"don't wish"` as a substring.

## Education

| Label contains | Profile field |
|---|---|
| school, university, college | `education[0].school` |
| degree | `education[0].degree` |
| discipline, major, field of study | `education[0].discipline` |
| graduation year, end year | `education[0].end_year` |

Some Greenhouse forms have a `#school--0` combobox that autocompletes from a school list. Type the school name and it'll match.

## Agreement / consent checkboxes

These are **required** on many forms but default to unchecked. Read the label and check if it's an affirmation:

- "I agree", "I acknowledge", "I confirm", "I certify" — **check these**
- Terms of service, privacy policy, arbitration agreement, application truthfulness — **check these** (unless the user has a specific objection)
- Marketing consent, "contact me about future jobs" — optional, default unchecked
- GDPR demographic data consent (Mixpanel, etc.) — **check this** if the user filled in any demographic field

When in doubt, check `"I agree"` but never marketing opt-in.

## Cover letter / free-text questions

Some Airtable, Patreon, and startup forms ask questions like:
- "Describe the most recent product feature you built"
- "How are you using AI today?"
- "Why do you want to work here?"

Generate a response using:
- `preferences.notes_for_autofill` (user's base elevator pitch)
- Tailor it slightly to the job description if available
- Keep it to 3-5 sentences

Don't make up metrics or projects — stick to what's in the profile. If there's no reasonable answer, skip the field if optional.

## Resume upload

The field input selectors vary by ATS:
- Greenhouse: `#resume`
- Lever: `#resume-upload-input`
- Ashby: `#_systemfield_resume`

Always use `mcp__autofill__attach_resume` with the selector — don't pass the file contents directly. The MCP reads the file from `profile.resume_path` on disk, so as long as that path is correct the upload works.

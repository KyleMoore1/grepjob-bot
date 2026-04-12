# ATS quirks — what to watch for

Each ATS has recurring gotchas that trip up submissions. Learn these so you can recognize failure modes and fix them without starting from scratch.

## Greenhouse

URL patterns: `boards.greenhouse.io/*`, `job-boards.greenhouse.io/*`, `boards.eu.greenhouse.io/*`, `job-boards.eu.greenhouse.io/*`.

**"I agree" checkbox is usually required.** Many forms have a compliance checkbox near the bottom: "By submitting this application, I affirm that all statements are accurate..." This is a custom question without an obvious required star. Always check it — if you submit and the page comes back with "This field is required", that's the checkbox. Look for selectors like `#question_XXXXXXXXX\[\]_YYYYYYYYY` (note the escaped brackets).

**GDPR demographic consent is its own separate checkbox.** Mixpanel and a few others have `#gdpr_demographic_data_consent_given_1` that you must tick if you answered any of the demographic/EEO questions. Error message: `"Please accept the terms to proceed, or clear your responses."` Fix: check the box and resubmit.

**Combobox substring matching can fail.** Sometimes `"Decline To Self Identify"` fails with `"no option matching"` even though it's an option. Greenhouse's fill expects a case-sensitive match that our extension handles loosely but occasionally misses. Retry with a shorter fragment like `"Decline"`.

**"I agree" with a single option** — some forms have a radio group with one option literally called `"I agree"`. Fill with that string.

**Custom company domains.** Greenhouse is a backend for many companies, but some (Asana, MongoDB, Palantir on Lever, etc.) host the form on their own domain. URLs like `asana.com/jobs/apply/...?gh_jid=...` or `mongodb.com/careers/jobs/...` route the application through Greenhouse but the extension can't touch forms on non-Greenhouse domains. **Skip these** with `status=skipped, notes="custom domain"`.

**School combobox.** `#school--0` is a searchable autocomplete with the full list of accredited institutions. Just type the school name; substring match works.

**Education section is sometimes required.** If present with `#degree--0` and `#discipline--0`, fill them or submit fails.

## Lever

URL patterns: `jobs.lever.co/*`, `jobs.eu.lever.co/*`.

**`/apply` suffix.** The canonical URL ends without `/apply` but the form only loads when you're at `/apply`. Navigate to `<url>/apply` — if read_form returns empty fields, try that.

**Hidden `selectedLocation` input.** Lever's location autocomplete has a visible typeahead and a hidden field the form submits. Just typing into the visible input doesn't set the hidden one. The extension's `fill_application` handles this, but if submit fails with "location is required", re-fill the location field using a full city/state/country string like `"San Francisco, CA, United States"` — the autocomplete likes specific matches.

**Country select on US jobs.** There's often a separate `"What is your location?"` combobox with a country dropdown. Set to `"United States"` (value `"US"`).

**Multiple EEO surveys.** Lever supports multi-region EEO surveys. You may see multiple `radiogroup:surveysResponses[UUID][responses][fieldN]` selectors for gender, race, etc. — one per region (US EEOC, UK demographics, etc.). Fill each one with the "decline" option; `"Prefer not to disclose"` is usually the phrasing on Lever.

**Pronouns checkbox (not radio).** Lever's pronouns is a `checkbox` with exclusive-seeming options. Check one. You can skip it, it's optional.

**Marketing consent checkbox.** `input[name="consent[marketing]"]` — leave unchecked.

## Ashby

URL patterns: `jobs.ashbyhq.com/*`.

**Form is at `/application`.** Navigating to `jobs.ashbyhq.com/<org>/<id>` shows the job description; the form is on the same page or at `/<id>/application`. read_form handles both but on the first read after navigate, the form may not be expanded yet. If read returns empty fields, wait a beat and re-run (or check with `javascript_tool` that the `#form` element has inputs).

**Location combobox selector is generic.** The city/location field almost always uses `input[placeholder="Start typing..."]`. This is the only placeholder-scoped selector in the form, so it reliably maps to location. Fill as a plain text field; no autocomplete matching required — the form accepts free text.

**Date picker fields.** Some Ashby forms have `input[placeholder="Pick date..."]` for questions like "when can you start?". Fill with `"YYYY-MM-DD"` or `"MM/YYYY"` — the extension's input handler dismisses the date picker afterward.

**EEO mismatched labels.** Ashby sometimes renders EEO radio groups with the *wrong* label from the form definition. You'll see a radio group called `"LinkedIn Profile"` with pronoun options (He/Him, She/Her, etc.), or `"Gender"` with race options. Don't trust the label — trust the options. Match by option text.

**Yes/No buttons, not dropdowns.** Ashby's yes_no questions are a pair of buttons, not a select. Use `type: "yes_no"` with value `"Yes"` or `"No"` — the extension clicks the right button.

**Textarea for sponsorship (rare).** Most forms use yes_no for "require sponsorship", but some (like Envoy) use a textarea. Read the field type carefully and fill `"No"` as text in that case.

**OpenAI has application limits.** OpenAI's Ashby form says "Candidates may not apply more than 5 times in any 180 day span." If you submit more than that, the form will silently reject. Not something you can detect pre-submit — just flag it as a known quirk.

**Whatnot hub-location radio group.** Whatnot's jobs have a radio group labeled "How did you hear about this opportunity?" with options that are actually *locations* (Los Angeles CA, New York NY, etc.). Select the matching hub to the user's city, or `"N/A - I am not in one of the hub locations..."` if remote. Then fill the separate checkbox group (LinkedIn, Glassdoor, etc.) with the actual referral source.

## Universal quirks (any ATS)

**reCAPTCHA.** Rare but possible. If the page has a `g-recaptcha` widget that's interactive, stop — you can't solve CAPTCHAs. Tell the user to complete it manually, then click submit.

**Session timeouts.** If the user opened a tab, went away for 30 minutes, and now the form won't submit, the ATS session may have expired. Navigate to the URL fresh and start the fill over.

**Single-page reloads.** Some ATS forms are React SPAs that re-render mid-fill if the user tabs away. If field values get wiped between read_form and click_submit, it's probably a re-render. Do the entire fill + attach + submit without interruption.

**"Thank you" on a confirmation URL.** Success usually means:
1. The URL now ends with `/confirmation` (Greenhouse), `/thanks` (Lever), or `/<id>/submitted` (Ashby success variants)
2. The page body contains "Thank you" or "application has been received" or "Application submitted"
3. The form `<input>` elements no longer exist in the DOM

If none of these, submit didn't take.

# Privacy

This document describes exactly what data the grepjob-bot system reads, where it goes, and what does not happen with it.

## What's stored on your machine

All of your personal data lives in files on your own computer:

- `config/profile.json` — your name, email, phone, LinkedIn, GitHub, location, current employer, education, work authorization, and EEO preferences.
- `config/search.yml` — your job search parameters (your intent and dealbreakers written in your own words, locations, seniority, tech stack, minimum salary, company size/stage, companies to avoid).
- `data/applications.csv` — one row per application you've submitted: date, company, role, URL, status.
- `config/resume.pdf` — your resume.

All of these live inside the cloned `grepjob-bot` folder on your computer, and every one is gitignored — they are never committed, pushed, or uploaded anywhere by this software. They are read and written only by the Claude skill and the local MCP server running on your machine.

## What leaves your machine

Three outbound data flows exist. Each has a narrow, stated purpose:

1. **To the job application's ATS server (Greenhouse / Lever / Ashby).** When you apply to a job, the Chrome extension fills the form on the application page and submits it. Form content — name, email, phone, resume file, answers you provide — goes to the ATS, exactly as if you'd filled the form manually. This is the intended behavior.

2. **To `grepjob.com`.** The remote `grepjob` MCP receives job search queries (your preference filters: location, seniority, tech stack, salary floor). Responses are lists of public job listings. This is the only data that goes to a server operated by the maintainers of this project. Your profile, resume, application history, and anything in your `config/` or `data/` folders are **never** sent to grepjob.com.

3. **From the Chrome extension to the local MCP server via `ws://localhost:9876`.** This connection never leaves your computer. It carries messages between the extension and the MCP server (form field metadata, fill commands, submit confirmations). Localhost traffic is not visible to your ISP, your network, or any third party.

## What does not happen

- No telemetry. The extension and MCP do not report usage, errors, or performance data anywhere.
- No analytics. There is no tracking of which jobs you applied to, which forms you filled, or how often you use the system.
- No accounts. There is no sign-up, login, or user identity associated with this software. Everything is keyed to files on your machine.
- No cloud sync. Your profile and application history stay on your computer unless you manually copy them (e.g., to your own Dropbox).
- No resume parsing on a remote server. The Claude skill reads your resume PDF locally using Claude's built-in PDF reading capability. The resume contents are visible to Claude (since Claude is reading it), but are not sent to grepjob.com or any other server operated by this project.

## Data Anthropic sees

When you use this skill inside Claude Code, Claude itself (running on Anthropic's servers) sees whatever you send it in the conversation, which includes:

- The resume content, when Claude reads it during first-run setup
- Your profile fields, when Claude loads `config/profile.json` to fill a form
- Job listings returned by the `grepjob` MCP
- Form fields read from application pages

This is the same data exposure as any other task you give Claude. Anthropic's data handling is governed by [Anthropic's privacy policy](https://www.anthropic.com/legal/privacy). This project has no additional data-sharing arrangement with Anthropic beyond what Claude Code users already have.

## The Chrome extension's permissions

The extension requests:

- **`activeTab`, `tabs`** — to locate the job application tab you're viewing (matched by its Greenhouse/Lever/Ashby URL) and route fill/submit commands to it.
- **`alarms`** — to keep the service worker alive so the WebSocket to the MCP server stays connected.
- **`debugger`** — to dispatch trusted Escape keystrokes via Chrome DevTools Protocol. This is required for reliably closing React Select dropdown menus on Greenhouse forms, because synthetic keyboard events don't work when the Chrome window doesn't have focus. **While the extension is active, Chrome shows a yellow banner that says "GrepJob Autofill Bridge started debugging this browser." This is a Chrome warning about the debugger API — it's normal, not a sign of compromise.** The debugger API is only used to send keyboard and mouse input events; it is not used to read browser state, intercept network requests, or modify any tab other than the application page.
- **`host_permissions`** restricted to these domains: `jobs.ashbyhq.com`, `boards.greenhouse.io`, `job-boards.greenhouse.io`, `boards.eu.greenhouse.io`, `job-boards.eu.greenhouse.io`, `jobs.lever.co`, `jobs.eu.lever.co`. The extension cannot read or modify any other website.

## Questions or concerns

File an issue at [github.com/KyleMoore1/grepjob-bot](https://github.com/KyleMoore1/grepjob-bot).

#!/usr/bin/env node
// Standalone preflight for grepjob-bot.
//
// Zero dependencies, so it runs even when the MCP server is down (an MCP tool
// could never tell you the MCP itself is broken). All paths resolve relative to
// THIS file — the repo root — never the cwd.
//
//   node doctor.mjs          human-readable report
//   node doctor.mjs --json    machine-readable: { ok, onboardingNeeded, checks }
//
// The grepjob-bot skill runs the --json form at the start of every session.

import { existsSync, readFileSync, accessSync, constants } from "fs";
import { dirname, join, isAbsolute } from "path";
import { fileURLToPath } from "url";
import net from "net";

const ROOT = dirname(fileURLToPath(import.meta.url));
const CONFIG = join(ROOT, "config");
const DATA = join(ROOT, "data");
const WS_PORT = 9876;
const JSON_MODE = process.argv.includes("--json");

const checks = [];
const add = (id, label, status, detail = "", fix = "") =>
  checks.push({ id, label, status, detail, fix }); // status: ok | warn | fail

const rel = (p) => (p.startsWith(ROOT) ? "." + p.slice(ROOT.length) : p);

// 1. Node version
const nodeMajor = Number(process.versions.node.split(".")[0]);
add(
  "node",
  "Node.js >= 18",
  nodeMajor >= 18 ? "ok" : "fail",
  `found v${process.versions.node}`,
  nodeMajor >= 18 ? "" : "Install Node 18+ from https://nodejs.org"
);

// 2. Profile
const profilePath = join(CONFIG, "profile.json");
let profile = null;
if (!existsSync(profilePath)) {
  add(
    "profile",
    "Profile created",
    "fail",
    `missing ${rel(profilePath)}`,
    "Run /grepjob-bot in Claude to set up your profile"
  );
} else {
  try {
    profile = JSON.parse(readFileSync(profilePath, "utf-8"));
    const hasName = typeof profile.name === "string" && profile.name.trim().length > 0;
    const hasEmail =
      typeof profile.email === "string" && /.+@.+\..+/.test(profile.email);
    if (hasName && hasEmail) {
      add("profile", "Profile valid", "ok", profile.email);
    } else {
      const missing = [!hasName && "name", !hasEmail && "valid email"]
        .filter(Boolean)
        .join(" & ");
      add(
        "profile",
        "Profile valid",
        "fail",
        `missing ${missing}`,
        "Re-run /grepjob-bot onboarding"
      );
    }
  } catch (e) {
    add(
      "profile",
      "Profile valid",
      "fail",
      `not valid JSON (${e.message})`,
      "Fix config/profile.json or re-run /grepjob-bot onboarding"
    );
  }
}

// 3. Search params
const searchPath = join(CONFIG, "search.yml");
if (!existsSync(searchPath)) {
  add(
    "search",
    "Search params",
    "warn",
    `missing ${rel(searchPath)}`,
    "Onboarding creates it from config/search.example.yml"
  );
} else {
  const size = readFileSync(searchPath, "utf-8").trim().length;
  add(
    "search",
    "Search params",
    size > 0 ? "ok" : "warn",
    rel(searchPath),
    size > 0 ? "" : "search.yml is empty — copy it from config/search.example.yml"
  );
}

// 4. Resume (only checkable once we have a profile)
if (profile) {
  const rp = profile.resume_path;
  if (!rp) {
    add(
      "resume",
      "Resume present",
      "fail",
      "no resume_path in profile",
      "Put your resume at config/resume.pdf and set resume_path"
    );
  } else {
    const abs = isAbsolute(rp) ? rp : join(ROOT, rp);
    add(
      "resume",
      "Resume present",
      existsSync(abs) ? "ok" : "fail",
      rel(abs),
      existsSync(abs) ? "" : `Put your resume at ${rp} (relative to the repo root)`
    );
  }
}

// 5. data/ writable
try {
  accessSync(DATA, constants.W_OK);
  add("data", "data/ writable", "ok", rel(DATA));
} catch {
  add(
    "data",
    "data/ writable",
    existsSync(DATA) ? "fail" : "warn",
    existsSync(DATA) ? "exists but not writable" : "will be created on first log",
    existsSync(DATA) ? "Fix permissions on the data/ folder" : ""
  );
}

// 6. MCP bridge port — is a server listening? (proxy for "MCP is running")
const portListening = await new Promise((resolve) => {
  const sock = net.connect({ host: "127.0.0.1", port: WS_PORT }, () => {
    sock.destroy();
    resolve(true);
  });
  sock.on("error", () => resolve(false));
  sock.setTimeout(700, () => {
    sock.destroy();
    resolve(false);
  });
});
add(
  "mcp",
  `MCP bridge (port ${WS_PORT})`,
  portListening ? "ok" : "warn",
  portListening ? "a server is listening" : "nothing listening yet",
  portListening
    ? ""
    : "Start Claude in this folder and approve the project MCP servers (this is expected before first launch)"
);

// ── Output ───────────────────────────────────────────────────────────────────
const onboardingNeeded = checks.some(
  (c) => c.id === "profile" && c.status === "fail"
);
const anyFail = checks.some((c) => c.status === "fail");

if (JSON_MODE) {
  console.log(JSON.stringify({ ok: !anyFail, onboardingNeeded, checks }, null, 2));
} else {
  const icon = { ok: "✓", warn: "!", fail: "✗" };
  console.log("\ngrepjob-bot doctor\n");
  for (const c of checks) {
    console.log(
      `  ${icon[c.status]} ${c.label}${c.detail ? "  — " + c.detail : ""}`
    );
    if (c.status !== "ok" && c.fix) console.log(`      -> ${c.fix}`);
  }
  console.log(
    `\n${anyFail ? "Some checks need attention." : "All good."}` +
      `${onboardingNeeded ? " Run /grepjob-bot in Claude to finish setup." : ""}\n`
  );
}

process.exit(anyFail ? 1 : 0);

#!/usr/bin/env node
/**
 * @reoring/sds installer — copies the skill sets into place.
 *
 *   npx @reoring/sds              install both (claude + codex)
 *   npx @reoring/sds --claude     Claude Code skills only  -> ~/.claude/skills/
 *   npx @reoring/sds --codex      Codex CLI skills only    -> ~/.codex/skills/
 *   npx @reoring/sds --force      overwrite skills that already exist
 *   npx @reoring/sds --dry-run    show what would happen, write nothing
 *
 * Fail-closed by default: an existing skill directory is never overwritten
 * without --force (it may carry local modifications).
 */
"use strict";

const fs = require("fs");
const path = require("path");
const os = require("os");

const args = new Set(process.argv.slice(2));
const DRY = args.has("--dry-run");
const FORCE = args.has("--force");
const onlyClaude = args.has("--claude");
const onlyCodex = args.has("--codex");

if (args.has("--help") || args.has("-h")) {
  console.log(
    "usage: npx @reoring/sds [--claude|--codex] [--force] [--dry-run]"
  );
  process.exit(0);
}

const pkgRoot = path.join(__dirname, "..");
const home = process.env.SDS_HOME_OVERRIDE || os.homedir();

const targets = [];
if (!onlyCodex)
  targets.push({
    label: "Claude Code",
    src: path.join(pkgRoot, "claude"),
    dest: path.join(home, ".claude", "skills"),
  });
if (!onlyClaude)
  targets.push({
    label: "Codex CLI",
    src: path.join(pkgRoot, "codex"),
    dest: path.join(home, ".codex", "skills"),
  });

let installed = 0,
  skipped = 0;

for (const t of targets) {
  if (!fs.existsSync(t.src)) continue;
  const skills = fs
    .readdirSync(t.src, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name);

  console.log(`\n${t.label} -> ${t.dest}`);
  if (!DRY) fs.mkdirSync(t.dest, { recursive: true });

  for (const name of skills) {
    const from = path.join(t.src, name);
    const to = path.join(t.dest, name);
    const exists = fs.existsSync(to);

    if (exists && !FORCE) {
      console.log(`  skip    ${name}  (exists — use --force to overwrite)`);
      skipped++;
      continue;
    }
    if (DRY) {
      console.log(`  would ${exists ? "replace" : "install"} ${name}`);
      installed++;
      continue;
    }
    if (exists) fs.rmSync(to, { recursive: true, force: true });
    fs.cpSync(from, to, { recursive: true });
    // ensure bundled shell scripts stay executable
    const scriptsDir = path.join(to, "scripts");
    if (fs.existsSync(scriptsDir)) {
      for (const f of fs.readdirSync(scriptsDir)) {
        if (f.endsWith(".sh")) fs.chmodSync(path.join(scriptsDir, f), 0o755);
      }
    }
    console.log(`  ${exists ? "replace" : "install"} ${name}`);
    installed++;
  }
}

console.log(
  `\n${DRY ? "[dry-run] " : ""}done: ${installed} installed/updated, ${skipped} skipped.`
);
if (skipped > 0)
  console.log("re-run with --force to overwrite the skipped skills.");
console.log(
  "docs: https://github.com/reoring/sds  (Claude Code users can also install via /plugin)"
);

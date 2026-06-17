#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');

function read(relPath) {
  return fs.readFileSync(path.join(root, relPath), 'utf8').replace(/\r\n/g, '\n').trim();
}

// This fork ships only Codex, Claude, and pi, so there are no compact host rule
// copies to byte-compare anymore. What remains is the canary: assert the
// load-bearing rules survive verbatim in both the runtime source of truth
// (SKILL.md) and the compact always-on file (AGENTS.md). Rewording a rule in one
// place trips this, which is the reminder to propagate it to the other.
// Upgrade path: generate AGENTS.md from SKILL.md if this ever misses a real drift.
const INVARIANTS = [
  'naive heuristic',                       // ceiling-comment rule
  'ONE runnable check',                    // test reflex
  'flimsier algorithm',                    // robust-variant rule
  // the four "not lazy about" safety carve-outs: pin each so a reword in either
  // file can't silently drop one. These are continuous substrings present in both
  // files ("prevents data loss" because the full "error handling that prevents
  // data loss" wraps a line in SKILL.md).
  'input validation at trust boundaries',
  'prevents data loss',
  'security',
  'accessibility',
  'Lazy code without its check is unfinished', // one-check promoted to headline
];

let failed = false;

const sources = [
  ['skills/ponytail/SKILL.md', read('skills/ponytail/SKILL.md')],
  ['AGENTS.md', read('AGENTS.md')],
];
for (const phrase of INVARIANTS) {
  for (const [label, text] of sources) {
    if (!text.includes(phrase)) {
      console.error(`${label} is missing rule invariant: "${phrase}"`);
      failed = true;
    }
  }
}

if (failed) {
  console.error('Update AGENTS.md or SKILL.md so the shared rules match.');
  process.exit(1);
}

console.log(`${INVARIANTS.length} rule invariants present in SKILL.md and AGENTS.md.`);

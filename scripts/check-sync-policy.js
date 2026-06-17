#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const policy = JSON.parse(fs.readFileSync(path.join(ROOT, 'sync-policy.json'), 'utf8'));
const errors = [];

function fullPath(relPath) {
  return path.join(ROOT, relPath);
}

function hasFiles(target) {
  if (!fs.existsSync(target)) return false;
  const stat = fs.statSync(target);
  if (stat.isFile()) return true;
  if (!stat.isDirectory()) return false;
  for (const entry of fs.readdirSync(target)) {
    if (hasFiles(path.join(target, entry))) return true;
  }
  return false;
}

for (const relPath of policy.deny) {
  if (hasFiles(fullPath(relPath))) {
    errors.push(`denied path exists: ${relPath}`);
  }
}

for (const relPath of policy.preserve || []) {
  if (!fs.existsSync(fullPath(relPath))) {
    errors.push(`preserved fork file missing: ${relPath}`);
  }
}

const textExtensions = new Set([
  '.js', '.json', '.md', '.mjs', '.ps1', '.sh', '.toml', '.txt', '.yaml', '.yml',
]);

function scanConflictMarkers(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === '.git' || entry.name === 'node_modules') continue;
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      scanConflictMarkers(p);
      continue;
    }
    if (!textExtensions.has(path.extname(entry.name))) continue;
    const text = fs.readFileSync(p, 'utf8');
    if (/^(<<<<<<<|=======|>>>>>>>) /m.test(text)) {
      errors.push(`conflict marker found: ${path.relative(ROOT, p).replace(/\\/g, '/')}`);
    }
  }
}

scanConflictMarkers(ROOT);

if (errors.length) {
  console.error(errors.join('\n'));
  process.exit(1);
}

console.log('sync policy checks passed');

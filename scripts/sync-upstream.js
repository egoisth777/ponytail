#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const POLICY_PATH = path.join(ROOT, 'sync-policy.json');
const policy = JSON.parse(fs.readFileSync(POLICY_PATH, 'utf8'));

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: ROOT,
    encoding: 'utf8',
    stdio: options.capture ? 'pipe' : 'inherit',
  });
  if (result.status !== 0) {
    const detail = options.capture ? `\n${result.stderr || result.stdout}` : '';
    throw new Error(`${command} ${args.join(' ')} failed${detail}`);
  }
  return result.stdout || '';
}

function git(args, options) {
  return run('git', args, options);
}

function safePath(relPath) {
  const full = path.resolve(ROOT, relPath);
  const root = path.resolve(ROOT);
  if (full !== root && !full.startsWith(root + path.sep)) {
    throw new Error(`Refusing path outside repo: ${relPath}`);
  }
  return full;
}

function upstreamRef() {
  return `upstream/${policy.upstream.branch}`;
}

function pathExistsInUpstream(relPath) {
  const result = spawnSync('git', ['cat-file', '-e', `${upstreamRef()}:${relPath}`], {
    cwd: ROOT,
    encoding: 'utf8',
    stdio: 'pipe',
  });
  return result.status === 0;
}

function rm(relPath) {
  fs.rmSync(safePath(relPath), { recursive: true, force: true });
}

function ensureUpstreamRemote() {
  const existing = spawnSync('git', ['remote', 'get-url', 'upstream'], {
    cwd: ROOT,
    encoding: 'utf8',
    stdio: 'pipe',
  });

  if (existing.status !== 0) {
    git(['remote', 'add', 'upstream', policy.upstream.url]);
    return;
  }

  const current = existing.stdout.trim();
  if (current !== policy.upstream.url) {
    console.log(`upstream remote is ${current}; leaving it unchanged`);
  }
}

function importAllowedPaths() {
  for (const relPath of policy.allow) {
    safePath(relPath);
    if (pathExistsInUpstream(relPath)) {
      console.log(`import ${relPath}`);
      git(['restore', '--source', upstreamRef(), '--', relPath]);
    } else {
      console.log(`remove ${relPath} (missing upstream)`);
      rm(relPath);
    }
  }
}

function removeDeniedPaths() {
  for (const relPath of policy.deny) {
    console.log(`deny ${relPath}`);
    rm(relPath);
  }
}

function regenerate() {
  for (const command of policy.regenerate || []) {
    console.log(`run ${command}`);
    const [bin, ...args] = command.split(/\s+/);
    run(bin, args);
  }
}

ensureUpstreamRemote();
git(['fetch', '--no-tags', 'upstream', policy.upstream.branch]);
importAllowedPaths();
removeDeniedPaths();
regenerate();
console.log('upstream sync complete');

#!/usr/bin/env node

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const root = path.join(__dirname, '..');

function run(script, env, input = '') {
  return spawnSync(process.execPath, [path.join(root, 'hooks', script)], {
    env: { ...process.env, ...env },
    input,
    encoding: 'utf8',
  });
}

// Keep the base env clean so the default-dir checks are deterministic; the
// CLAUDE_CONFIG_DIR case sets it explicitly.
delete process.env.CLAUDE_CONFIG_DIR;

const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'ponytail-hooks-'));
const home = path.join(temp, 'home');
fs.mkdirSync(home, { recursive: true });

// USERPROFILE alongside HOME: os.homedir() reads USERPROFILE on Windows, HOME on POSIX.
const claudeEnv = {
  HOME: home,
  USERPROFILE: home,
  PONYTAIL_DEFAULT_MODE: 'full',
};
delete claudeEnv.PLUGIN_DATA;

let result = run('ponytail-activate.js', claudeEnv);
assert.equal(result.status, 0, result.stderr);
assert.equal(
  fs.readFileSync(path.join(home, '.claude', '.ponytail-active'), 'utf8'),
  'full',
);

// CLAUDE_CONFIG_DIR overrides ~/.claude for the flag file (issue #34).
const home2 = path.join(temp, 'home2');
fs.mkdirSync(home2, { recursive: true });
const customConfigDir = path.join(temp, 'custom-claude');
result = run('ponytail-activate.js', {
  HOME: home2,
  USERPROFILE: home2,
  CLAUDE_CONFIG_DIR: customConfigDir,
  PONYTAIL_DEFAULT_MODE: 'lite',
});
assert.equal(result.status, 0, result.stderr);
assert.equal(
  fs.readFileSync(path.join(customConfigDir, '.ponytail-active'), 'utf8'),
  'lite',
);
assert.equal(
  fs.existsSync(path.join(home2, '.claude', '.ponytail-active')),
  false,
  'flag must not land in ~/.claude when CLAUDE_CONFIG_DIR is set',
);

const copilotData = path.join(temp, 'copilot-data');
const strayPluginData = path.join(temp, 'plugin-data-shadow');
result = run('ponytail-activate.js', {
  HOME: home,
  USERPROFILE: home,
  COPILOT_PLUGIN_DATA: copilotData,
  PLUGIN_DATA: strayPluginData,
  PONYTAIL_DEFAULT_MODE: 'full',
});
assert.equal(result.status, 0, result.stderr);
assert.equal(fs.readFileSync(path.join(copilotData, '.ponytail-active'), 'utf8'), 'full');
assert.equal(
  fs.existsSync(path.join(strayPluginData, '.ponytail-active')),
  false,
  'copilot hooks must not write mode state to stray PLUGIN_DATA',
);
let output = JSON.parse(result.stdout);
assert.match(output.additionalContext, /PONYTAIL MODE ACTIVE — level: full/);

result = run(
  'ponytail-mode-tracker.js',
  {
    HOME: home,
    USERPROFILE: home,
    COPILOT_PLUGIN_DATA: copilotData,
    PLUGIN_DATA: strayPluginData,
  },
  JSON.stringify({ prompt: '/ponytail ultra' }),
);
assert.equal(result.status, 0, result.stderr);
assert.equal(fs.readFileSync(path.join(copilotData, '.ponytail-active'), 'utf8'), 'ultra');
assert.equal(
  fs.existsSync(path.join(strayPluginData, '.ponytail-active')),
  false,
  'copilot mode tracker must keep stray PLUGIN_DATA untouched',
);
output = JSON.parse(result.stdout);
assert.deepEqual(output, {});

fs.rmSync(temp, { recursive: true, force: true });
console.log('hook compatibility checks passed');

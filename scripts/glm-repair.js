#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const PATCH_PATH = path.join(ROOT, 'glm-repair.patch');
const apiKey = process.env.GLM_API_KEY;
const model = process.env.GLM_MODEL;
const baseUrl = (process.env.GLM_BASE_URL || 'https://open.bigmodel.cn/api/paas/v4')
  .replace(/\/+$/, '');
const testLogPath = process.env.SYNC_TEST_LOG || path.join(ROOT, 'sync-test.log');

function runGit(args) {
  const result = spawnSync('git', args, {
    cwd: ROOT,
    encoding: 'utf8',
    stdio: 'pipe',
  });
  return result.stdout || result.stderr || '';
}

function tail(text, maxChars) {
  return text.length > maxChars ? text.slice(text.length - maxChars) : text;
}

function readIfExists(file) {
  try {
    return fs.readFileSync(file, 'utf8');
  } catch {
    return '';
  }
}

function endpoint() {
  if (/\/chat\/completions$/.test(baseUrl)) return baseUrl;
  return `${baseUrl}/chat/completions`;
}

function extractPatch(text) {
  const fenced = text.match(/```(?:diff|patch)?\s*([\s\S]*?)```/i);
  const body = (fenced ? fenced[1] : text).trim();
  const firstDiff = body.search(/^diff --git /m);
  return firstDiff >= 0 ? body.slice(firstDiff).trim() + '\n' : '';
}

async function main() {
  if (!apiKey || !model) {
    console.log('GLM repair skipped: GLM_API_KEY and GLM_MODEL are required');
    return;
  }

  const policy = readIfExists(path.join(ROOT, 'sync-policy.json'));
  const diff = tail(runGit(['diff', '--no-ext-diff', '--binary']), 60000);
  const status = runGit(['status', '--short', '--untracked-files=all']);
  const testLog = tail(readIfExists(testLogPath), 30000);

  const prompt = `
Repair this upstream sync branch for the ponytail fork.

Fork policy:
${policy}

Rules:
- Return only a unified git diff patch, no prose.
- Preserve install.ps1 and install.sh.
- This fork supports Codex, Claude, and pi only.
- Do not reintroduce Claude marketplace packaging, Codex or Copilot plugin manifests, OpenCode/OpenClaw/Gemini adapters, .agents plugin marketplace files, or hooks/hooks.json.
- Make the smallest change needed for policy checks and tests to pass.

Git status:
${status}

Current diff:
${diff}

Failing check/test log:
${testLog}
`;

  const response = await fetch(endpoint(), {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: 'system',
          content: 'You are a repository maintenance agent. Output only apply-ready git patches.',
        },
        { role: 'user', content: prompt },
      ],
      temperature: 0.1,
    }),
  });

  if (!response.ok) {
    throw new Error(`GLM request failed ${response.status}: ${await response.text()}`);
  }

  const data = await response.json();
  const content = data?.choices?.[0]?.message?.content || '';
  const patch = extractPatch(content);
  if (!patch) {
    throw new Error('GLM did not return an apply-ready git diff');
  }

  fs.writeFileSync(PATCH_PATH, patch, 'utf8');
  const apply = spawnSync('git', ['apply', '--whitespace=fix', PATCH_PATH], {
    cwd: ROOT,
    encoding: 'utf8',
    stdio: 'pipe',
  });

  if (apply.status !== 0) {
    throw new Error(`GLM patch failed to apply:\n${apply.stderr || apply.stdout}`);
  }

  fs.rmSync(PATCH_PATH, { force: true });
  console.log('GLM repair patch applied');
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exit(1);
});

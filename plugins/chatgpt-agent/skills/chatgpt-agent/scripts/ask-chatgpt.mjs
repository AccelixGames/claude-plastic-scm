#!/usr/bin/env node

/**
 * ask-chatgpt.mjs
 * Codex CLI wrapper — ChatGPT Plus 인증으로 동작.
 * Claude 서브에이전트에서 Bash로 호출 가능.
 *
 * Usage:
 *   node ask-chatgpt.mjs \
 *     --prompt "Explain the difference between REST and GraphQL" \
 *     [--model "gpt-5.4"] \
 *     [--system "You are a helpful assistant"] \
 *     [--sandbox "read-only"]
 *
 * Prerequisites:
 *   - codex CLI installed: npm install -g @openai/codex
 *   - codex login done: codex login
 *
 * Note:
 *   `codex exec` does NOT support --system-prompt.
 *   --system is prepended to the prompt as an instruction block.
 *   Prompt is written to a temp file to avoid Windows shell escaping issues
 *   with JSON, Korean text, semicolons, and curly braces.
 */

import { spawnSync } from 'child_process';
import { parseArgs } from 'util';
import { writeFileSync, unlinkSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';
import { randomUUID } from 'crypto';

const { values } = parseArgs({
  options: {
    prompt:  { type: 'string', short: 'p' },
    model:   { type: 'string', short: 'm' },
    system:  { type: 'string', short: 's' },
    sandbox: { type: 'string', default: 'read-only' },
  },
  strict: true,
});

if (!values.prompt) {
  console.error('Usage: node ask-chatgpt.mjs --prompt "..." [--model gpt-5.4] [--system "..."] [--sandbox read-only]');
  process.exit(1);
}

// Merge system instruction into prompt (codex exec has no --system-prompt)
const fullPrompt = values.system
  ? `[System instruction] ${values.system}\n\n---\n\n${values.prompt}`
  : values.prompt;

// Write prompt to temp file to avoid shell escaping issues on Windows
const tmpFile = join(tmpdir(), `codex-prompt-${randomUUID()}.txt`);
writeFileSync(tmpFile, fullPrompt, 'utf-8');

let result;
try {
  // Use PowerShell Get-Content to safely inject the file content
  const promptReader = `$(Get-Content -Raw '${tmpFile.replace(/'/g, "''")}')`;
  let cmd = `codex exec ${promptReader} -s ${values.sandbox}`;

  if (values.model) {
    cmd += ` -m ${values.model}`;
  }

  result = spawnSync(cmd, {
    encoding: 'utf8',
    timeout: 300000, // 5 min
    shell: 'powershell.exe',
    env: { ...process.env, NO_COLOR: '1' },
  });
} finally {
  try { unlinkSync(tmpFile); } catch {}
}

if (result.error) {
  console.error(`Codex exec failed: ${result.error.message}`);
  process.exit(1);
}

if (result.status !== 0) {
  console.error(result.stderr?.trim() || `Codex exited with code ${result.status}`);
  process.exit(1);
}

const output = result.stdout || '';

// Parse codex output: extract the actual response
// Codex format: header block, then "codex\n<response>\ntokens used\n<count>"
const lines = output.split('\n');
const codexIdx = lines.findIndex((l, i) => l.trim() === 'codex' && i > 0);

if (codexIdx >= 0) {
  const responseLines = [];
  for (let i = codexIdx + 1; i < lines.length; i++) {
    if (lines[i].trim() === 'tokens used') break;
    responseLines.push(lines[i]);
  }
  console.log(responseLines.join('\n').trim());
} else {
  console.log(output.trim());
}

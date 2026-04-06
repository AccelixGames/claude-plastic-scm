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
 * Output:
 *   stdout — ChatGPT response text (parsed from codex output)
 *   stderr — errors
 */

import { spawnSync } from 'child_process';
import { parseArgs } from 'util';

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

// Shell-escape a string for cross-platform use
function shellEscape(s) {
  return `"${s.replace(/"/g, '\\"')}"`;
}

// Build command string with proper quoting
let cmd = `codex exec ${shellEscape(values.prompt)} -s ${values.sandbox}`;

if (values.model) {
  cmd += ` -m ${values.model}`;
}
if (values.system) {
  cmd += ` --system-prompt ${shellEscape(values.system)}`;
}

const result = spawnSync(cmd, {
  encoding: 'utf8',
  timeout: 300000, // 5 min
  shell: true,
  env: { ...process.env, NO_COLOR: '1' },
});

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

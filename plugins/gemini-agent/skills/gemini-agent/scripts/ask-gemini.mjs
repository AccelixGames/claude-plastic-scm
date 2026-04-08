#!/usr/bin/env node

/**
 * ask-gemini.mjs
 * Gemini CLI wrapper — 구현/리뷰 서브에이전트용.
 * Claude 서브에이전트에서 Bash로 호출 가능.
 *
 * Usage:
 *   node ask-gemini.mjs \
 *     --prompt "Create a JSON file with..." \
 *     [--model "gemini-2.5-pro"] \
 *     [--approval-mode "yolo"] \
 *     [--cwd "/path/to/worktree"] \
 *     [--output-format "json"]
 *
 * Prerequisites:
 *   - gemini CLI installed: npm install -g @google/gemini-cli
 *   - GEMINI_API_KEY environment variable set
 *
 * Output:
 *   stdout — Gemini response text (parsed from JSON output)
 *   stderr — errors
 *
 * Exit codes:
 *   0 — success
 *   1 — error (auth, timeout, empty response)
 */

import { spawnSync } from 'child_process';
import { readFileSync } from 'fs';
import { parseArgs } from 'util';

const { values } = parseArgs({
  options: {
    prompt:          { type: 'string', short: 'p' },
    'prompt-file':   { type: 'string', short: 'f' },
    model:           { type: 'string', short: 'm' },
    'approval-mode': { type: 'string', default: 'yolo' },
    cwd:             { type: 'string' },
    'output-format': { type: 'string', default: 'json' },
    sandbox:         { type: 'boolean', short: 's', default: false },
  },
  strict: true,
});

// Resolve prompt: --prompt-file takes precedence over --prompt
let prompt = values.prompt;
if (values['prompt-file']) {
  try {
    prompt = readFileSync(values['prompt-file'], 'utf8');
  } catch (e) {
    console.error(`Cannot read prompt file: ${e.message}`);
    process.exit(1);
  }
}

if (!prompt) {
  console.error('Usage: node ask-gemini.mjs --prompt "..." | --prompt-file path [--model gemini-2.5-pro] [--cwd /path] [--sandbox]');
  process.exit(1);
}

if (!process.env.GEMINI_API_KEY) {
  console.error('GEMINI_API_KEY environment variable is required');
  process.exit(1);
}

// Always use stdin piping — avoids shell arg length limits and escaping issues
// Gemini CLI: stdin content is prepended to -p prompt
let cmd = `gemini -p " "`;  // minimal -p triggers headless mode; real prompt via stdin
cmd += ` -o ${values['output-format']}`;
cmd += ` --approval-mode ${values['approval-mode']}`;

if (values.model) {
  cmd += ` -m ${values.model}`;
}
if (values.sandbox) {
  cmd += ' -s';
}

const spawnOpts = {
  input: prompt,  // always pipe via stdin
  encoding: 'utf8',
  timeout: 300000, // 5 min
  shell: true,
  env: { ...process.env, NO_COLOR: '1' },
};

if (values.cwd) {
  spawnOpts.cwd = values.cwd;
}

const result = spawnSync(cmd, spawnOpts);

if (result.error) {
  console.error(`Gemini exec failed: ${result.error.message}`);
  process.exit(1);
}

// Handle non-zero exit gracefully — Windows UV assertion crash produces valid output
// before crashing, so check for output content before treating as error
if (result.status !== 0 && !result.stdout?.trim()) {
  const raw = result.stderr || '';
  console.error(raw.trim() || `Gemini exited with code ${result.status}`);
  process.exit(1);
}

const output = result.stdout || '';

// Parse based on output format
if (values['output-format'] === 'json') {
  try {
    const data = JSON.parse(output);

    if (data.error) {
      console.error(data.error.message || JSON.stringify(data.error));
      process.exit(1);
    }

    // Output response text
    const response = data.response || '';
    if (!response.trim()) {
      console.error('Empty response from Gemini');
      process.exit(1);
    }

    // Print response
    console.log(response);

    // Print stats to stderr for debugging
    if (data.stats) {
      const models = data.stats.models || {};
      const modelNames = Object.keys(models);
      const totalLatency = modelNames.reduce((sum, m) => sum + (models[m]?.api?.totalLatencyMs || 0), 0);
      const totalTokens = modelNames.reduce((sum, m) => sum + (models[m]?.tokens?.total || 0), 0);
      const filesChanged = (data.stats.files?.totalLinesAdded || 0) + (data.stats.files?.totalLinesRemoved || 0);
      console.error(`[gemini] models=${modelNames.join(',')} latency=${totalLatency}ms tokens=${totalTokens} fileChanges=${filesChanged}`);
    }
  } catch (e) {
    // If JSON parse fails, output raw
    console.log(output.trim());
  }
} else {
  console.log(output.trim());
}

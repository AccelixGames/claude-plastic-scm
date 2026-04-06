#!/usr/bin/env node

/**
 * generate-mockup.mjs
 * Gemini API 직접 호출로 이미지 생성 — MCP 서버 우회.
 * 백그라운드 서브에이전트에서 Bash로 호출 가능.
 *
 * Usage:
 *   GEMINI_API_KEY=<key> node generate-mockup.mjs \
 *     --prompt "first-person view inside cafe..." \
 *     --output "output/mockup.png" \
 *     [--aspect-ratio "16:9"] \
 *     [--reference "references/screen-mockup.png"]
 *
 * Environment:
 *   GEMINI_API_KEY — required
 */

import { GoogleGenAI } from '@google/genai';
import { writeFileSync, readFileSync, mkdirSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { parseArgs } from 'util';

const { values } = parseArgs({
  options: {
    prompt:         { type: 'string', short: 'p' },
    output:         { type: 'string', short: 'o' },
    'aspect-ratio': { type: 'string', default: '16:9' },
    reference:      { type: 'string', short: 'r' },
  },
  strict: true,
});

if (!values.prompt || !values.output) {
  console.error('Usage: node generate-mockup.mjs --prompt "..." --output "path.png" [--aspect-ratio 16:9] [--reference ref.png]');
  process.exit(1);
}

const apiKey = process.env.GEMINI_API_KEY;
if (!apiKey) {
  console.error('GEMINI_API_KEY environment variable is required');
  process.exit(1);
}

const ai = new GoogleGenAI({ apiKey });
const outputPath = resolve(values.output);
const outputDir = dirname(outputPath);

if (!existsSync(outputDir)) {
  mkdirSync(outputDir, { recursive: true });
}

// Build prompt parts
const contents = [];

// If reference image provided, include it
if (values.reference) {
  const refPath = resolve(values.reference);
  if (existsSync(refPath)) {
    const refBytes = readFileSync(refPath);
    const base64 = refBytes.toString('base64');
    const ext = refPath.split('.').pop().toLowerCase();
    const mime = ext === 'png' ? 'image/png' : 'image/jpeg';
    contents.push({
      inlineData: { mimeType: mime, data: base64 },
    });
  } else {
    console.error(`Reference image not found: ${refPath}`);
  }
}

// Add text prompt with aspect ratio instruction
let fullPrompt = values.prompt;
if (values['aspect-ratio']) {
  fullPrompt += `, ${values['aspect-ratio']} aspect ratio`;
}
contents.push({ text: fullPrompt });

try {
  const response = await ai.models.generateContent({
    model: 'gemini-3.1-flash-image-preview',
    contents: [{ role: 'user', parts: contents }],
    config: {
      responseModalities: ['TEXT', 'IMAGE'],
    },
  });

  // Extract image from response
  const parts = response.candidates?.[0]?.content?.parts || [];
  let saved = false;

  for (const part of parts) {
    if (part.inlineData?.mimeType?.startsWith('image/')) {
      const buffer = Buffer.from(part.inlineData.data, 'base64');
      writeFileSync(outputPath, buffer);
      console.log(outputPath);
      saved = true;
      break;
    }
  }

  if (!saved) {
    // Try text response for debugging
    const textParts = parts.filter(p => p.text).map(p => p.text).join('\n');
    console.error('No image in response.', textParts ? `Text: ${textParts}` : '');
    process.exit(1);
  }
} catch (err) {
  console.error(`Generation failed: ${err.message}`);
  process.exit(1);
}

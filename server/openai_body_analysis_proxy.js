#!/usr/bin/env node

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

loadEnvFile(path.join(__dirname, '.env'));
loadEnvFile(path.join(__dirname, '..', '.env'));

const port = Number(process.env.OPENAI_BODY_PROXY_PORT || 8787);
const model = process.env.OPENAI_BODY_MODEL || 'gpt-5.6';
const maxBodyBytes = 14 * 1024 * 1024;

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return;
  }

  const lines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }

    const separator = trimmed.indexOf('=');
    if (separator === -1) {
      continue;
    }

    const key = trimmed.slice(0, separator).trim();
    const rawValue = trimmed.slice(separator + 1).trim();
    if (!key || process.env[key] !== undefined) {
      continue;
    }

    process.env[key] = rawValue.replace(/^['"]|['"]$/g, '');
  }
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  });
  response.end(JSON.stringify(payload));
}

function readJsonBody(request) {
  return new Promise((resolve, reject) => {
    let totalBytes = 0;
    const chunks = [];

    request.on('data', (chunk) => {
      totalBytes += chunk.length;
      if (totalBytes > maxBodyBytes) {
        reject(new Error('Image payload is too large.'));
        request.destroy();
        return;
      }
      chunks.push(chunk);
    });

    request.on('end', () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch {
        reject(new Error('Invalid JSON body.'));
      }
    });

    request.on('error', reject);
  });
}

function extractOutputText(payload) {
  if (typeof payload.output_text === 'string') {
    return payload.output_text;
  }

  const parts = [];
  for (const output of payload.output || []) {
    for (const content of output.content || []) {
      if (typeof content.text === 'string') {
        parts.push(content.text);
      }
    }
  }
  return parts.join('\n').trim();
}

function parseModelJson(text) {
  try {
    return JSON.parse(text);
  } catch {
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) {
      throw new Error('OpenAI response did not include JSON.');
    }
    return JSON.parse(match[0]);
  }
}

function normalizeResult(result) {
  const heightCm = finiteNumberInRange(result.height_cm, 80, 240);
  const weightKg = finiteNumberInRange(result.weight_kg, 25, 250);
  const faceVisible = result.face_visible === true;

  return {
    capture_accepted: result.capture_accepted === true && faceVisible,
    face_visible: faceVisible,
    complete_body_visible: result.complete_body_visible === true,
    known_scale_visible: false,
    height_cm: heightCm,
    weight_kg: weightKg,
    message_ar:
      typeof result.message_ar === 'string'
        ? result.message_ar
        : 'تم تحليل الصورة. قياس الطول يحتاج معايرة، والوزن يحتاج ميزان متصل أو إدخال يدوي.',
    message_en:
      typeof result.message_en === 'string'
        ? result.message_en
        : 'AI visual estimate returned from the photo.',
    message_ar:
      typeof result.message_ar === 'string'
        ? result.message_ar
        : 'AI visual estimate returned from the photo.',
    model,
  };
}

function finiteNumberInRange(value, min, max) {
  const number = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(number) || number < min || number > max) {
    return null;
  }
  return Math.round(number * 10) / 10;
}

async function analyzeBodyImage(imageDataUrl) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    const error = new Error(
      'OPENAI_API_KEY is not configured on the body analysis proxy.',
    );
    error.statusCode = 500;
    throw error;
  }

  const openAiResponse = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      reasoning: { effort: 'low' },
      input: [
        {
          role: 'user',
          content: [
            {
              type: 'input_text',
              text: [
                'You are analyzing one camera photo for a height and weight measurement workflow.',
                'Return JSON only with this shape:',
                '{"capture_accepted":boolean,"face_visible":boolean,"complete_body_visible":boolean,"known_scale_visible":false,"height_cm":number|null,"weight_kg":number|null,"message_ar":string,"message_en":string}',
                'Rules:',
                '- Return an approximate AI visual estimate for height_cm and weight_kg from the photo.',
                '- Set face_visible true only when a human face is visible in the image.',
                '- Set capture_accepted true only when a face is visible and a person is visible enough to make an estimate.',
                '- Set complete_body_visible true only when the full body is visible from head to feet.',
                '- If the photo is too dark, blank, no face is visible, or no person is visible, set capture_accepted false and return null values.',
                '- Keep height_cm between 80 and 240 when provided.',
                '- Keep weight_kg between 25 and 250 when provided.',
                '- Messages must be short and mention that this is an AI visual estimate.',
              ].join('\n'),
            },
            {
              type: 'input_image',
              image_url: imageDataUrl,
              detail: 'original',
            },
          ],
        },
      ],
    }),
  });

  const payload = await openAiResponse.json();
  if (!openAiResponse.ok) {
    const error = new Error(
      payload.error?.message || 'OpenAI body analysis request failed.',
    );
    error.statusCode = openAiResponse.status;
    throw error;
  }

  return normalizeResult(parseModelJson(extractOutputText(payload)));
}

const server = http.createServer(async (request, response) => {
  if (request.method === 'OPTIONS') {
    sendJson(response, 204, {});
    return;
  }

  if (request.method !== 'POST' || request.url !== '/analyze-body') {
    sendJson(response, 404, { error: 'Not found.' });
    return;
  }

  try {
    const body = await readJsonBody(request);
    const imageDataUrl = body.image_data_url;
    if (
      typeof imageDataUrl !== 'string' ||
      !imageDataUrl.startsWith('data:image/')
    ) {
      sendJson(response, 400, { error: 'image_data_url is required.' });
      return;
    }

    sendJson(response, 200, await analyzeBodyImage(imageDataUrl));
  } catch (error) {
    sendJson(response, error.statusCode || 500, {
      error: error.message || 'Body analysis proxy failed.',
    });
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`OpenAI body analysis proxy listening on http://127.0.0.1:${port}`);
  console.log(`Model: ${model}`);
});

import express, { type Request, type Response, type NextFunction } from 'express';
import multer from 'multer';
import { config } from './config.js';
import { buildSystemPrompt, isParseContext } from './prompt.js';
import { parseItems } from './items.js';
import { runClaudeText } from './claude.js';
import { transcribeAudio } from './transcribe.js';

const app = express();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 25 * 1024 * 1024 } });

function auth(req: Request, res: Response, next: NextFunction): void {
  if (req.headers.authorization !== `Bearer ${config.apiToken}`) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }
  next();
}

app.get('/health', (_req, res) => {
  res.json({ ok: true });
});

/**
 * POST /v1/parse — one round trip for the whole capture: audio (or a retry's
 * saved transcript) plus the ledger context in, transcript plus validated
 * items out. Error codes the app maps to log rows: nothing_heard, no_amount.
 */
app.post('/v1/parse', auth, upload.single('audio'), async (req: Request, res: Response) => {
  try {
    let context: unknown;
    try {
      context = JSON.parse((req.body?.context as string) ?? '');
    } catch {
      context = null;
    }
    if (!isParseContext(context)) {
      res.status(400).json({ error: 'Invalid context' });
      return;
    }

    let transcript = typeof req.body?.transcript === 'string' ? req.body.transcript.trim() : '';
    if (!transcript && req.file) {
      transcript = (await transcribeAudio(req.file.buffer, req.file.mimetype)).trim();
    }
    if (!transcript) {
      res.status(422).json({ error: 'Nothing heard', code: 'nothing_heard' });
      return;
    }

    const reply = await runClaudeText({ system: buildSystemPrompt(context), prompt: transcript });
    const items = parseItems(reply, context.categories, context.today, {
      subscriptions: context.subscriptions.map((s) => s.name),
      expenses: context.recentExpenses.map((e) => e.note),
    });
    if (items.length === 0) {
      res.status(422).json({ error: 'No usable items', code: 'no_amount', transcript });
      return;
    }
    res.json({ transcript, items });
  } catch (error) {
    console.error('Parse error:', error);
    const message = error instanceof Error ? error.message : 'Unknown error';
    res.status(502).json({ error: message });
  }
});

app.listen(config.port, () => {
  console.log(`wealth-server listening on :${config.port} (model ${config.claude.model}, effort ${config.claude.effort})`);
});

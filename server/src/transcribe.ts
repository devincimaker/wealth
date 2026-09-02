import { config } from './config.js';

// Raw fetch instead of the OpenAI SDK: one endpoint doesn't justify a
// dependency (whose zod peer also clashes with the Agent SDK's).
// No language pin: dictation mixes Spanish and English and Whisper detects both.
export async function transcribeAudio(audioBuffer: Buffer, mimeType: string): Promise<string> {
  const extensionMap: Record<string, string> = {
    'audio/mp4': 'm4a',
    'audio/m4a': 'm4a',
    'audio/x-m4a': 'm4a',
    'audio/wav': 'wav',
    'audio/mpeg': 'mp3',
  };
  const extension = extensionMap[mimeType] || 'm4a';
  const form = new FormData();
  form.append('model', 'whisper-1');
  form.append('file', new File([new Uint8Array(audioBuffer)], `capture.${extension}`, { type: mimeType }));

  const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${config.openai.apiKey}` },
    body: form,
  });
  if (!response.ok) throw new Error(`Whisper answered ${response.status}`);
  const payload = (await response.json()) as { text?: string };
  return payload.text ?? '';
}

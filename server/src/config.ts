// Env-driven config. The server fails loudly at boot when a required value is
// missing (same rule as the app's Secrets): a half-configured server that
// answers 500s is worse than one that refuses to start.
function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return value;
}

export const config = {
  port: Number(process.env.PORT || 3002),
  /** Shared secret the app sends as a bearer token; single user, one token. */
  apiToken: required('WEALTH_API_TOKEN'),
  openai: {
    /** Whisper only; Claude does the thinking. */
    apiKey: required('OPENAI_API_KEY'),
  },
  claude: {
    model: process.env.WEALTH_MODEL || 'claude-opus-5',
    /** Parsing is quick work; low keeps captures snappy. */
    effort: (process.env.WEALTH_EFFORT || 'low') as 'low' | 'medium' | 'high',
  },
};

if (!process.env.CLAUDE_CODE_OAUTH_TOKEN && !process.env.ANTHROPIC_API_KEY) {
  console.warn(
    'CLAUDE_CODE_OAUTH_TOKEN is not set; falling back to the local Claude Code login (fine in dev, not on a server).'
  );
}

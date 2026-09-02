import { query, type Options } from '@anthropic-ai/claude-agent-sdk';
import { config } from './config.js';

/**
 * One tool-less Claude call through the Agent SDK, riding subscription auth
 * (CLAUDE_CODE_OAUTH_TOKEN, or the local Claude Code login in dev). Same
 * pattern as thrive's runClaudeText; the conversation is not persisted.
 */
export async function runClaudeText(args: { system: string; prompt: string }): Promise<string> {
  const options: Options = {
    systemPrompt: args.system,
    model: config.claude.model,
    effort: config.claude.effort,
    settingSources: [],
    tools: [],
    allowedTools: [],
    permissionMode: 'dontAsk',
    maxTurns: 1,
    persistSession: false,
  };

  for await (const message of query({ prompt: args.prompt, options })) {
    if (message.type === 'result') {
      if (message.subtype === 'success') {
        return message.result.trim();
      }
      throw new Error(`Claude call failed (${message.subtype}): ${message.errors.join('; ')}`);
    }
  }

  throw new Error('Claude call ended without a result');
}

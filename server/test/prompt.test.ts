import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildSystemPrompt, isParseContext } from '../src/prompt.js';

const CONTEXT = {
  today: '2026-09-01',
  defaultCurrency: 'ARS',
  categories: ['Food & Drink', 'Transport'],
  subscriptions: [{ name: 'Claude Pro', amount: 200, currency: 'USD', cadence: 'monthly' }],
  recentExpenses: [{ note: 'Café con Juan', amount: 9800, currency: 'ARS', date: '2026-08-31' }],
};

test('the prompt carries the candidates, categories, and today', () => {
  const prompt = buildSystemPrompt(CONTEXT);
  assert.match(prompt, /Claude Pro · 200 USD · monthly/);
  assert.match(prompt, /Café con Juan · 9800 ARS · 2026-08-31/);
  assert.match(prompt, /Food & Drink, Transport/);
  assert.match(prompt, /Today is 2026-09-01/);
  assert.match(prompt, /copied EXACTLY/);
  assert.match(prompt, /never invent a category/);
});

test('empty ledgers still render valid candidate sections', () => {
  const prompt = buildSystemPrompt({ ...CONTEXT, subscriptions: [], recentExpenses: [] });
  assert.match(prompt, /Active subscriptions[^]*\(none\)/);
  assert.match(prompt, /Recent expenses[^]*\(none\)/);
});

test('context validation rejects junk and accepts the real shape', () => {
  assert.equal(isParseContext(CONTEXT), true);
  assert.equal(isParseContext(null), false);
  assert.equal(isParseContext({ today: '2026-09-01' }), false);
});

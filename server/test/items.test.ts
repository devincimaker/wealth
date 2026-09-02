import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseItems, extractJson } from '../src/items.js';

const CATEGORIES = ['Food & Drink', 'Groceries'];
const TODAY = '2026-09-01';

test('reads a plain JSON reply into normalized items', () => {
  const items = parseItems(
    '{"items":[{"kind":"expense","action":"create","amount":9800,"currency":"ars","note":"Café","category":"food & drink","date":"2026-08-31","cadence":null}]}',
    CATEGORIES,
    TODAY
  );
  assert.deepEqual(items, [
    {
      kind: 'expense',
      action: 'create',
      amount: 9800,
      currency: 'ARS',
      note: 'Café',
      category: 'Food & Drink',
      date: '2026-08-31',
      cadence: null,
    },
  ]);
});

test('tolerates a fenced reply', () => {
  const items = parseItems(
    'Here you go:\n```json\n{"items":[{"kind":"expense","amount":100,"currency":"USD","note":"Taxi","category":null,"date":"2026-09-01"}]}\n```',
    [],
    TODAY
  );
  assert.equal(items.length, 1);
  assert.equal(items[0].action, 'create');
});

test('drops amountless creates and updates but keeps deletes', () => {
  const items = parseItems(
    JSON.stringify({
      items: [
        { kind: 'expense', action: 'create', amount: 0, currency: 'ARS', note: 'súper', category: null, date: TODAY },
        { kind: 'expense', action: 'update', amount: 0, currency: 'ARS', note: 'café', category: null, date: TODAY },
        { kind: 'subscription', action: 'delete', amount: 0, currency: 'ARS', note: 'Netflix', category: null, date: TODAY },
      ],
    }),
    [],
    TODAY
  );
  assert.deepEqual(
    items.map((item) => [item.action, item.note]),
    [['delete', 'Netflix']]
  );
});

test('invented categories become null and bad dates become today', () => {
  const items = parseItems(
    JSON.stringify({
      items: [{ kind: 'expense', amount: 5, currency: 'USD', note: 'x', category: 'Crypto', date: 'ayer' }],
    }),
    CATEGORIES,
    TODAY
  );
  assert.equal(items[0].category, null);
  assert.equal(items[0].date, TODAY);
});

test('subscription cadence defaults to monthly and expenses never carry one', () => {
  const items = parseItems(
    JSON.stringify({
      items: [
        { kind: 'subscription', amount: 200, currency: 'USD', note: 'Claude Pro', category: null, date: TODAY, cadence: null },
        { kind: 'expense', amount: 10, currency: 'USD', note: 'Taxi', category: null, date: TODAY, cadence: 'monthly' },
      ],
    }),
    [],
    TODAY
  );
  assert.equal(items[0].cadence, 'monthly');
  assert.equal(items[1].cadence, null);
});

test('a reference kind is corrected to the list its name came from', () => {
  const names = { subscriptions: ['Netflix'], expenses: ['suscripción pro de cloud'] };
  const items = parseItems(
    JSON.stringify({
      items: [
        // The speaker said "suscripción" but the copied name is an expense note.
        { kind: 'subscription', action: 'delete', amount: 0, currency: 'USD', note: 'suscripción pro de cloud', category: null, date: TODAY },
        // A create keeps whatever kind the model chose.
        { kind: 'subscription', action: 'create', amount: 200, currency: 'USD', note: 'suscripción pro de cloud', category: null, date: TODAY },
        // A name in neither list stays as labeled.
        { kind: 'subscription', action: 'delete', amount: 0, currency: 'ARS', note: 'Spotify', category: null, date: TODAY },
      ],
    }),
    [],
    TODAY,
    names
  );
  assert.deepEqual(
    items.map((item) => [item.action, item.kind]),
    [
      ['delete', 'expense'],
      ['create', 'subscription'],
      ['delete', 'subscription'],
    ]
  );
});

test('garbage replies throw', () => {
  assert.throws(() => extractJson('no json here at all'));
});

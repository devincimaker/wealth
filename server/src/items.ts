// Turns a model reply into validated, normalized items. The model is asked
// for bare JSON but tolerated if it fences it; everything else is enforced
// here so the app only ever sees clean items.

export interface Item {
  kind: 'expense' | 'subscription';
  action: 'create' | 'update' | 'delete';
  amount: number;
  currency: string;
  note: string;
  category: string | null;
  date: string;
  cadence: 'monthly' | 'yearly' | null;
}

interface RawItem {
  kind?: unknown;
  action?: unknown;
  amount?: unknown;
  currency?: unknown;
  note?: unknown;
  category?: unknown;
  date?: unknown;
  cadence?: unknown;
}

/** Parses a JSON object out of a model reply, tolerating a ```json fence. */
export function extractJson(text: string): unknown {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fenced?.[1] ?? text.slice(text.indexOf('{'), text.lastIndexOf('}') + 1);
  return JSON.parse(candidate);
}

function equalsIgnoringCase(a: string, b: string): boolean {
  return a.localeCompare(b, undefined, { sensitivity: 'base' }) === 0;
}

/**
 * The model sometimes labels a reference by the speaker's words instead of
 * the list the name came from ("el gasto de la suscripción" is an expense).
 * When the copied name lives in exactly one list, that list decides the kind.
 */
function resolveKind(
  kind: Item['kind'],
  action: Item['action'],
  note: string,
  names: { subscriptions: string[]; expenses: string[] }
): Item['kind'] {
  if (action === 'create') return kind;
  const inSubscriptions = names.subscriptions.some((name) => equalsIgnoringCase(name, note));
  const inExpenses = names.expenses.some((name) => equalsIgnoringCase(name, note));
  if (inSubscriptions === inExpenses) return kind;
  return inSubscriptions ? 'subscription' : 'expense';
}

/**
 * Normalizes the reply into items the app can apply. Unusable entries drop
 * (a create/update without an amount can't act; a delete needs none); an
 * invented category becomes null; a bad date becomes today; a reference's
 * kind is corrected to the list its name came from.
 */
export function parseItems(
  reply: string,
  categories: string[],
  today: string,
  names: { subscriptions: string[]; expenses: string[] } = { subscriptions: [], expenses: [] }
): Item[] {
  const parsed = extractJson(reply) as { items?: RawItem[] };
  const rawItems = Array.isArray(parsed.items) ? parsed.items : [];
  const items: Item[] = [];
  for (const raw of rawItems) {
    const action = raw.action === 'update' || raw.action === 'delete' ? raw.action : 'create';
    const amount = typeof raw.amount === 'number' && Number.isFinite(raw.amount) ? raw.amount : 0;
    if (action !== 'delete' && amount <= 0) continue;
    const note = typeof raw.note === 'string' ? raw.note : '';
    const kind = resolveKind(raw.kind === 'subscription' ? 'subscription' : 'expense', action, note, names);
    const category =
      typeof raw.category === 'string'
        ? (categories.find((name) => equalsIgnoringCase(name, raw.category as string)) ?? null)
        : null;
    items.push({
      kind,
      action,
      amount,
      currency: typeof raw.currency === 'string' && raw.currency ? raw.currency.toUpperCase() : 'ARS',
      note,
      category,
      date: typeof raw.date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(raw.date) ? raw.date : today,
      cadence: kind === 'subscription' ? (raw.cadence === 'yearly' ? 'yearly' : 'monthly') : null,
    });
  }
  return items;
}

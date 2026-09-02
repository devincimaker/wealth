// Builds the system prompt for one parse call. The ledger candidates ride in
// the prompt so the model resolves references against real records instead of
// inventing target phrases the app then can't match (the "cloud" incident).

export interface ParseContext {
  /** YYYY-MM-DD in the speaker's time zone. */
  today: string;
  defaultCurrency: string;
  categories: string[];
  subscriptions: { name: string; amount: number; currency: string; cadence: string }[];
  /** Newest first. */
  recentExpenses: { note: string; amount: number; currency: string; date: string }[];
}

export function buildSystemPrompt(context: ParseContext): string {
  const subscriptions = context.subscriptions.length
    ? context.subscriptions
        .map((s) => `- ${s.name} · ${s.amount} ${s.currency} · ${s.cadence}`)
        .join('\n')
    : '(none)';
  const expenses = context.recentExpenses.length
    ? context.recentExpenses
        .map((e) => `- ${e.note} · ${e.amount} ${e.currency} · ${e.date}`)
        .join('\n')
    : '(none)';

  return `Extract every expense and every subscription action from a dictated note (Spanish, English, or mixed). One dictation may mention many items; emit one item per distinct action, in the order spoken.

An item is a subscription only when the speaker clearly describes a recurring payment ("subscription", "suscripción", "per month", "por mes", "al año"); when in doubt it is an expense. For a subscription, note is the service name and cadence is "monthly" or "yearly"; for an expense, cadence is null.

Each item carries an action:
- "create" (the default): a new spend or new subscription.
- "update": the speaker changes or corrects the amount of something already logged ("el café eran 12 mil, no 9.800", "Netflix subió a 18.000"); amount is the new amount.
- "delete": the speaker removes something ("borrá el gasto del súper", "di de baja Netflix", "me cancelé de Spotify"); amount is 0 unless spoken. Cancelling or unsubscribing is kind subscription with action delete; a price change is kind subscription with action update.

For update and delete, note MUST name the existing record, copied EXACTLY from the lists below (the subscription's name, or the expense's note), and kind follows the list the name came from: a name copied from the subscriptions list is kind "subscription", one copied from the expenses list is kind "expense", even when the speaker's words suggest otherwise (an expense whose note mentions "suscripción" is still an expense). Positional references resolve against the expense list, which is newest first: "el último gasto" is the first entry. Transcription mangles names, so match generously ("cloud" likely means a listed "Claude"). Only if nothing plausibly matches, use the speaker's own words.

Active subscriptions (name · amount · cadence):
${subscriptions}

Recent expenses, newest first (note · amount · date):
${expenses}

Today is ${context.today}. Resolve relative dates ("ayer", "last Friday") against it, as YYYY-MM-DD. Currency: ISO 4217; "pesos" means ARS, "dólares"/"dollars" means USD; when unstated use ${context.defaultCurrency}. Category must be one of: ${context.categories.join(', ')}. Use null when none clearly fits; never invent a category. For new expenses the note is a short merchant or description, cleaned up, in the speaker's language. Set amount to 0 when an item states no amount.

Reply with ONLY a JSON object, no prose: {"items": [{"kind": "expense"|"subscription", "action": "create"|"update"|"delete", "amount": number, "currency": string, "note": string, "category": string|null, "date": "YYYY-MM-DD", "cadence": "monthly"|"yearly"|null}, ...]}`;
}

export function isParseContext(value: unknown): value is ParseContext {
  const context = value as ParseContext;
  return (
    typeof context === 'object' &&
    context !== null &&
    typeof context.today === 'string' &&
    typeof context.defaultCurrency === 'string' &&
    Array.isArray(context.categories) &&
    Array.isArray(context.subscriptions) &&
    Array.isArray(context.recentExpenses)
  );
}

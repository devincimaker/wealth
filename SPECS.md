# Wealth — v1 Specification

A personal, native iPhone app for tracking expenses. Built for one user (me). No accounts, no server, no monetization. Wealth/net-worth tracking is deliberately deferred to v2.

## Product principles

- **Minimal**: only what I actually need. Every feature must earn its place.
- **Fast capture**: logging an expense should take under 5 seconds (hold-to-speak + LLM parse), under 15 manually.
- **Zero upkeep**: the app never asks me to maintain data by hand (rates, catch-up chores). Automate or drop it.
- **Private by default, not dogmatically serverless**: v1 needs no backend, but v2+ (wealth tracking, recommendations, bank sync) may well add one. Don't contort the design to avoid a server.
- **Extensible**: nothing in v1 should block v2 (wealth: crypto, real estate, mixed instruments) or future bank sync.

## v1 scope

1. Log individual expenses (manual form + voice quick entry: Whisper STT + LLM parsing).
2. Recurring subscriptions that auto-post expenses each cycle.
3. Categories with monthly totals.
4. Multi-currency (USD + ARS today, open-ended) with a base-currency view.
5. iCloud sync/backup.

### Explicit non-goals for v1

- No budgets or spending limits.
- No income tracking, no net worth (v2).
- No bank sync, no CSV import (future — see Roadmap).
- No iPad/Mac targets, no widgets, no watch app.
- No charts beyond simple monthly category totals.

## Core flows

### 1. Quick add (voice → cloud STT → LLM, optimistic) — the headline feature

Borrows Habitron's **optimistic fire-and-forget assistant** (HAB-134, thrive monorepo, worktree "Optimistic-assistant"): speak, release, done — no confirmation step. **Nothing Apple-Intelligence-based**: Apple speech recognition and Apple Foundation Models are both deliberately unused — half my dictation is in Spanish and they handle it badly.

**One action button.** A single "＋" button above the tab bar:
- **Tap** → the manual-add half sheet.
- **Long-press (~400 ms)** → it becomes a microphone and starts recording; slide up to cancel; **release = the expense saves, immediately**. No proposal sheet, no Apply, no blocking "working" panel. I may lock the phone the moment my thumb lifts.

**Pipeline** (network required for voice; manual entry always works offline):
1. **Record**: `AVAudioRecorder`, m4a, metering for a waveform, hard cap ~1 min.
2. On release: the recording is **enqueued** in a local persisted queue (SwiftData) and processed by a background task (`beginBackgroundTask` covers the phone-lock case; a killed app resumes the queue on next launch).
3. **Audio → text**: OpenAI **`whisper-1`** (excellent Spanish, auto-detects language — do NOT pin `language: es`, input mixes English).
4. **Text → structured expense**: a **small OpenAI model** (`gpt-4o-mini`) with **structured outputs** (`strict: true`), so the schema is enforced rather than trusted — `amount`, `currency` (from "pesos"/"dollars", default last-used), `merchant/note`, `categoryName?` (matched against my category list, never invented), `date` (relative phrases resolved). The expense is **saved directly**. One vendor for the whole voice path: same key as Whisper, one bill, one status page.

**Ticker pill** — one floating pill above the tab bar, a summary of the queue, never one per expense:
- *Working*: amber spinner + current label ("Logging AR$ 40.000 · Cena…") + `+N` badge for items queued behind.
- *Landing*: each save flashes green ~1 s ("Logged AR$ 40.000 · Food & Drink"), rolls to the next.
- *Drained*: rests at "N logged" a few seconds, fades away.
- *Failure*: red flash; rests at "N logged · M failed" and **stays until every failure is retried or dismissed**. A failure never blocks the rest of the queue.
- Tap the pill in any state → **Activity log**.

**Activity log** (sheet): newest first; row = icon puck, title, quoted transcript, status chip. Actions by status: Working → Cancel; Logged → **Undo** (deletes the expense) · **Edit** (opens it); Failed → Retry · Dismiss; Undone → Restore. Parse failures ("didn't catch an amount") land here as failed rows with the transcript preserved — retry re-uses the same recording (HAB-157 lesson: distinguish "server never answered" from "didn't catch that").

- v1 calls both APIs **directly from the app** (personal keys in a local config, not committed) — no server yet. `TranscriptionService` / `ParsingService` protocols so the calls can later move to a backend (Habitron runs this queue server-side; if Wealth grows a server, adopt that shape) without touching the UI.
- Fallback: typing into the manual form always works; the same parse can be run on typed text.

### 2. Manual add

Single sheet: amount (numeric pad, currency toggle inline), category picker, date (defaults today), optional note. Save.

### 3. Subscriptions

- Define once: name, amount, currency, cadence (monthly/yearly, billing day), category, active flag, optional start/end date.
- The app **auto-posts** an expense on each billing date (generated on app open — catch-up logic creates any missed postings since last launch; no server needed).
- Posted expenses link back to their subscription (`subscriptionId`) and are editable/deletable individually.
- Subscriptions screen shows the list + "monthly burn" total (yearly amounts ÷ 12), in base currency.

### 4. Review

- **Home**: current month total (base currency), list of recent expenses grouped by day.
- **Month view**: total + per-category breakdown (amount and % of month), switch months.
- Per-currency subtotals shown alongside the converted total (e.g. "US$ 420 + AR$ 850.000 ≈ US$ 1.020").

### 5. Categories

Reached from Settings → Categories (also where the "9" count lives).
- **List**: icon + name + "N expenses this month". Drag to reorder — this order is the chip order everywhere (manual add, breakdowns). Swipe left to delete.
- **Create/edit**: one sheet for both — name field + icon picker (a fixed set of ~18 stroke icons). "Delete category" lives at the bottom of the edit sheet too.
- **Delete**: always asks where the expenses go — move to a chosen category (default "Other") or leave uncategorized. Never silently orphans or deletes expenses. Uncategorized expenses show without a category and can be recategorized from their edit screen.
- Voice parsing only ever matches existing categories; creating one is always an explicit act here.

## Multi-currency model

- Every expense stores `amount` + `currency` — always the original, never converted at write time.
- **Base currency: USD** (setting, changeable).
- Exchange rates come from an **API, automatically** — no manual rate entry, ever:
  - **ARS**: DolarAPI (`dolarapi.com`) using the **blue** rate (the rate my money actually moves at; official would misstate real spending).
  - **Other currencies**: a standard free rates API (e.g. frankfurter.app or exchangerate-api) against USD.
  - Fetched on app launch and cached (SwiftData/UserDefaults) with `lastUpdated`; the cached rate is used offline. A rate-source picker per currency (blue vs official) lives in Settings only if ever needed — default blue for ARS.
- Conversions happen at **display time at the current rate** — no historical-rate conversion. I want to see what my spending is worth in dollars *now*, not what it was worth then.

## Data model (SwiftData)

```swift
@Model Expense {
  var id: UUID
  var amount: Decimal          // in `currency`, always positive
  var currency: String         // ISO 4217: "USD", "ARS"
  var date: Date
  var note: String             // merchant / free text
  var category: Category?
  var subscription: Subscription?  // nil for one-off expenses
  var source: String           // "manual" | "voice" | (future: "santander", "csv")
  var externalId: String?      // future bank-sync dedupe key; nil in v1
  var createdAt: Date
}

@Model Category {
  var id: UUID
  var name: String
  var symbol: String           // SF Symbol name
  var sortOrder: Int
  var expenses: [Expense]
}

@Model Subscription {
  var id: UUID
  var name: String
  var amount: Decimal
  var currency: String
  var cadence: String          // "monthly" | "yearly"
  var billingDay: Int          // day-of-month (monthly) — for yearly also billingMonth: Int
  var billingMonth: Int?       // yearly only
  var isActive: Bool
  var startDate: Date
  var endDate: Date?
  var category: Category?
  var lastPostedDate: Date?    // drives catch-up posting
  var expenses: [Expense]
}

// Settings (UserDefaults / @AppStorage, not SwiftData):
// baseCurrency: String, knownCurrencies: [String]
// Rate cache: [currency: (rate: Decimal, lastUpdated: Date)] — API-fed, never hand-edited
```

Seed categories on first launch: Food & Drink, Groceries, Transport, Housing, Subscriptions & Services, Health, Entertainment, Travel, Other. All editable/deletable.

`externalId` + `source` exist from day one so future Santander/CSV imports can dedupe against manual entries without a migration.

## Screens (4 tabs max — likely 3)

1. **Expenses** (home): month total, recent list, the "＋" action button (tap = manual, long-press = voice), ticker pill + Activity log sheet.
2. **Months**: month picker, category breakdown.
3. **Subscriptions**: list, monthly burn, add/edit.
4. **Settings** (gear on home, not a tab): base currency, rate status (read-only: current rates + last updated), categories, iCloud status.

## Tech stack

- **Swift 6 / SwiftUI**, iOS 26 minimum (unlocks Foundation Models; my device supports it).
- **SwiftData + CloudKit** (`.private` database) for storage/sync. Consequence: all relationships optional, defaults on all attributes — designed above accordingly.
- **Voice quick add**: `AVAudioRecorder` + `URLSession` calls to OpenAI (Whisper to transcribe, `gpt-4o-mini` with structured outputs to parse). No Apple Speech framework, no Foundation Models — both are poor in Spanish, which is half my dictation. A single API key lives in a local untracked config for v1; it ships inside the app bundle, which is acceptable only while the app is mine alone.
- **Rates**: plain `URLSession` calls to DolarAPI + a standard rates API; no SDKs.
- No third-party dependencies. No backend *in v1* (a server is acceptable later when wealth tracking/recommendations or bank sync need one; the STT/parse services are behind protocols so they can move server-side without UI changes).
- Xcode project, single app target. Capabilities: iCloud (CloudKit), Microphone. Network for rates + voice pipeline.

## Roadmap (not v1)

- **v2 — Wealth**: accounts/assets across instrument types — cash, brokerage, **crypto**, **real estate**, other instruments — with balances/valuations, net worth now + over time. Likely the point where a backend enters (price feeds, wealth recommendations). Separate tab alongside expenses.
- **CSV import**: Santander export → mapping → bulk insert with dedupe via `externalId`.
- **Bank sync**: via an aggregator (GoCardless Bank Account Data free tier, or TrueLayer/Plaid) — Santander supported under PSD2/Open Banking. Requires their OAuth flow + polling; `source`/`externalId` already in the model.
- **Deeper Habitron borrowing**: if quick-add ever grows past single-expense creation (multi-action commands, corrections), adopt Habitron's full propose→correct→apply agent pattern (read-only propose turn, session resume, apply unlocks write tools) and/or share its Express API for transcription.
- **Maybe-laters**: budgets, widgets, Mac app.

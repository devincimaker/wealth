To-Do:
- [ ] Voice needs a device pass: the simulator has no usable mic, so hold-to-speak is only verified as far as the recorder starting. Transcription and parsing are verified against the live API.
- [ ] M6: iCloud sync on + polish _needs Apple Developer account_
- [ ] Bundle Spline Sans Mono font for amounts (system monospaced is the placeholder)
- [ ] Revisit the parse model if category matching disappoints: gpt-4o-mini returned null for "el chino de la esquina" (a corner grocery) rather than Groceries. One line in `OpenAIParsingService.requestBody`.

Doing:

Done:
- [x] M1: repo setup, guidelines, XcodeGen project, SwiftData models, 3-tab shell
- [x] M2: manual add sheet, home list with day grouping, expense edit/delete, months breakdown
- [x] M3: category management (list, reorder, edit, delete-with-reassign); subscriptions with catch-up auto-posting
- [x] M4: rates (DolarAPI blue + Frankfurter), cached in UserDefaults, display-time conversion
- [x] M5: recorder, persisted queue, ticker pill, activity log with undo/retry
- [x] M5 keys: OPENAI_API_KEY copied from thrive/apps/api/.env into Secrets.local.xcconfig (gitignored). One vendor for the whole voice path.

# Wealth server

The voice parse service: the app posts a capture's audio (or a retry's saved transcript) plus its ledger context; the server transcribes with Whisper, parses with Claude Opus 5 through subscription auth (Agent SDK, same pattern as thrive), and returns validated items.

```
npm install       # once
npm test          # unit tests (prompt + item validation)
npm run typecheck
cp .env.example .env   # then fill it in
npm start         # listens on :3002
```

`POST /v1/parse` (bearer `WEALTH_API_TOKEN`): multipart with `context` (JSON, see `src/prompt.ts`), plus `audio` (m4a) or `transcript`. Returns `{transcript, items}`; 422 `nothing_heard` / `no_amount` map to activity-log failures in the app.

Deploy: `bash deploy/deploy.sh` from the Mac. It builds the image on the box (tar context over ssh), ships `compose.yml` + `deploy/ensure-ingress.sh` to `/opt/wealth`, brings the stack up, and installs the ingress cron. `/opt/wealth/.env` is created once by hand (`WEALTH_API_TOKEN`, `OPENAI_API_KEY`, a real `CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token`) and never touched by deploys.

Ingress: only one process can own 80/443 on the box and habitron's Caddy already does, so wealth's site block (`wealth.91.98.45.41.nip.io`) is appended to `/opt/habitron/Caddyfile` **on the box** by `ensure-ingress.sh`. Thrive's CI overwrites that file on its deploys; the cron re-appends the block within a minute and reloads Caddy. Nothing about wealth lives in the thrive repo.

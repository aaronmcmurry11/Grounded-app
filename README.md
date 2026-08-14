# Grounded chat backend

A tiny Cloudflare Worker. Its only job: hold the real Anthropic API key so it
never ships inside the iOS app, and forward chat requests to Anthropic on
the app's behalf.

You do **not** need a Mac or Xcode for any of this — it all runs from a
terminal (or Claude can run these commands for you if you hand over a
Cloudflare API token the same way you handed over the GitHub token).

## One-time setup

1. **Create a free Cloudflare account** at https://dash.cloudflare.com/sign-up
   if you don't have one already.

2. **Install dependencies** (from the `backend/` folder):
   ```
   npm install
   ```

3. **Log in to Cloudflare** (opens a browser to authorize):
   ```
   npx wrangler login
   ```

4. **Set the two secrets** (you'll be prompted to paste each value — it is
   never written to a file or committed):
   ```
   npx wrangler secret put ANTHROPIC_API_KEY
   npx wrangler secret put APP_SHARED_KEY
   ```
   - `ANTHROPIC_API_KEY` is your real Anthropic API key from
     https://console.anthropic.com/settings/keys.
   - `APP_SHARED_KEY` can be any string you make up (e.g. a random password).
     It just needs to **match exactly** the `appSharedKey` value in
     `ios-grounded/Grounded/Config.swift`.

5. **Deploy:**
   ```
   npx wrangler deploy
   ```
   This prints a URL like `https://grounded-chat.YOUR-SUBDOMAIN.workers.dev`.

6. **Update the iOS app** — open `ios-grounded/Grounded/Config.swift` and set
   `backendBaseURL` to the URL from step 5.

## Redeploying after a code change

```
npx wrangler deploy
```

That's it — no app update needed unless `Config.swift`'s URL or shared key
changed.

## What this does NOT do yet

- No real retrieval/RAG grounding (the app still sends the full remedy
  catalog as context — see project notes on Phase 2 scope).
- No red-flag/emergency triage logic — that must be a deterministic layer,
  not left to the model, and isn't built yet.
- No rate limiting beyond the shared-key check. Fine for early testing;
  revisit before any public launch.

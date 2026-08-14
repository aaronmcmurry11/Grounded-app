//
//  Config.swift
//  Grounded
//
//  Non-secret app configuration. The real secret (the Anthropic API key that
//  pays for chat) lives ONLY on the backend (see /backend in the repo root),
//  set there as a Cloudflare Workers secret — never in this file, never in
//  the app binary.
//
//  `appSharedKey` below is NOT a real secret. It's a low-stakes app
//  identifier the backend checks before spending money on a chat request —
//  it just filters out casual/accidental hits to the endpoint. Anyone who
//  decompiles the shipped app can recover it, the same way they could
//  recover anything else baked into a client binary. That's an accepted
//  tradeoff for MVP; if abuse becomes a real problem, add server-side rate
//  limiting or App Attest before loosening this further.
//
//  This file is intentionally committed to git (unlike the old Rork-era
//  Config.swift) so a fresh clone of this repo builds without any missing
//  local file. Update `backendBaseURL` after deploying/redeploying the
//  Cloudflare Worker in /backend.
//

enum Config {
    /// Base URL of the deployed chat backend (Cloudflare Worker). Example:
    /// "https://grounded-chat.YOUR-SUBDOMAIN.workers.dev"
    static let backendBaseURL = "https://grounded-chat.example.workers.dev"

    /// Must match the APP_SHARED_KEY secret set on the Worker (see
    /// backend/README.md). Not a high-value secret — see note above.
    static let appSharedKey = "grounded-ios-v1"
}

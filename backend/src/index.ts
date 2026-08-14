/**
 * Grounded chat backend — a minimal Cloudflare Worker.
 *
 * The ONLY job of this service: hold the real Anthropic API key server-side
 * and forward chat requests to Anthropic on the app's behalf, so the key
 * never ships inside the iOS app binary (where it could be extracted).
 *
 * This intentionally does NOT reshape Anthropic's response — it passes it
 * straight through, so the response is exactly Anthropic's native Messages
 * API shape (`{ content: [...], stop_reason: ... }`). The iOS app decodes
 * that shape directly.
 *
 * Later phases (real RAG/retrieval grounding, deterministic red-flag
 * triage) plug in here — this is deliberately the smallest version that
 * unblocks the app, not the final architecture.
 */

export interface Env {
  ANTHROPIC_API_KEY: string;
  APP_SHARED_KEY: string;
}

const ANTHROPIC_MESSAGES_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";
// If this model alias ever 404s, check the current model list at
// https://docs.claude.com/en/docs/about-claude/models and update it here —
// nothing on the app side needs to change.
const MODEL = "claude-haiku-4-5";

interface ChatRequestBody {
  system: string;
  messages: Array<{ role: "user" | "assistant"; content: string }>;
  temperature?: number;
  max_tokens?: number;
}

function corsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, X-App-Key",
  };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders() });
    }

    const url = new URL(request.url);
    if (url.pathname !== "/chat" || request.method !== "POST") {
      return json({ error: "not found" }, 404);
    }

    const appKey = request.headers.get("X-App-Key");
    if (!env.APP_SHARED_KEY || appKey !== env.APP_SHARED_KEY) {
      return json({ error: "unauthorized" }, 401);
    }

    let body: ChatRequestBody;
    try {
      body = await request.json();
    } catch {
      return json({ error: "invalid json body" }, 400);
    }

    if (!body.system || !Array.isArray(body.messages) || body.messages.length === 0) {
      return json({ error: "missing system or messages" }, 400);
    }

    if (!env.ANTHROPIC_API_KEY) {
      return json({ error: "backend not configured" }, 500);
    }

    const anthropicResponse = await fetch(ANTHROPIC_MESSAGES_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": ANTHROPIC_VERSION,
      },
      body: JSON.stringify({
        model: MODEL,
        system: body.system,
        messages: body.messages,
        temperature: body.temperature ?? 0.4,
        max_tokens: body.max_tokens ?? 2000,
      }),
    });

    const data = await anthropicResponse.text();
    return new Response(data, {
      status: anthropicResponse.status,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  },
};

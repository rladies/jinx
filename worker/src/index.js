import { slack_event_handle } from "./slack-events.js";
import { slack_oauth_install_handle, slack_oauth_callback_handle } from "./slack-oauth.js";
import {
  airtable_webhook_handle,
  slack_interaction_handle,
} from "./airtable-invite.js";
import { slack_command_handle } from "./slash-command.js";
import { slack_signature_verify } from "./slack-api.js";
import { question_log_purge } from "./question-log.js";
import { question_digest_post } from "./question-digest.js";
import { bearer_token_extract, api_key_verify } from "./api-auth.js";
import { ai_generate_handle } from "./ai-api.js";
import { analytics_rum_handle } from "./analytics-rum.js";

const DIGEST_CRON = "0 9 * * 1";

const SLACK_ROUTES = {
  "/slack/command": slack_command_handle,
  "/slack/events": slack_event_handle,
  "/slack/interact": slack_interaction_handle,
};

// Authenticated HTTP API for other RLadies+ repos -- see docs/AGENTS.md's
// "HTTP API for other repos" section. Gated by JINX_API_KEY rather than
// Slack's per-route signature scheme, since these callers aren't Slack.
const API_ROUTES = {
  "/ai/generate": ai_generate_handle,
  "/analytics/rum": analytics_rum_handle,
};

export default {
  async fetch(request, env, ctx) {
    try {
      return await route(request, env, ctx);
    } catch (err) {
      console.error("Worker handler threw:", err);
      return new Response(`Worker error: ${err?.message || "unknown"}`, {
        status: 503,
        headers: { "Content-Type": "text/plain" },
      });
    }
  },

  async scheduled(event, env, ctx) {
    if (event.cron === DIGEST_CRON) {
      ctx.waitUntil(question_digest_post(env, { days: 7 }));
    } else {
      ctx.waitUntil(question_log_purge(env));
    }
  },
};

async function route(request, env, ctx) {
  const url = new URL(request.url);

  if (request.method === "GET" && url.pathname === "/slack/install") {
    return slack_oauth_install_handle(env, url);
  }
  if (request.method === "GET" && url.pathname === "/slack/oauth") {
    return slack_oauth_callback_handle(request, env);
  }

  if (request.method !== "POST") {
    return new Response("Hi! I'm the Jinx Slack bridge. Nothing to see here. 🔮", {
      status: 200,
    });
  }

  if (url.pathname === "/airtable/webhook") {
    return airtable_webhook_handle(request, env);
  }

  const apiHandler = API_ROUTES[url.pathname];
  if (apiHandler) {
    const provided = bearer_token_extract(request);
    if (!(await api_key_verify(env.JINX_API_KEY, provided))) {
      console.warn(`Rejected API request to ${url.pathname}: bad or missing key`);
      return new Response("Unauthorized", { status: 401 });
    }
    return apiHandler(request, env);
  }

  const slackHandler = SLACK_ROUTES[url.pathname];
  if (!slackHandler) {
    return new Response("Not found", { status: 404 });
  }

  const body = await request.text();
  const timestamp = request.headers.get("x-slack-request-timestamp");
  const signature = request.headers.get("x-slack-signature");

  if (
    !(await slack_signature_verify(
      env.SLACK_SIGNING_SECRET,
      timestamp,
      body,
      signature
    ))
  ) {
    console.log("Signature verification failed");
    return new Response("Invalid signature", { status: 401 });
  }

  return slackHandler(env, ctx, body);
}

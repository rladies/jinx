import { handleSlackEvent } from "./slack-events.js";
import { handleSlackInstall, handleSlackOAuthCallback } from "./slack-oauth.js";
import {
  handleAirtableWebhook,
  handleSlackInteraction,
} from "./airtable-invite.js";
import { handleSlashCommand } from "./slash-command.js";
import { verifySlackSignature } from "./slack-api.js";

const SLACK_ROUTES = {
  "/slack/command": handleSlashCommand,
  "/slack/events": handleSlackEvent,
  "/slack/interact": handleSlackInteraction,
};

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/slack/install") {
      return handleSlackInstall(env, url);
    }
    if (request.method === "GET" && url.pathname === "/slack/oauth") {
      return handleSlackOAuthCallback(request, env);
    }

    if (request.method !== "POST") {
      return new Response("Hi! I'm the Jinx Slack bridge. Nothing to see here. 🔮", {
        status: 200,
      });
    }

    if (url.pathname === "/airtable/webhook") {
      return handleAirtableWebhook(request, env);
    }

    const slackHandler = SLACK_ROUTES[url.pathname];
    if (!slackHandler) {
      return new Response("Not found", { status: 404 });
    }

    const body = await request.text();
    const timestamp = request.headers.get("x-slack-request-timestamp");
    const signature = request.headers.get("x-slack-signature");

    if (
      !(await verifySlackSignature(
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
  },
};

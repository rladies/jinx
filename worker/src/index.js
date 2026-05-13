import { slack_event_handle } from "./slack-events.js";
import { slack_oauth_install_handle, slack_oauth_callback_handle } from "./slack-oauth.js";
import {
  airtable_webhook_handle,
  slack_interaction_handle,
} from "./airtable-invite.js";
import { slack_command_handle } from "./slash-command.js";
import { slack_signature_verify } from "./slack-api.js";

const SLACK_ROUTES = {
  "/slack/command": slack_command_handle,
  "/slack/events": slack_event_handle,
  "/slack/interact": slack_interaction_handle,
};

export default {
  async fetch(request, env, ctx) {
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
  },
};

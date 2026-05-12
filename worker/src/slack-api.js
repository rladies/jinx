export async function postSlackMessage(env, { channel, thread_ts, text, blocks }) {
  const body = { channel, text };
  if (thread_ts) body.thread_ts = thread_ts;
  if (blocks) body.blocks = blocks;

  const res = await fetch("https://slack.com/api/chat.postMessage", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.SLACK_ORGANISER_TOKEN}`,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify(body),
  });

  const result = await res.json();
  if (!result.ok) {
    throw new Error(`Slack postMessage failed: ${result.error}`);
  }
  return result;
}

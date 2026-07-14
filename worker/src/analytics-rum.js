// Thin proxy to Cloudflare's GraphQL RUM Analytics API (the same query
// `cloudflarer::cf_rum_page_views()`/`cf_rum_top()` build directly) so a
// caller never needs its own Cloudflare API token. Only the single-window
// fetch lives here -- chunking across <=90-day windows, retry, and
// retention-aware aggregation stay in the calling repo's own code.
const DIMENSION_RE = /^[A-Za-z_][A-Za-z0-9_]*$/;

export async function analytics_rum_handle(request, env) {
  let payload;
  try {
    payload = await request.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const { account_id, site_tag, since, until, dimension = "date", limit } = payload;

  if (!account_id || !site_tag || !since || !until) {
    return new Response("account_id, site_tag, since, until are required", {
      status: 400,
    });
  }
  // `dimension` is interpolated directly into the GraphQL query text below,
  // so an unvalidated value is a query-injection point. "count" is reserved
  // (the metric column every query already selects).
  if (!DIMENSION_RE.test(dimension) || dimension === "count") {
    return new Response("Invalid dimension", { status: 400 });
  }

  const orderBy = dimension === "date" ? "date_ASC" : "count_DESC";
  const query = `query($accountTag:String!,$siteTag:String!,$since:Time!,$until:Time!,$limit:Int!){
    viewer{accounts(filter:{accountTag:$accountTag}){
      rumPageloadEventsAdaptiveGroups(limit:$limit,filter:{siteTag:$siteTag,datetime_geq:$since,datetime_lt:$until},orderBy:[${orderBy}]){
        count dimensions{${dimension}}
      }}}}`;

  let res;
  try {
    res = await fetch("https://api.cloudflare.com/client/v4/graphql", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.CLOUDFLARE_API_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        query,
        variables: {
          accountTag: account_id,
          siteTag: site_tag,
          since,
          until,
          limit: limit || 10000,
        },
      }),
    });
  } catch (err) {
    console.error("Cloudflare GraphQL request failed:", err);
    return new Response(`Cloudflare GraphQL request failed: ${err.message}`, {
      status: 502,
    });
  }

  const body = await res.json();
  if (!res.ok || body.errors?.length) {
    console.error("Cloudflare GraphQL query failed:", body.errors || res.status);
    return new Response(JSON.stringify({ error: body.errors || `HTTP ${res.status}` }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }

  const groups = body.data?.viewer?.accounts?.[0]?.rumPageloadEventsAdaptiveGroups || [];
  return new Response(JSON.stringify({ groups }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

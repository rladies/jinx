export function bearer_token_extract(request) {
  const header = request.headers.get("authorization") || "";
  return header.startsWith("Bearer ") ? header.slice(7) : "";
}

// Constant-time key comparison: digest both sides to fixed-length 32-byte
// arrays first, then XOR-accumulate with no early return, so neither the
// key's length nor its content leaks through timing.
export async function api_key_verify(expectedKey, providedKey) {
  if (!expectedKey || !providedKey) return false;

  const enc = new TextEncoder();
  const [a, b] = await Promise.all([
    crypto.subtle.digest("SHA-256", enc.encode(expectedKey)),
    crypto.subtle.digest("SHA-256", enc.encode(providedKey)),
  ]);
  const av = new Uint8Array(a);
  const bv = new Uint8Array(b);

  let diff = 0;
  for (let i = 0; i < av.length; i++) {
    diff |= av[i] ^ bv[i];
  }
  return diff === 0;
}

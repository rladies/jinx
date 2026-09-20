// Crypto-random id generator over a URL-safe alphabet with no visually
// ambiguous characters (no 0/O/1/l/I). Shared by the URL shortener
// (short-links.js) and the invite gateway (invite-gateway.js).
const ALPHABET = "23456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ";

export function random_id(length) {
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  let out = "";
  for (const b of bytes) out += ALPHABET[b % ALPHABET.length];
  return out;
}

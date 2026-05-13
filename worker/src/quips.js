const FETCH_FAILURE_QUIPS = [
  "🐈‍⬛ Sorry — I couldn't fetch an answer just now. *grooms paw, regroups* — try me again in a moment?",
  "🐈‍⬛ Yowch — something tangled up between me and the answer. Give me a wiggle and try again?",
  "🐈‍⬛ My whiskers twitched at the wrong moment and I lost the thread. Try again?",
  "🐈‍⬛ I batted that one straight under the sofa. Could you try again in a moment?",
  "🐈‍⬛ Hairball moment — I couldn't pull the answer together. Another go?",
  "🐈‍⬛ Sorry, I tripped over my own tail and dropped the answer. Want to try again?",
  "🐈‍⬛ *stares at the empty void where the answer should be* … nope, lost it. Try again?",
  "🐈‍⬛ I knocked the answer off the table and it rolled away. Mind asking again?",
  "🐈‍⬛ My nine lives include a few clumsy ones — that was one of them. Give it another go?",
  "🐈‍⬛ Something went sideways and the answer slipped past my paws. Try once more?",
];

const NO_MATCH_QUIPS = [
  "🐈‍⬛ My whiskers came up empty — I couldn't find anything on that in the RLadies+ guide or website. Try rephrasing, or ask in #help-rladies and a human can pick up where my paws gave up.",
  "🐈‍⬛ I sniffed around the RLadies+ guide and website and came back with nothing. Try rephrasing, or ask in #help-rladies — a human might have the answer.",
  "🐈‍⬛ Nothing on that in the guide or website that I could spot. Want to rephrase, or shall we ask in #help-rladies?",
  "🐈‍⬛ I patrolled the whole guide and the website and turned up zero leads. Try rephrasing, or pop the question into #help-rladies.",
  "🐈‍⬛ Drew a blank on that one — the guide and the website didn't have anything I could use. Rephrasing sometimes helps, otherwise #help-rladies is your best bet.",
];

const DISPATCH_FAILURE_QUIPS = [
  "😿 Oops — I dropped that command behind the sofa and couldn't start it. Give it another try in a moment, or let a maintainer know.",
  "😿 That command slipped through my paws before I could start it. Try again in a moment, or flag a maintainer.",
  "😿 I fumbled the handover and couldn't kick off that command. Another try, or ping a maintainer if it sticks.",
  "😿 Something jammed before I could even start that one. Have another go, or let a maintainer know if it keeps misbehaving.",
];

export function pick_quip(list) {
  return list[Math.floor(Math.random() * list.length)];
}

export function fetch_failure_quip() {
  return pick_quip(FETCH_FAILURE_QUIPS);
}

export function no_match_quip() {
  return pick_quip(NO_MATCH_QUIPS);
}

export function dispatch_failure_quip() {
  return pick_quip(DISPATCH_FAILURE_QUIPS);
}

// Reads a restaurant's Google reviews against someone's red flags and decides:
// eat here, be careful, or stay away. Runs entirely in the browser.
//
// Same rules as the Cloud Functions version (functions/analysis.js), with one
// change for long review lists: a non-critical flag only counts as serious
// when at least 2 reviews, and at least 3 % of them, complain about it. One
// person getting sick still matters more than ten finding the waiter slow.

const RED_FLAGS = [
  {
    id: "dirty", label: "Nicht sauber", critical: false,
    keywords: [
      "dreckig", "schmutzig", "verschmutzt", "unsauber", "unhygienisch",
      "hygiene", "klebrig", "eklig", "ekelhaft", "toilette war", "wc war",
      "fettig und", "haare im", "ein haar", "dirty", "filthy", "unclean",
      "unhygienic", "sticky table", "disgusting", "hair in",
    ],
  },
  {
    id: "food_poisoning", label: "Lebensmittelvergiftung", critical: true,
    keywords: [
      "lebensmittelvergiftung", "vergiftung", "magen-darm", "magendarm",
      "durchfall", "erbrochen", "übergeben", "übel geworden", "mir war übel",
      "krank geworden", "wurde krank", "bauchschmerzen", "salmonellen",
      "food poisoning", "got sick", "became sick", "made me sick",
      "threw up", "vomit", "diarrhea", "diarrhoea", "stomach ache",
      "stomach cramps", "salmonella",
    ],
  },
  {
    id: "pests", label: "Ungeziefer", critical: true,
    keywords: [
      "kakerlake", "schabe", "maus", "mäuse", "ratte", "ungeziefer",
      "insekt im", "fliegen überall", "maden", "cockroach", "roach",
      "mouse", "mice", "rat ", "rats", "bug in", "insect in", "maggot",
    ],
  },
  {
    id: "spoiled_food", label: "Verdorbenes Essen", critical: true,
    keywords: [
      "verdorben", "schimmel", "schimmlig", "abgelaufen", "gammel",
      "nicht mehr frisch", "roch komisch", "stank", "roh war", "nicht durch",
      "spoiled", "mould", "mold", "rotten", "expired", "undercooked",
      "raw chicken", "smelled off", "gone off",
    ],
  },
  {
    id: "bad_service", label: "Schlechter Service", critical: false,
    keywords: [
      "schlechter service", "service war schlecht", "miserabler service",
      "ignoriert", "vergessen", "falsche bestellung", "nie wieder",
      "katastrophe", "bad service", "poor service", "terrible service",
      "ignored us", "forgot our", "wrong order", "never again",
    ],
  },
  {
    id: "rude_staff", label: "Unfreundliches Personal", critical: false,
    keywords: [
      "unfreundlich", "unhöflich", "frech", "arrogant", "angeschrien",
      "respektlos", "genervt", "rude", "unfriendly", "impolite",
      "disrespectful", "yelled", "shouted at", "attitude",
    ],
  },
  {
    id: "long_wait", label: "Lange Wartezeit", critical: false,
    keywords: [
      "lange gewartet", "ewig gewartet", "wartezeit", "stunde gewartet",
      "minuten gewartet", "ewig gedauert", "sehr lange", "waited forever",
      "long wait", "waited an hour", "took forever", "slow service",
    ],
  },
  {
    id: "overpriced", label: "Überteuert", critical: false,
    keywords: [
      "überteuert", "zu teuer", "abzocke", "abgezockt", "wucher",
      "preis-leistung stimmt nicht", "overpriced", "rip off", "rip-off",
      "ripoff", "too expensive", "not worth the price",
    ],
  },
  {
    id: "bad_food", label: "Schlechtes Essen", critical: false,
    keywords: [
      "geschmacklos", "fade", "kalt serviert", "lauwarm", "versalzen",
      "verbrannt", "zäh", "schmeckte nicht", "ungeniessbar", "ungenießbar",
      "tasteless", "bland", "served cold", "lukewarm", "too salty", "burnt",
      "inedible", "tasted bad",
    ],
  },
  {
    id: "allergies", label: "Allergien nicht ernst genommen", critical: true,
    keywords: [
      "allergie", "allergisch", "allergische reaktion", "glutenfrei",
      "laktose", "nüsse", "allergy", "allergic", "allergic reaction",
      "gluten", "nut-free", "anaphyla",
    ],
  },
];

/** Reviews at or above this many stars are not counted as complaints. */
const POSITIVE_RATING = 4;
const SNIPPET_RADIUS = 80;
const MAX_EVIDENCE = 4;

/** Known ids plus free-text flags in the person's own words. */
function resolveFlags(ids, custom) {
  const flags = RED_FLAGS.filter((f) => ids.includes(f.id))
      .map((f) => ({...f, custom: false}));
  for (const text of custom) {
    const label = String(text).trim().slice(0, 80);
    if (!label) continue;
    flags.push({
      id: `custom:${label.toLowerCase()}`, label, critical: false,
      keywords: [label.toLowerCase()], custom: true,
    });
  }
  return flags;
}

function verdictFor(flags, reviewCount) {
  if (reviewCount === 0) return "unknown";
  if (flags.some((f) => f.critical && f.status === "serious")) return "avoid";
  if (flags.some((f) => f.status !== "clear")) return "caution";
  return "ok";
}

function snippet(text, index, length) {
  let start = Math.max(0, index - SNIPPET_RADIUS);
  let end = Math.min(text.length, index + length + SNIPPET_RADIUS);
  if (start > 0) start = text.indexOf(" ", start) + 1 || start;
  if (end < text.length) end = text.lastIndexOf(" ", end) || end;
  const body = text.slice(start, end).replace(/\s+/g, " ").trim();
  return `${start > 0 ? "…" : ""}${body}${end < text.length ? "…" : ""}`;
}

function summaryFor(verdict, flags) {
  const hit = flags.filter((f) => f.status !== "clear").map((f) => f.label);
  switch (verdict) {
    case "unknown":
      return "Zu diesem Restaurant gibt es keine Bewertungen mit Text. " +
        "Wir können dir nichts Verlässliches sagen.";
    case "avoid":
      return `Achtung: In den Bewertungen tauchen ernste Hinweise auf ` +
        `(${hit.join(", ")}). Wir würden hier eher nicht essen.`;
    case "caution":
      return `Sei vorsichtig: Einige Bewertungen erwähnen ${hit.join(", ")}.`;
    default:
      return "In den Bewertungen haben wir keine deiner Red Flags " +
        "gefunden. Guten Appetit!";
  }
}

/**
 * @param {Array<{text: string, rating: number|null, when: string}>} reviews
 * @param {ReturnType<typeof resolveFlags>} flags
 */
function analyze(reviews, flags) {
  const withText = reviews.filter((r) => r.text && r.text.trim());
  const seriousAt = Math.max(2, Math.ceil(withText.length * 0.03));
  const results = flags.map((flag) => {
    const evidence = [];
    for (const review of withText) {
      if (review.rating != null && review.rating >= POSITIVE_RATING) continue;
      const lower = review.text.toLowerCase();
      const keyword = flag.keywords.find((k) => lower.includes(k));
      if (!keyword) continue;
      evidence.push({
        quote: snippet(review.text, lower.indexOf(keyword), keyword.length),
        rating: review.rating,
        when: review.when,
      });
    }
    let status = "clear";
    if ((flag.critical && evidence.length >= 1) ||
        evidence.length >= seriousAt) {
      status = "serious";
    } else if (evidence.length >= 1) {
      status = "mentioned";
    }
    const note = status === "clear" ?
      "Nichts gefunden." :
      `${evidence.length} von ${withText.length} Bewertungen erwähnen das.`;
    return {
      id: flag.id, label: flag.label, critical: flag.critical,
      status, note, count: evidence.length,
      evidence: evidence.slice(0, MAX_EVIDENCE),
    };
  });
  const verdict = verdictFor(results, withText.length);
  return {
    verdict, summary: summaryFor(verdict, results),
    reviewsRead: withText.length, flags: results,
  };
}

if (typeof module !== "undefined") {
  module.exports = {RED_FLAGS, resolveFlags, analyze, verdictFor, snippet};
}

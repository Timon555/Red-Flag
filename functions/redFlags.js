/**
 * The red flags someone can pick in the app, and the words that give each one
 * away in a review.
 *
 * The ids are the contract with the app: `lib/red_flags.dart` holds the same
 * list with the labels and icons, and a flag the backend does not know here is
 * treated as a custom flag (matched on its own words).
 *
 * `critical` flags are the ones where a single credible report is enough to
 * stay away: one person getting sick matters more than ten people finding the
 * waiter slow.
 *
 * Keywords are lower-case stems in German and English, matched as substrings,
 * so "schmutzig" also catches "schmutzige" and "verschmutzt" is listed on its
 * own. Keep them specific: "kalt" alone would flag every ice-cream parlour.
 */

const RED_FLAGS = {
  dirty: {
    label: "Nicht sauber",
    critical: false,
    keywords: [
      "dreckig", "schmutzig", "verschmutzt", "unsauber", "unhygienisch",
      "hygiene", "klebrig", "eklig", "ekelhaft", "toilette war", "wc war",
      "fettig und", "haare im", "ein haar", "dirty", "filthy", "unclean",
      "unhygienic", "sticky table", "disgusting", "hair in",
    ],
  },
  food_poisoning: {
    label: "Lebensmittelvergiftung",
    critical: true,
    keywords: [
      "lebensmittelvergiftung", "vergiftung", "magen-darm", "magendarm",
      "durchfall", "erbrochen", "übergeben", "übel geworden", "mir war übel",
      "krank geworden", "wurde krank", "bauchschmerzen", "salmonellen",
      "food poisoning", "got sick", "became sick", "made me sick",
      "threw up", "vomit", "diarrhea", "diarrhoea", "stomach ache",
      "stomach cramps", "salmonella",
    ],
  },
  pests: {
    label: "Ungeziefer",
    critical: true,
    keywords: [
      "kakerlake", "schabe", "maus", "mäuse", "ratte", "ungeziefer",
      "insekt im", "fliegen überall", "maden", "cockroach", "roach",
      "mouse", "mice", "rat ", "rats", "bug in", "insect in", "maggot",
    ],
  },
  spoiled_food: {
    label: "Verdorbenes Essen",
    critical: true,
    keywords: [
      "verdorben", "schimmel", "schimmlig", "abgelaufen", "gammel",
      "nicht mehr frisch", "roch komisch", "stank", "roh war", "nicht durch",
      "spoiled", "mould", "mold", "rotten", "expired", "undercooked",
      "raw chicken", "smelled off", "gone off",
    ],
  },
  bad_service: {
    label: "Schlechter Service",
    critical: false,
    keywords: [
      "schlechter service", "service war schlecht", "miserabler service",
      "ignoriert", "vergessen", "falsche bestellung", "nie wieder",
      "katastrophe", "bad service", "poor service", "terrible service",
      "ignored us", "forgot our", "wrong order", "never again",
    ],
  },
  rude_staff: {
    label: "Unfreundliches Personal",
    critical: false,
    keywords: [
      "unfreundlich", "unhöflich", "frech", "arrogant", "angeschrien",
      "respektlos", "genervt", "rude", "unfriendly", "impolite",
      "disrespectful", "yelled", "shouted at", "attitude",
    ],
  },
  long_wait: {
    label: "Lange Wartezeit",
    critical: false,
    keywords: [
      "lange gewartet", "ewig gewartet", "wartezeit", "stunde gewartet",
      "minuten gewartet", "ewig gedauert", "sehr lange", "waited forever",
      "long wait", "waited an hour", "took forever", "slow service",
    ],
  },
  overpriced: {
    label: "Überteuert",
    critical: false,
    keywords: [
      "überteuert", "zu teuer", "abzocke", "abgezockt", "wucher",
      "preis-leistung stimmt nicht", "overpriced", "rip off", "rip-off",
      "ripoff", "too expensive", "not worth the price",
    ],
  },
  bad_food: {
    label: "Schlechtes Essen",
    critical: false,
    keywords: [
      "geschmacklos", "fade", "kalt serviert", "lauwarm", "versalzen",
      "verbrannt", "zäh", "schmeckte nicht", "ungeniessbar", "ungenießbar",
      "tasteless", "bland", "served cold", "lukewarm", "too salty", "burnt",
      "inedible", "tasted bad",
    ],
  },
  allergies: {
    label: "Allergien nicht ernst genommen",
    critical: true,
    keywords: [
      "allergie", "allergisch", "allergische reaktion", "glutenfrei",
      "laktose", "nüsse", "allergy", "allergic", "allergic reaction",
      "gluten", "nut-free", "anaphyla",
    ],
  },
};

/**
 * Turns what the app sent into the flags to look for: known ids get their
 * catalogue entry, anything else is a custom flag described in the user's own
 * words. Duplicates and blanks are dropped; at most 20 flags survive, which is
 * more than anyone picks and keeps the prompt small.
 *
 * @param {unknown} ids Known flag ids from the app.
 * @param {unknown} custom Free-text flags from the app.
 * @return {Array<{id: string, label: string, critical: boolean,
 *   keywords: string[], custom: boolean}>}
 */
function resolveFlags(ids, custom) {
  const flags = [];
  const seen = new Set();
  for (const id of Array.isArray(ids) ? ids : []) {
    const entry = typeof id === "string" ? RED_FLAGS[id] : undefined;
    if (!entry || seen.has(id)) continue;
    seen.add(id);
    flags.push({id, ...entry, custom: false});
  }
  for (const text of Array.isArray(custom) ? custom : []) {
    if (typeof text !== "string") continue;
    const label = text.trim().slice(0, 80);
    const id = `custom:${label.toLowerCase()}`;
    if (!label || seen.has(id)) continue;
    seen.add(id);
    flags.push({
      id,
      label,
      critical: false,
      keywords: [label.toLowerCase()],
      custom: true,
    });
  }
  return flags.slice(0, 20);
}

module.exports = {RED_FLAGS, resolveFlags};

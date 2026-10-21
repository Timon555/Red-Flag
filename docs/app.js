// Red Flag, phone edition: paste a Google Maps link, Apify's Google Maps
// Reviews Scraper fetches the reviews, analysis.js judges them.
//
// Everything lives in this browser: the Apify token, the chosen flags and the
// history are in localStorage, and Apify is called directly (it allows CORS).

const ACTOR = "compass~google-maps-reviews-scraper";
const API = "https://api.apify.com/v2";
const POLL_MS = 3000;

const $ = (id) => document.getElementById(id);
const store = {
  get(key, fallback) {
    try {
      const v = localStorage.getItem(key);
      return v ? JSON.parse(v) : fallback;
    } catch {
      return fallback;
    }
  },
  set(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch {}
  },
};

let selected = new Set(store.get("rf.selected",
    ["dirty", "food_poisoning", "pests", "spoiled_food"]));
let custom = store.get("rf.custom", []);
let checks = store.get("rf.history", []);
let controller = null;

// ---------- Setup ----------

function token() {
  return store.get("rf.token", "");
}

function showSetup(show) {
  $("setup").hidden = !show;
  if (show) $("token-input").value = token();
}

$("settings-btn").onclick = () => showSetup($("setup").hidden);
$("token-form").addEventListener("submit", (e) => {
  e.preventDefault();
  const value = $("token-input").value.trim();
  if (!value) return;
  store.set("rf.token", value);
  showSetup(false);
});

// ---------- Red flags ----------

function renderChips() {
  const box = $("chips");
  box.replaceChildren();
  for (const flag of RED_FLAGS) {
    const b = document.createElement("button");
    b.type = "button";
    b.className = "chip";
    b.textContent = flag.label;
    b.setAttribute("aria-pressed", selected.has(flag.id));
    b.onclick = () => {
      if (selected.has(flag.id)) selected.delete(flag.id);
      else selected.add(flag.id);
      store.set("rf.selected", [...selected]);
      renderChips();
    };
    box.append(b);
  }
  for (const label of custom) {
    const b = document.createElement("button");
    b.type = "button";
    b.className = "chip";
    b.setAttribute("aria-pressed", "true");
    b.setAttribute("aria-label", `${label} entfernen`);
    b.textContent = `${label} ×`;
    b.onclick = () => {
      custom = custom.filter((c) => c !== label);
      store.set("rf.custom", custom);
      renderChips();
    };
    box.append(b);
  }
}

$("custom-form").addEventListener("submit", (e) => {
  e.preventDefault();
  const label = $("custom-input").value.trim().slice(0, 80);
  if (label && !custom.some((c) => c.toLowerCase() === label.toLowerCase())) {
    custom.push(label);
    store.set("rf.custom", custom);
    renderChips();
  }
  $("custom-input").value = "";
});

// ---------- Link handling ----------

/** The first Google Maps link in a piece of shared or pasted text. */
function findMapsLink(text) {
  const urls = String(text || "").match(/https?:\/\/[^\s<>"]+/g) || [];
  return urls.find((u) =>
    /^https?:\/\/(maps\.app\.goo\.gl|goo\.gl\/maps|g\.co\/kgs|(www\.|maps\.)?google\.[a-z.]+\/maps)/i
        .test(u)) || "";
}

$("paste-btn").onclick = async () => {
  try {
    const text = await navigator.clipboard.readText();
    const link = findMapsLink(text);
    if (link) $("link-input").value = link;
    else showError("In der Zwischenablage ist kein Google-Maps-Link.");
  } catch {
    $("link-input").focus();
  }
};

// ---------- Apify ----------

async function apify(path, options = {}) {
  const res = await fetch(API + path, {
    ...options,
    headers: {
      "Authorization": `Bearer ${token()}`,
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });
  const json = await res.json().catch(() => null);
  if (!res.ok) {
    const err = new Error(json?.error?.message || res.statusText);
    err.status = res.status;
    err.type = json?.error?.type;
    throw err;
  }
  return json;
}

function apifyErrorText(err) {
  if (err.name === "AbortError") return "Abgebrochen.";
  if (err.status === 401) {
    return "Der Apify-Schlüssel stimmt nicht. Tippe oben auf „Schlüssel“ " +
      "und füge ihn neu ein.";
  }
  if (err.status === 402 || /usage|credit|limit/i.test(err.message)) {
    return "Das Apify-Guthaben für diesen Monat ist aufgebraucht. " +
      "Nächsten Monat geht es wieder.";
  }
  if (err.status === undefined) {
    return "Keine Verbindung. Prüfe dein Internet und versuch es nochmal.";
  }
  return `Apify meldet einen Fehler: ${err.message}`;
}

async function fetchReviews(url, max, signal) {
  setStatus("Starte die Abfrage …");
  const run = await apify(`/acts/${ACTOR}/runs`, {
    method: "POST",
    signal,
    body: JSON.stringify({
      startUrls: [{url}],
      maxReviews: max,
      reviewsSort: "newest",
      language: "de",
      reviewsOrigin: "google",
      personalData: false,
    }),
  });
  let info = run.data;
  const started = Date.now();
  try {
    while (!["SUCCEEDED", "FAILED", "ABORTED", "TIMED-OUT"]
        .includes(info.status)) {
      const secs = Math.round((Date.now() - started) / 1000);
      setStatus(`Google-Bewertungen werden geladen … ${secs} s`);
      await sleep(POLL_MS, signal);
      info = (await apify(`/actor-runs/${info.id}`, {signal})).data;
    }
  } catch (err) {
    if (err.name === "AbortError") {
      apify(`/actor-runs/${info.id}/abort`, {method: "POST"}).catch(() => {});
    }
    throw err;
  }
  if (info.status !== "SUCCEEDED") {
    throw Object.assign(new Error(`Lauf ${info.status}`), {status: 500});
  }
  setStatus("Bewertungen werden ausgewertet …");
  return apify(`/datasets/${info.defaultDatasetId}/items?clean=true`,
      {signal});
}

function sleep(ms, signal) {
  return new Promise((resolve, reject) => {
    const t = setTimeout(resolve, ms);
    signal.addEventListener("abort", () => {
      clearTimeout(t);
      reject(new DOMException("Abgebrochen", "AbortError"));
    }, {once: true});
  });
}

// ---------- Checking ----------

function setStatus(text) {
  $("status-text").textContent = text;
}

function showError(text) {
  $("error").textContent = text;
  $("error").hidden = false;
}

$("stop-btn").onclick = () => controller?.abort();

$("check-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  $("error").hidden = true;
  if (!token()) {
    showSetup(true);
    showError("Richte zuerst einmalig deinen Apify-Schlüssel ein.");
    return;
  }
  const raw = $("link-input").value.trim();
  const url = findMapsLink(raw) || raw;
  if (!findMapsLink(url)) {
    showError("Das ist kein Google-Maps-Link. Tippe in Google Maps beim " +
      "Restaurant auf „Teilen“ → „Link kopieren“.");
    return;
  }
  const flags = resolveFlags([...selected], custom);
  if (!flags.length) {
    showError("Wähle unten mindestens eine Red Flag.");
    return;
  }

  controller = new AbortController();
  $("status").hidden = false;
  $("check-btn").disabled = true;
  try {
    const items = await fetchReviews(url,
        Number($("count-select").value), controller.signal);
    const place = items.find((i) => i.title) || {};
    if (!items.length) {
      showError(/goo\.gl/.test(url) ?
        "Für diesen Link kamen keine Bewertungen zurück. Öffne den Link " +
          "einmal im Browser und kopiere die lange Adresse " +
          "(google.com/maps/place/…) aus der Adresszeile." :
        "Für diesen Link kamen keine Bewertungen zurück. Ist es ein " +
          "einzelnes Restaurant?");
      return;
    }
    const reviews = items.map((i) => ({
      text: i.text || "",
      rating: i.stars ?? null,
      when: i.publishAt || "",
    }));
    const result = {
      ...analyze(reviews, flags),
      restaurant: place.title || "",
      address: place.address || "",
      googleRating: place.totalScore ?? null,
      googleCount: place.reviewsCount ?? null,
      loaded: items.length,
      url: place.url || url,
      at: new Date().toISOString(),
    };
    renderResult(result);
    checks = [result, ...checks.filter((h) => h.url !== result.url)]
        .slice(0, 15);
    store.set("rf.history", checks);
    renderHistory();
  } catch (err) {
    showError(apifyErrorText(err));
  } finally {
    $("status").hidden = true;
    $("check-btn").disabled = false;
    controller = null;
  }
});

// ---------- Rendering ----------

const VERDICT_TEXT = {
  ok: "Hier kannst du essen",
  caution: "Sei vorsichtig",
  avoid: "Lieber nicht",
  unknown: "Keine Aussage möglich",
};
const STATUS_TEXT = {clear: "Nichts", mentioned: "Hinweis", serious: "Ernst"};

function el(tag, props = {}, ...children) {
  const node = Object.assign(document.createElement(tag), props);
  node.append(...children);
  return node;
}

function renderResult(r) {
  const meta = [];
  if (r.address) meta.push(r.address);
  if (r.googleRating != null) {
    meta.push(`${r.googleRating.toFixed(1).replace(".", ",")} ★ aus ` +
      `${r.googleCount ?? "?"} Google-Bewertungen`);
  }
  meta.push(`${r.reviewsRead} neueste mit Text geprüft`);

  const order = {serious: 0, mentioned: 1, clear: 2};
  const list = el("ul", {className: "flags"});
  for (const f of [...r.flags].sort((a, b) =>
    order[a.status] - order[b.status])) {
    const body = el("div", {className: "body"},
        el("strong", {textContent: f.label}),
        el("p", {textContent: f.note}));
    for (const ev of f.evidence) {
      const cite = [ev.rating ? `${ev.rating} ★` : "", ev.when]
          .filter(Boolean).join(" · ");
      body.append(el("blockquote", {}, `„${ev.quote}“`,
          cite ? el("cite", {textContent: cite}) : ""));
    }
    list.append(el("li", {className: "flag"},
        el("span", {className: `st ${f.status}`,
          textContent: STATUS_TEXT[f.status]}), body));
  }

  const card = el("article", {className: `card verdict ${r.verdict}`},
      el("div", {},
          el("div", {className: "badge"}, el("span", {className: "dot"}),
              VERDICT_TEXT[r.verdict]),
          el("h2", {textContent: r.restaurant || "Restaurant"}),
          el("div", {className: "meta", textContent: meta.join(" · ")})),
      el("p", {textContent: r.summary, style: "margin:0"}),
      list,
      el("a", {href: r.url, target: "_blank", rel: "noopener",
        textContent: "In Google Maps öffnen"}));
  $("result").replaceChildren(card);
  card.scrollIntoView({behavior: "smooth", block: "start"});
}

function renderHistory() {
  $("history-section").hidden = !checks.length;
  $("history").replaceChildren(...checks.map((h) => {
    const date = new Date(h.at).toLocaleDateString("de-CH");
    const b = el("button", {type: "button"},
        el("span", {className: `dot ${h.verdict}`}),
        el("span", {className: "name", textContent: h.restaurant || h.url}),
        el("small", {textContent: date}));
    b.querySelector(".dot").style.background = "currentColor";
    b.querySelector(".dot").style.color = `var(--${{
      ok: "ok", caution: "warn", avoid: "bad", unknown: "muted"}[h.verdict]})`;
    b.onclick = () => renderResult(h);
    return el("li", {}, b);
  }));
}

// ---------- Start ----------

renderChips();
renderHistory();
if (!token()) showSetup(true);

// Opened through "Teilen → Red Flag" (Android share target) or ?link=…
const params = new URLSearchParams(location.search);
const shared = findMapsLink([params.get("url"), params.get("text"),
  params.get("link")].join(" "));
if (shared) {
  $("link-input").value = shared;
  window.history.replaceState(null, "", location.pathname);
  if (token()) $("check-form").requestSubmit();
}

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("sw.js").catch(() => {});
}

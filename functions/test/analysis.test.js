const test = require("node:test");
const assert = require("node:assert/strict");

const {analyzeWithKeywords, snippet} = require("../analysis");
const {resolveFlags} = require("../redFlags");

function place(reviews) {
  return {name: "Test", address: "", rating: 4, ratingCount: 10, reviews};
}

test("a single food-poisoning report means stay away", () => {
  const result = analyzeWithKeywords(place([
    {rating: 1, text: "Nach dem Essen hatte ich eine Lebensmittelvergiftung.",
      when: "vor 2 Wochen"},
    {rating: 5, text: "Sehr lecker!", when: "vor 1 Monat"},
  ]), resolveFlags(["food_poisoning", "dirty"], []));
  assert.equal(result.verdict, "avoid");
  assert.equal(result.flags[0].status, "serious");
  assert.equal(result.flags[0].evidence.length, 1);
  assert.equal(result.flags[1].status, "clear");
});

test("one complaint about service is a reason for caution", () => {
  const result = analyzeWithKeywords(place([
    {rating: 2, text: "Die Kellnerin war sehr unfreundlich.", when: ""},
  ]), resolveFlags(["rude_staff"], []));
  assert.equal(result.verdict, "caution");
  assert.equal(result.flags[0].status, "mentioned");
});

test("positive reviews are not held against the restaurant", () => {
  const result = analyzeWithKeywords(place([
    {rating: 5, text: "Keine Spur von dreckig, alles top!", when: ""},
  ]), resolveFlags(["dirty"], []));
  assert.equal(result.verdict, "ok");
});

test("no reviews means no verdict", () => {
  const result = analyzeWithKeywords(place([]), resolveFlags(["dirty"], []));
  assert.equal(result.verdict, "unknown");
});

test("custom flags match on their own words", () => {
  const flags = resolveFlags(["nope"], ["laute Musik", " ", "laute Musik"]);
  assert.equal(flags.length, 1);
  const result = analyzeWithKeywords(place([
    {rating: 2, text: "Viel zu laute Musik, man versteht sich nicht.",
      when: ""},
  ]), flags);
  assert.equal(result.flags[0].status, "mentioned");
  assert.equal(result.flags[0].label, "laute Musik");
});

test("snippets are cut at word boundaries", () => {
  const text = "wort ".repeat(60) + "schimmel " + "wort ".repeat(60);
  const s = snippet(text, text.indexOf("schimmel"), 8);
  assert.ok(s.startsWith("…wort"));
  assert.ok(s.endsWith("wort…"));
  assert.ok(s.includes("schimmel"));
});

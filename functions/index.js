/**
 * Cloud Functions for Red Flag.
 *
 * - `nearbyRestaurants` lists the restaurants around the phone's position.
 * - `checkRestaurant` fetches one restaurant's Google reviews, reads them
 *   against the caller's red flags and stores the result under
 *   `users/{uid}/checks/{placeId}` so the app can show a history.
 *
 * Both are callable functions and need a signed-in user (the app signs in
 * anonymously), so the Places quota cannot be spent by anyone with the URL.
 *
 * Secrets (set once with `firebase functions:secrets:set NAME`):
 * - PLACES_API_KEY: a Google Maps Platform key with "Places API (New)" on.
 * - ANTHROPIC_API_KEY: for the Claude analysis. Set it to "none" to run on
 *   keyword matching only.
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

const {searchNearby, placeDetails} = require("./places");
const {resolveFlags} = require("./redFlags");
const {analyzeWithClaude, analyzeWithKeywords} = require("./analysis");

admin.initializeApp();

const PLACES_API_KEY = defineSecret("PLACES_API_KEY");
const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

const REGION = "europe-west6";

/** Search radius bounds in metres; the Places API allows up to 50 km. */
const MIN_RADIUS = 100;
const MAX_RADIUS = 5000;
const DEFAULT_RADIUS = 1500;

/**
 * Rejects calls from someone who is not signed in.
 *
 * @param {object} request A callable request.
 */
function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Bitte zuerst anmelden.");
  }
}

exports.nearbyRestaurants = onCall(
    {region: REGION, secrets: [PLACES_API_KEY]},
    async (request) => {
      requireAuth(request);
      const {lat, lng} = request.data ?? {};
      if (!Number.isFinite(lat) || !Number.isFinite(lng) ||
          Math.abs(lat) > 90 || Math.abs(lng) > 180) {
        throw new HttpsError("invalid-argument", "Ungültiger Standort.");
      }
      const radius = Math.min(MAX_RADIUS, Math.max(MIN_RADIUS,
          Number(request.data.radius) || DEFAULT_RADIUS));
      try {
        const restaurants = await searchNearby({
          lat, lng, radius, apiKey: PLACES_API_KEY.value(),
        });
        return {restaurants};
      } catch (error) {
        logger.error("nearbyRestaurants failed", error);
        throw new HttpsError("unavailable",
            "Restaurants konnten nicht geladen werden.");
      }
    });

exports.checkRestaurant = onCall(
    {
      region: REGION,
      secrets: [PLACES_API_KEY, ANTHROPIC_API_KEY],
      timeoutSeconds: 120,
    },
    async (request) => {
      requireAuth(request);
      const {placeId, redFlags, customFlags} = request.data ?? {};
      if (typeof placeId !== "string" || !/^[\w-]{10,300}$/.test(placeId)) {
        throw new HttpsError("invalid-argument", "Ungültiges Restaurant.");
      }
      const flags = resolveFlags(redFlags, customFlags);
      if (flags.length === 0) {
        throw new HttpsError("failed-precondition",
            "Wähle zuerst mindestens eine Red Flag.");
      }

      let place;
      try {
        place = await placeDetails({placeId, apiKey: PLACES_API_KEY.value()});
      } catch (error) {
        logger.error("placeDetails failed", error);
        throw new HttpsError("unavailable",
            "Bewertungen konnten nicht geladen werden.");
      }

      let result = null;
      const anthropicKey = ANTHROPIC_API_KEY.value();
      if (place.reviews.length > 0 && anthropicKey && anthropicKey !== "none") {
        try {
          result = await analyzeWithClaude(place, flags, anthropicKey);
        } catch (error) {
          logger.warn("Claude analysis failed, using keywords", error);
        }
      }
      result ??= analyzeWithKeywords(place, flags);

      const check = {
        placeId,
        name: place.name,
        address: place.address,
        rating: place.rating,
        ratingCount: place.ratingCount,
        mapsUrl: place.mapsUrl,
        reviewCount: place.reviews.length,
        ...result,
      };
      await admin.firestore()
          .doc(`users/${request.auth.uid}/checks/${placeId}`)
          .set({
            ...check,
            checkedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      return check;
    });

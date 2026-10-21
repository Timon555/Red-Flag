/**
 * The two Google Places API (New) calls Red Flag needs: restaurants around a
 * point, and one restaurant with its reviews.
 *
 * The API key lives here, on the server, and never in the app: a key shipped
 * inside an app can be pulled out of it and billed by anyone.
 *
 * Google returns at most five reviews per place ("most relevant" first). That
 * is a hard limit of the API, not of this code, and the app says so next to
 * every verdict.
 */

const PLACES_URL = "https://places.googleapis.com/v1";

/** What the list screen shows. Every extra field costs money per request. */
const NEARBY_FIELDS = [
  "places.id",
  "places.displayName",
  "places.formattedAddress",
  "places.location",
  "places.rating",
  "places.userRatingCount",
  "places.primaryTypeDisplayName",
  "places.currentOpeningHours.openNow",
].join(",");

const DETAIL_FIELDS = [
  "id",
  "displayName",
  "formattedAddress",
  "rating",
  "userRatingCount",
  "googleMapsUri",
  "reviews",
].join(",");

/**
 * Calls the Places API and turns a non-2xx answer into an Error carrying
 * Google's own message, which is the useful part when a key is misconfigured.
 *
 * @param {string} url
 * @param {string} apiKey
 * @param {string} fieldMask
 * @param {object} [body] POST body; GET when absent.
 * @return {Promise<any>}
 */
async function call(url, apiKey, fieldMask, body) {
  const response = await fetch(url, {
    method: body ? "POST" : "GET",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": apiKey,
      "X-Goog-FieldMask": fieldMask,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = json?.error?.message ?? response.statusText;
    throw new Error(`Places API ${response.status}: ${message}`);
  }
  return json;
}

/**
 * Restaurants within `radius` metres of a point, nearest first.
 *
 * @param {{lat: number, lng: number, radius: number, apiKey: string}} args
 * @return {Promise<object[]>}
 */
async function searchNearby({lat, lng, radius, apiKey}) {
  const json = await call(`${PLACES_URL}/places:searchNearby`, apiKey,
      NEARBY_FIELDS, {
        includedTypes: ["restaurant"],
        maxResultCount: 20,
        rankPreference: "DISTANCE",
        languageCode: "de",
        locationRestriction: {
          circle: {center: {latitude: lat, longitude: lng}, radius},
        },
      });
  return (json.places ?? []).map((place) => ({
    id: place.id,
    name: place.displayName?.text ?? "Unbekannt",
    address: place.formattedAddress ?? "",
    lat: place.location?.latitude ?? null,
    lng: place.location?.longitude ?? null,
    rating: place.rating ?? null,
    ratingCount: place.userRatingCount ?? 0,
    type: place.primaryTypeDisplayName?.text ?? null,
    openNow: place.currentOpeningHours?.openNow ?? null,
  }));
}

/**
 * One restaurant and its reviews. The review text is taken in the language it
 * was written in where Google has it, because a translation can soften exactly
 * the words we are looking for.
 *
 * @param {{placeId: string, apiKey: string}} args
 * @return {Promise<object>}
 */
async function placeDetails({placeId, apiKey}) {
  const url = `${PLACES_URL}/places/${encodeURIComponent(placeId)}` +
    "?languageCode=de";
  const place = await call(url, apiKey, DETAIL_FIELDS);
  return {
    id: place.id,
    name: place.displayName?.text ?? "Unbekannt",
    address: place.formattedAddress ?? "",
    rating: place.rating ?? null,
    ratingCount: place.userRatingCount ?? 0,
    mapsUrl: place.googleMapsUri ?? null,
    reviews: (place.reviews ?? []).map((review) => ({
      rating: review.rating ?? null,
      text: review.originalText?.text ?? review.text?.text ?? "",
      when: review.relativePublishTimeDescription ?? "",
      publishTime: review.publishTime ?? null,
      author: review.authorAttribution?.displayName ?? "",
    })).filter((review) => review.text),
  };
}

module.exports = {searchNearby, placeDetails};

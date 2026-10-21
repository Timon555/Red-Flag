import 'package:cloud_functions/cloud_functions.dart';

import '../models.dart';

/// Talks to the Cloud Functions in `functions/index.js`. They hold the Google
/// and Anthropic keys, so the app never does.
class ApiService {
  ApiService()
    : _functions = FirebaseFunctions.instanceFor(region: 'europe-west6');

  final FirebaseFunctions _functions;

  Future<List<Restaurant>> nearbyRestaurants({
    required double lat,
    required double lng,
    int radius = 1500,
  }) async {
    final result = await _functions
        .httpsCallable('nearbyRestaurants')
        .call<Map<String, dynamic>>({'lat': lat, 'lng': lng, 'radius': radius});
    final list = result.data['restaurants'] as List? ?? const [];
    return [
      for (final item in list)
        Restaurant.fromMap(Map<String, dynamic>.from(item as Map)),
    ];
  }

  Future<CheckResult> checkRestaurant({
    required String placeId,
    required List<String> redFlags,
    required List<String> customFlags,
  }) async {
    final result = await _functions
        .httpsCallable(
          'checkRestaurant',
          options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
        )
        .call<Map<String, dynamic>>({
          'placeId': placeId,
          'redFlags': redFlags,
          'customFlags': customFlags,
        });
    return CheckResult.fromMap(_deepMap(result.data));
  }

  /// Callable results arrive as `Map<Object?, Object?>` all the way down.
  static Map<String, dynamic> _deepMap(Map map) => {
    for (final entry in map.entries) entry.key.toString(): _deep(entry.value),
  };

  static Object? _deep(Object? value) {
    if (value is Map) return _deepMap(value);
    if (value is List) return [for (final v in value) _deep(v)];
    return value;
  }
}

/// A message for a failed call that makes sense to the user.
String describeError(Object error) {
  if (error is FirebaseFunctionsException) {
    return error.message ?? 'Etwas ist schiefgelaufen (${error.code}).';
  }
  return error.toString();
}

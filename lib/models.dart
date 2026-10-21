/// A restaurant from the nearby search.
class Restaurant {
  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    this.lat,
    this.lng,
    this.rating,
    this.ratingCount = 0,
    this.type,
    this.openNow,
    this.distanceMeters,
  });

  factory Restaurant.fromMap(Map<String, dynamic> map) => Restaurant(
    id: map['id'] as String,
    name: map['name'] as String? ?? 'Unbekannt',
    address: map['address'] as String? ?? '',
    lat: (map['lat'] as num?)?.toDouble(),
    lng: (map['lng'] as num?)?.toDouble(),
    rating: (map['rating'] as num?)?.toDouble(),
    ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
    type: map['type'] as String?,
    openNow: map['openNow'] as bool?,
  );

  final String id;
  final String name;
  final String address;
  final double? lat;
  final double? lng;
  final double? rating;
  final int ratingCount;
  final String? type;
  final bool? openNow;
  double? distanceMeters;
}

enum Verdict { ok, caution, avoid, unknown }

Verdict _verdict(Object? value) => Verdict.values.firstWhere(
  (v) => v.name == value,
  orElse: () => Verdict.unknown,
);

/// A quote from a review that backs up a finding.
class Evidence {
  Evidence({required this.quote, this.rating, this.when = ''});

  factory Evidence.fromMap(Map<String, dynamic> map) => Evidence(
    quote: map['quote'] as String? ?? '',
    rating: (map['rating'] as num?)?.toInt(),
    when: map['when'] as String? ?? '',
  );

  final String quote;
  final int? rating;
  final String when;
}

enum FlagStatus { clear, mentioned, serious }

/// What the check found for one of the user's red flags.
class FlagResult {
  FlagResult({
    required this.id,
    required this.label,
    required this.status,
    required this.note,
    required this.evidence,
  });

  factory FlagResult.fromMap(Map<String, dynamic> map) => FlagResult(
    id: map['id'] as String? ?? '',
    label: map['label'] as String? ?? '',
    status: FlagStatus.values.firstWhere(
      (s) => s.name == map['status'],
      orElse: () => FlagStatus.clear,
    ),
    note: map['note'] as String? ?? '',
    evidence: [
      for (final e in (map['evidence'] as List? ?? const []))
        Evidence.fromMap(Map<String, dynamic>.from(e as Map)),
    ],
  );

  final String id;
  final String label;
  final FlagStatus status;
  final String note;
  final List<Evidence> evidence;
}

/// The answer to "can I eat here?" for one restaurant.
class CheckResult {
  CheckResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.verdict,
    required this.summary,
    required this.engine,
    required this.flags,
    required this.reviewCount,
    this.rating,
    this.ratingCount = 0,
    this.mapsUrl,
    this.checkedAt,
  });

  factory CheckResult.fromMap(Map<String, dynamic> map) => CheckResult(
    placeId: map['placeId'] as String? ?? '',
    name: map['name'] as String? ?? '',
    address: map['address'] as String? ?? '',
    verdict: _verdict(map['verdict']),
    summary: map['summary'] as String? ?? '',
    engine: map['engine'] as String? ?? '',
    flags: [
      for (final f in (map['flags'] as List? ?? const []))
        FlagResult.fromMap(Map<String, dynamic>.from(f as Map)),
    ],
    reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
    rating: (map['rating'] as num?)?.toDouble(),
    ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
    mapsUrl: map['mapsUrl'] as String?,
    checkedAt: map['checkedAt'] is DateTime
        ? map['checkedAt'] as DateTime
        : null,
  );

  final String placeId;
  final String name;
  final String address;
  final Verdict verdict;
  final String summary;
  final String engine;
  final List<FlagResult> flags;
  final int reviewCount;
  final double? rating;
  final int ratingCount;
  final String? mapsUrl;
  final DateTime? checkedAt;
}

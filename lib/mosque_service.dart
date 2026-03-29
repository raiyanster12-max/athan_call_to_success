import 'dart:convert';

import 'package:http/http.dart' as http;

class MasjidResult {
  const MasjidResult({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
}

class MosqueLookupException implements Exception {
  const MosqueLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MosqueService {
  static const String _overpassUrl =
      'https://overpass-api.de/api/interpreter';

  /// Finds mosques and Islamic places of worship within [radiusMeters] of
  /// the given coordinates using the free OpenStreetMap Overpass API.
  Future<List<MasjidResult>> findNearbyMosques(
    double lat,
    double lng, {
    int radiusMeters = 5000,
  }) async {
    final query = '''
[out:json][timeout:25];
(
  node["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);
  way["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);
  relation["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);
);
out center;
''';

    final response = await http
        .post(
          Uri.parse(_overpassUrl),
          body: query,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw MosqueLookupException(
        'Overpass API returned status ${response.statusCode}.',
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>? ?? [];

    final results = <MasjidResult>[];
    for (final element in elements) {
      final tags = (element['tags'] as Map<String, dynamic>?) ?? {};
      final name = (tags['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;

      final double? lat2 = (element['lat'] as num?)?.toDouble() ??
          (element['center']?['lat'] as num?)?.toDouble();
      final double? lng2 = (element['lon'] as num?)?.toDouble() ??
          (element['center']?['lon'] as num?)?.toDouble();
      if (lat2 == null || lng2 == null) continue;

      final street = tags['addr:street'] as String? ?? '';
      final city = tags['addr:city'] as String? ?? '';
      final address =
          [street, city].where((s) => s.isNotEmpty).join(', ');

      results.add(MasjidResult(
        id: '${element['type']}_${element['id']}',
        name: name,
        address: address,
        lat: lat2,
        lng: lng2,
      ));
    }

    return results;
  }
}
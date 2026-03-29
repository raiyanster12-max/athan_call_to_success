import 'dart:convert';
import 'dart:math' as math;

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
  static const int _defaultRadiusMeters = 24140; // 15 miles
  static const String _userAgent =
      'athan_call_to_success/1.0 (contact: app-local)';
  static const List<String> _overpassUrls = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.openstreetmap.ru/api/interpreter',
  ];

  /// Finds mosques and Islamic places of worship within [radiusMeters] of
  /// the given coordinates using the free OpenStreetMap Overpass API.
  Future<List<MasjidResult>> findNearbyMosques(
    double lat,
    double lng, {
    int radiusMeters = _defaultRadiusMeters,
  }) async {
    final query = '''
[out:json][timeout:25];
(
  node["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);
  way["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);
  relation["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);
  node["amenity"="mosque"](around:$radiusMeters,$lat,$lng);
  way["amenity"="mosque"](around:$radiusMeters,$lat,$lng);
  relation["amenity"="mosque"](around:$radiusMeters,$lat,$lng);
  node["building"="mosque"](around:$radiusMeters,$lat,$lng);
  way["building"="mosque"](around:$radiusMeters,$lat,$lng);
  relation["building"="mosque"](around:$radiusMeters,$lat,$lng);
  node["amenity"="place_of_worship"]["name"~"(?i)(masjid|mosque|islamic|muslim)"](around:$radiusMeters,$lat,$lng);
  way["amenity"="place_of_worship"]["name"~"(?i)(masjid|mosque|islamic|muslim)"](around:$radiusMeters,$lat,$lng);
  relation["amenity"="place_of_worship"]["name"~"(?i)(masjid|mosque|islamic|muslim)"](around:$radiusMeters,$lat,$lng);
);
out center;
''';

    Object? lastFailure;
    final overpassResults = <MasjidResult>[];
    for (final baseUrl in _overpassUrls) {
      try {
        final response = await http
            .post(
              Uri.parse(baseUrl),
              headers: {
                'User-Agent': _userAgent,
                'Content-Type': 'text/plain; charset=utf-8',
              },
              body: query,
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode != 200) {
          if (response.statusCode >= 500 ||
              response.statusCode == 429 ||
              response.statusCode == 504) {
            lastFailure = MosqueLookupException(
              'Overpass API returned status ${response.statusCode}.',
            );
            continue;
          }
          throw MosqueLookupException(
            'Overpass API returned status ${response.statusCode}.',
          );
        }

        final data = json.decode(response.body) as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>? ?? [];
        overpassResults.addAll(_parseOverpassElements(elements));
        if (overpassResults.isNotEmpty) {
          break;
        }
      } catch (e) {
        lastFailure = e;
      }
    }

    final fallbackResults = await _fetchFromNominatim(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
    );

    final merged = _mergeAndSortByDistance(
      lat: lat,
      lng: lng,
      lists: [overpassResults, fallbackResults],
    );
    if (merged.isNotEmpty) {
      return merged;
    }

    throw MosqueLookupException(
      'Unable to load nearby masjids right now. '
      'Please retry in a moment. Details: $lastFailure',
    );
  }

  List<MasjidResult> _parseOverpassElements(List<dynamic> elements) {
    final results = <MasjidResult>[];
    final seenIds = <String>{};

    for (final element in elements) {
      final tags = (element['tags'] as Map<String, dynamic>?) ?? {};
      final name = ((tags['name:en'] as String?) ?? (tags['name'] as String?))
          ?.trim();
      if (name == null || name.isEmpty) continue;

      final double? lat2 = (element['lat'] as num?)?.toDouble() ??
          (element['center']?['lat'] as num?)?.toDouble();
      final double? lng2 = (element['lon'] as num?)?.toDouble() ??
          (element['center']?['lon'] as num?)?.toDouble();
      if (lat2 == null || lng2 == null) continue;

      final street = tags['addr:street'] as String? ?? '';
      final city = tags['addr:city'] as String? ?? '';
      final fallbackAddress = tags['addr:full'] as String? ?? '';
      final address = [street, city, fallbackAddress]
          .where((s) => s.isNotEmpty)
          .join(', ');

      final id = '${element['type']}_${element['id']}';
      if (!seenIds.add(id)) continue;

      results.add(
        MasjidResult(
          id: id,
          name: name,
          address: address,
          lat: lat2,
          lng: lng2,
        ),
      );
    }

    return results;
  }

  Future<List<MasjidResult>> _fetchFromNominatim({
    required double lat,
    required double lng,
    required int radiusMeters,
  }) async {
    final latDelta = radiusMeters / 111320.0;
    final cosLat = math.cos(lat * math.pi / 180).abs().clamp(0.1, 1.0);
    final lngDelta = radiusMeters / (111320.0 * cosLat);

    final left = (lng - lngDelta).toStringAsFixed(6);
    final right = (lng + lngDelta).toStringAsFixed(6);
    final top = (lat + latDelta).toStringAsFixed(6);
    final bottom = (lat - latDelta).toStringAsFixed(6);

    final queries = ['masjid', 'mosque', 'islamic center'];
    final results = <MasjidResult>[];

    for (final q in queries) {
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'format': 'jsonv2',
          'q': q,
          'bounded': '1',
          'limit': '50',
          'addressdetails': '1',
          'viewbox': '$left,$top,$right,$bottom',
        });

        final response = await http.get(uri, headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 8));

        if (response.statusCode != 200) {
          continue;
        }

        final data = json.decode(response.body) as List<dynamic>;
        for (final item in data) {
          final map = item as Map<String, dynamic>;
          final latText = map['lat'] as String?;
          final lonText = map['lon'] as String?;
          final lat2 = double.tryParse(latText ?? '');
          final lng2 = double.tryParse(lonText ?? '');
          if (lat2 == null || lng2 == null) continue;

          final name =
              (map['name'] as String?)?.trim().isNotEmpty == true
                  ? (map['name'] as String).trim()
                  : ((map['display_name'] as String?) ?? '').split(',').first.trim();
          if (name.isEmpty) continue;

          final distance = _distanceMeters(lat, lng, lat2, lng2);
          if (distance > radiusMeters * 1.15) {
            continue;
          }

          final id = 'nominatim_${map['osm_type']}_${map['osm_id']}';
          results.add(
            MasjidResult(
              id: id,
              name: name,
              address: (map['display_name'] as String?) ?? '',
              lat: lat2,
              lng: lng2,
            ),
          );
        }
      } catch (_) {
        // Ignore individual fallback failures and continue.
      }
    }

    return results;
  }

  List<MasjidResult> _mergeAndSortByDistance({
    required double lat,
    required double lng,
    required List<List<MasjidResult>> lists,
  }) {
    final merged = <MasjidResult>[];
    final seen = <String>{};

    for (final list in lists) {
      for (final item in list) {
        final key = '${item.name.toLowerCase()}_${item.lat.toStringAsFixed(4)}_${item.lng.toStringAsFixed(4)}';
        if (!seen.add(key)) continue;
        merged.add(item);
      }
    }

    merged.sort((a, b) {
      final da = _distanceMeters(lat, lng, a.lat, a.lng);
      final db = _distanceMeters(lat, lng, b.lat, b.lng);
      return da.compareTo(db);
    });
    return merged;
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final rLat1 = lat1 * math.pi / 180.0;
    final rLat2 = lat2 * math.pi / 180.0;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) *
            math.cos(rLat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
}
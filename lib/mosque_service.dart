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
  static const int _defaultRadiusMeters = 8047; // 5 miles
  // NOTE: no (?i) prefix — Overpass uses ,i flag on the filter instead
  static const String _nameRegex =
      'masjid|mosque|islamic|muslim|musalla|mushalla|masjed|jami|jamia|jame|al-masjid|jumah|jumuah|prayer hall|salah center|islamic center|islamic centre|icna|isna|msa |al islam|noor|nur|ummah|deen|tabligh|foundation|islamic society|muslim association|muslim community|islamic foundation|muslim foundation|muslim federation|baitul|dar ul|darul|ijtima';
  static const String _userAgent =
      'athan_call_to_success/1.0 (contact: app-local)';
  static const List<String> _geocodeFallbackHosts = [
    'nominatim.openstreetmap.org',
    'geocode.maps.co',
  ];
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
    String? zipcode,
  }) async {
    // Query uses nwr shorthand (node+way+relation in one) to keep clause count
    // low and avoid Overpass timeouts.
    final query = '''
[out:json][timeout:45];
(
  nwr["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);
  nwr["amenity"="mosque"](around:$radiusMeters,$lat,$lng);
  nwr["amenity"="prayer_hall"](around:$radiusMeters,$lat,$lng);
  nwr["building"="mosque"](around:$radiusMeters,$lat,$lng);
  nwr["amenity"="community_centre"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);
  nwr["office"="religious"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);
  nwr["name"~"$_nameRegex",i]["amenity"](around:$radiusMeters,$lat,$lng);
  nwr["name"~"$_nameRegex",i]["building"](around:$radiusMeters,$lat,$lng);
  nwr["name"~"$_nameRegex",i]["office"](around:$radiusMeters,$lat,$lng);
  nwr["amenity"="community_centre"]["name"~"$_nameRegex",i](around:$radiusMeters,$lat,$lng);
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
            .timeout(const Duration(seconds: 55));

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
      zipcode: zipcode,
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

      // Prefer English name, then any Latin-script variant, then Arabic/Urdu, then place type
      final name = ((tags['name:en'] as String?) ??
              (tags['name'] as String?) ??
              (tags['name:ar'] as String?) ??
              (tags['name:ur'] as String?) ??
              (tags['name:tr'] as String?) ??
              (tags['alt_name'] as String?) ??
              _inferPlaceName(tags))
          ?.trim();
      if (name == null || name.isEmpty) continue;

      final double? lat2 =
          (element['lat'] as num?)?.toDouble() ??
          (element['center']?['lat'] as num?)?.toDouble();
      final double? lng2 =
          (element['lon'] as num?)?.toDouble() ??
          (element['center']?['lon'] as num?)?.toDouble();
      if (lat2 == null || lng2 == null) continue;

      final street = tags['addr:street'] as String? ?? '';
      final city = tags['addr:city'] as String? ?? '';
      final fallbackAddress = tags['addr:full'] as String? ?? '';
      final address = [
        street,
        city,
        fallbackAddress,
      ].where((s) => s.isNotEmpty).join(', ');

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

  /// Returns a human-readable placeholder name when no explicit name tag is set.
  String? _inferPlaceName(Map<String, dynamic> tags) {
    final amenity = tags['amenity'] as String?;
    final building = tags['building'] as String?;
    final religion = tags['religion'] as String?;
    final denomination = tags['denomination'] as String?;
    if (amenity == 'mosque' || building == 'mosque') return 'Masjid';
    if (amenity == 'prayer_hall') return 'Prayer Hall';
    if (religion == 'muslim') {
      if (denomination != null && denomination.isNotEmpty) {
        return '${denomination[0].toUpperCase()}${denomination.substring(1)} Masjid';
      }
      return 'Islamic Place of Worship';
    }
    return null;
  }

  Future<List<MasjidResult>> _fetchFromNominatim({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? zipcode,
  }) async {
    final latDelta = radiusMeters / 111320.0;
    final cosLat = math.cos(lat * math.pi / 180).abs().clamp(0.1, 1.0);
    final lngDelta = radiusMeters / (111320.0 * cosLat);

    final left = (lng - lngDelta).toStringAsFixed(6);
    final right = (lng + lngDelta).toStringAsFixed(6);
    final top = (lat + latDelta).toStringAsFixed(6);
    final bottom = (lat - latDelta).toStringAsFixed(6);

    // Keep fallback broad enough to avoid showing only one center when
    // Overpass is unavailable on a device/network.
    final queries = [
      'masjid',
      'mosque',
      'islamic center',
      'islamic centre',
      'islamic society',
      'muslim center',
      'muslim community center',
      'muslim association',
      'musalla',
      'prayer hall',
    ];
    final results = <MasjidResult>[];

    for (final q in queries) {
      final attempts = <Map<String, String>>[
        {
          'format': 'jsonv2',
          'q': q,
          'bounded': '1',
          'limit': '100',
          'addressdetails': '1',
          'extratags': '1',
          'viewbox': '$left,$top,$right,$bottom',
        },
        {
          'format': 'jsonv2',
          'q': q,
          'limit': '60',
          'addressdetails': '1',
          'extratags': '1',
        },
      ];

      if (zipcode != null && zipcode.trim().isNotEmpty) {
        attempts.addAll([
          {
            'format': 'jsonv2',
            'q': '$q $zipcode',
            'bounded': '1',
            'limit': '40',
            'addressdetails': '1',
            'extratags': '1',
            'viewbox': '$left,$top,$right,$bottom',
          },
          {
            'format': 'jsonv2',
            'q': '$q $zipcode',
            'limit': '60',
            'addressdetails': '1',
            'extratags': '1',
          },
        ]);
      }

      for (final params in attempts) {
        for (final host in _geocodeFallbackHosts) {
          try {
            final uri = Uri.https(host, '/search', params);

            final response = await http
                .get(
                  uri,
                  headers: {
                    'User-Agent': _userAgent,
                    'Accept': 'application/json',
                  },
                )
                .timeout(const Duration(seconds: 8));

            if (response.statusCode == 429) {
              continue;
            }

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

              final name = (map['name'] as String?)?.trim().isNotEmpty == true
                  ? (map['name'] as String).trim()
                  : ((map['display_name'] as String?) ?? '')
                        .split(',')
                        .first
                        .trim();
              if (name.isEmpty) continue;

              final distance = _distanceMeters(lat, lng, lat2, lng2);
              if (distance > radiusMeters * 1.75) {
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

            // Use first successful host response for this attempt.
            break;
          } catch (_) {
            // Ignore individual fallback failures and continue.
          }
        }
      }

      // Stop early once we have enough nearby options.
      if (results.length >= 30) break;
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
        final key =
            '${item.name.toLowerCase()}_${item.lat.toStringAsFixed(4)}_${item.lng.toStringAsFixed(4)}';
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

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) *
            math.cos(rLat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Geocodes a zip code, city name, or free-text location query to (lat, lng).
  /// Falls back to [geocodeZipcode] for 5-digit US zip codes.
  Future<({double lat, double lng})> geocodeQuery(String query) async {
    final q = query.trim();
    if (RegExp(r'^\d{5}(-\d{4})?$').hasMatch(q)) {
      return geocodeZipcode(q);
    }
    try {
      return _geocodeFromHosts({'q': q, 'addressdetails': '1'});
    } on MosqueLookupException {
      rethrow;
    } catch (e) {
      throw MosqueLookupException('Failed to find location: $e');
    }
  }

  /// Geocodes a US zip code to (lat, lng) using the Nominatim API.
  /// Throws [MosqueLookupException] if the zip code cannot be resolved.
  Future<({double lat, double lng})> geocodeZipcode(String zipcode) async {
    try {
      final clean = zipcode.trim();

      // US-focused attempt first.
      try {
        return _geocodeFromHosts({
          'postalcode': clean,
          'countrycodes': 'us',
        });
      } on MosqueLookupException {
        // Fall through to global postal lookup.
      }

      // Global fallback for non-US postal codes.
      return _geocodeFromHosts({'q': clean, 'addressdetails': '1'});
    } on MosqueLookupException {
      rethrow;
    } catch (e) {
      throw MosqueLookupException(
        'Failed to look up zip code: ${e.toString()}',
      );
    }
  }

  Future<({double lat, double lng})> _geocodeFromHosts(
    Map<String, String> params,
  ) async {
    Object? lastFailure;

    for (final host in _geocodeFallbackHosts) {
      final query = <String, String>{
        'format': 'jsonv2',
        'limit': '1',
        ...params,
      };

      final uri = Uri.https(host, '/search', query);
      try {
        final response = await http
            .get(
              uri,
              headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 429) {
          lastFailure = MosqueLookupException(
            'Location service is rate-limited right now.',
          );
          continue;
        }
        if (response.statusCode != 200) {
          lastFailure = MosqueLookupException(
            'Could not find location (HTTP ${response.statusCode}).',
          );
          continue;
        }

        final data = json.decode(response.body) as List<dynamic>;
        if (data.isEmpty) {
          lastFailure = const MosqueLookupException('Location was not found.');
          continue;
        }

        final item = data.first as Map<String, dynamic>;
        final lat = double.tryParse('${item['lat']}');
        final lng = double.tryParse('${item['lon']}');
        if (lat == null || lng == null) {
          lastFailure = const MosqueLookupException(
            'Location response had invalid coordinates.',
          );
          continue;
        }

        return (lat: lat, lng: lng);
      } catch (e) {
        lastFailure = e;
      }
    }

    throw MosqueLookupException('Failed to find location: $lastFailure');
  }
}

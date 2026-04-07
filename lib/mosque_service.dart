import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// A single mosque entry returned by OSM/Nominatim search.
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

/// Thrown when the OSM/Nominatim mosque lookup fails.
class MosqueLookupException implements Exception {
  const MosqueLookupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A single mosque entry returned by the Mawaqit API.
class MosqueSummary {
  const MosqueSummary({
    required this.uuid,
    required this.name,
    this.localName,
    this.lat,
    this.lng,
    this.address,
    this.city,
    this.country,
    this.slug,
  });

  final String uuid;
  final String name;
  final String? localName;
  final double? lat;
  final double? lng;
  final String? address;
  final String? city;
  final String? country;
  final String? slug;

  /// Display name prefers localName when populated.
  String get displayName =>
      (localName != null && localName!.isNotEmpty) ? localName! : name;

  /// One-line address combining address + city.
  String get fullAddress {
    final parts = [address, city].where((s) => s != null && s.isNotEmpty);
    return parts.join(', ');
  }

  factory MosqueSummary.fromJson(Map<String, dynamic> json) {
    return MosqueSummary(
      uuid: json['uuid'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Mosque',
      localName: json['localName'] as String?,
      lat: (json['latitude'] as num?)?.toDouble(),
      lng: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      slug: json['slug'] as String?,
    );
  }
}

/// Thrown when the Mawaqit API returns 401/403 (bad or expired credentials).
class MawaqitAuthException implements Exception {
  const MawaqitAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lightweight Dart wrapper around the Mawaqit REST API.
///
/// API base: https://mawaqit.net/api
///   Login      POST /2.0/me        (Basic Auth → { apiAccessToken })
///   Search     GET  /2.0/mosque/search?lat=X&lon=X  (Authorization: <token>)
///   By keyword GET  /2.0/mosque/search?word=X        (Authorization: <token>)
class MosqueService {
  static const String _apiBase = 'https://mawaqit.net/api';

  // ── Authentication ────────────────────────────────────────────────────────

  /// Login with a mawaqit.net account and return the API access token.
  static Future<String> login(String email, String password) async {
    final uri = Uri.parse('$_apiBase/2.0/me');
    final credentials = base64.encode(utf8.encode('$email:$password'));

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Basic $credentials',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) {
      throw const MawaqitAuthException(
        'Invalid Mawaqit credentials. Please check your email and password.',
      );
    }
    if (response.statusCode != 200) {
      throw Exception('Mawaqit login failed (HTTP ${response.statusCode}).');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final token = data['apiAccessToken'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('No API token received from Mawaqit login response.');
    }
    return token;
  }

  // ── Mosque search ─────────────────────────────────────────────────────────

  /// Return mosques near [lat]/[lon] using the cached API [token].
  static Future<List<MosqueSummary>> searchNearby(
    String token,
    double lat,
    double lon,
  ) async {
    return _search(token, {'lat': lat.toString(), 'lon': lon.toString()});
  }

  /// Return mosques matching [keyword] using the cached API [token].
  static Future<List<MosqueSummary>> searchByKeyword(
    String token,
    String keyword,
  ) async {
    return _search(token, {'word': keyword});
  }

  // ── Prayer times calendar ─────────────────────────────────────────────────

  /// Fetch the full yearly prayer-times calendar for [mosqueUuid].
  ///
  /// Endpoint: GET /2.0/mosque/{uuid}/prayer-times
  /// Header:   Api-Access-Token: <token>
  ///
  /// Returns a [MawaqitCalendarData] whose [prayerTimesForDate] method
  /// yields the 5 obligatory prayer DateTimes for any day in the year.
  static Future<MawaqitCalendarData> fetchPrayerCalendar(
    String token,
    String mosqueUuid,
  ) async {
    final uri = Uri.parse('$_apiBase/2.0/mosque/$mosqueUuid/prayer-times');

    final response = await http.get(
      uri,
      headers: {
        'Api-Access-Token': token,
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const MawaqitAuthException(
        'Mawaqit session expired or invalid. Please sign in again.',
      );
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Mawaqit prayer times fetch failed (HTTP ${response.statusCode}).',
      );
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    return MawaqitCalendarData.fromJson(mosqueUuid, body);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static Future<List<MosqueSummary>> _search(
    String token,
    Map<String, String> params,
  ) async {
    final uri = Uri.parse(
      '$_apiBase/2.0/mosque/search',
    ).replace(queryParameters: params);

    final response = await http.get(
      uri,
      headers: {
        'Authorization': token,
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const MawaqitAuthException(
        'Mawaqit session expired or invalid. Please sign in again.',
      );
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Mosque search failed (HTTP ${response.statusCode}).',
      );
    }

    final body = json.decode(response.body);
    if (body is! List) return [];

    return body
        .whereType<Map<String, dynamic>>()
        .map(MosqueSummary.fromJson)
        .where((m) => m.uuid.isNotEmpty && m.lat != null && m.lng != null)
        .toList();
  }

  // ── OSM / Nominatim instance API (used by MasjidPage) ────────────────────

  static const int _defaultRadiusMeters = 8047; // 5 miles
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

  Future<List<MasjidResult>> findNearbyMosques(
    double lat,
    double lng, {
    int radiusMeters = _defaultRadiusMeters,
    String? zipcode,
  }) async {
    final futures = await Future.wait([
      _fetchFromOverpass(lat, lng, radiusMeters),
      _fetchFromNominatim(
        lat: lat,
        lng: lng,
        radiusMeters: radiusMeters,
        zipcode: zipcode,
      ),
    ], eagerError: false);

    final merged = _mergeAndSortByDistance(lat: lat, lng: lng, lists: futures);
    if (merged.isNotEmpty) return merged;

    throw const MosqueLookupException(
      'Unable to load nearby masjids right now. Please retry in a moment.',
    );
  }

  Future<({double lat, double lng})> geocodeQuery(String query) async {
    final q = query.trim();
    if (RegExp(r'^\d{5}(-\d{4})?$').hasMatch(q)) {
      return _geocodeFromHosts({'postalcode': q, 'countrycodes': 'us'});
    }
    try {
      return _geocodeFromHosts({'q': q, 'addressdetails': '1'});
    } on MosqueLookupException {
      rethrow;
    } catch (e) {
      throw MosqueLookupException('Failed to find location: $e');
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
            .get(uri, headers: {'User-Agent': _userAgent, 'Accept': 'application/json'})
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 429) {
          lastFailure = const MosqueLookupException('Location service is rate-limited.');
          continue;
        }
        if (response.statusCode != 200) {
          lastFailure = MosqueLookupException('Could not find location (HTTP ${response.statusCode}).');
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
          lastFailure = const MosqueLookupException('Location response had invalid coordinates.');
          continue;
        }
        return (lat: lat, lng: lng);
      } catch (e) {
        lastFailure = e;
      }
    }
    throw MosqueLookupException('Failed to find location: $lastFailure');
  }

  Future<List<MasjidResult>> _fetchFromOverpass(
    double lat,
    double lng,
    int radiusMeters,
  ) async {
    final query = '''
[out:json][timeout:18];
(
  nwr["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);
  nwr["amenity"="mosque"](around:$radiusMeters,$lat,$lng);
  nwr["amenity"="prayer_hall"](around:$radiusMeters,$lat,$lng);
  nwr["building"="mosque"](around:$radiusMeters,$lat,$lng);
  nwr["name"~"$_nameRegex",i]["amenity"](around:$radiusMeters,$lat,$lng);
  nwr["name"~"$_nameRegex",i]["building"](around:$radiusMeters,$lat,$lng);
);
out center;
''';
    for (final baseUrl in _overpassUrls) {
      try {
        final response = await http
            .post(
              Uri.parse(baseUrl),
              headers: {'User-Agent': _userAgent, 'Content-Type': 'text/plain; charset=utf-8'},
              body: query,
            )
            .timeout(const Duration(seconds: 22));
        if (response.statusCode != 200) {
          if (response.statusCode >= 500 || response.statusCode == 429 || response.statusCode == 504) {
            continue;
          }
          break;
        }
        final data = json.decode(response.body) as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>? ?? [];
        final results = _parseOverpassElements(elements);
        if (results.isNotEmpty) return results;
      } catch (_) {
        // Try next server
      }
    }
    return const [];
  }

  List<MasjidResult> _parseOverpassElements(List<dynamic> elements) {
    final results = <MasjidResult>[];
    final seenIds = <String>{};
    for (final element in elements) {
      final tags = (element['tags'] as Map<String, dynamic>?) ?? {};
      final name = ((tags['name:en'] as String?) ??
              (tags['name'] as String?) ??
              (tags['name:ar'] as String?) ??
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
      final fallback = tags['addr:full'] as String? ?? '';
      final address = [street, city, fallback].where((s) => s.isNotEmpty).join(', ');
      final id = '${element['type']}_${element['id']}';
      if (!seenIds.add(id)) continue;
      results.add(MasjidResult(id: id, name: name, address: address, lat: lat2, lng: lng2));
    }
    return results;
  }

  String? _inferPlaceName(Map<String, dynamic> tags) {
    final amenity = tags['amenity'] as String?;
    final building = tags['building'] as String?;
    final religion = tags['religion'] as String?;
    if (amenity == 'mosque' || building == 'mosque') return 'Masjid';
    if (amenity == 'prayer_hall') return 'Prayer Hall';
    if (religion == 'muslim') return 'Islamic Place of Worship';
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
    final queries = ['masjid', 'mosque', 'islamic center'];
    if (zipcode != null && zipcode.trim().isNotEmpty) queries.add('masjid $zipcode');
    final results = <MasjidResult>[];
    for (final q in queries) {
      final params = <String, String>{
        'format': 'jsonv2',
        'q': q,
        'bounded': '1',
        'limit': '50',
        'addressdetails': '1',
        'viewbox': '$left,$top,$right,$bottom',
      };
      for (final host in _geocodeFallbackHosts) {
        try {
          final uri = Uri.https(host, '/search', params);
          final response = await http
              .get(uri, headers: {'User-Agent': _userAgent, 'Accept': 'application/json'})
              .timeout(const Duration(seconds: 5));
          if (response.statusCode != 200) continue;
          final data = json.decode(response.body) as List<dynamic>;
          for (final item in data) {
            final map = item as Map<String, dynamic>;
            final lat2 = double.tryParse(map['lat'] as String? ?? '');
            final lng2 = double.tryParse(map['lon'] as String? ?? '');
            if (lat2 == null || lng2 == null) continue;
            final name = (map['name'] as String?)?.trim().isNotEmpty == true
                ? (map['name'] as String).trim()
                : ((map['display_name'] as String?) ?? '').split(',').first.trim();
            if (name.isEmpty) continue;
            if (_distanceMeters(lat, lng, lat2, lng2) > radiusMeters * 1.5) continue;
            final id = 'nominatim_${map['osm_type']}_${map['osm_id']}';
            results.add(MasjidResult(id: id, name: name, address: (map['display_name'] as String?) ?? '', lat: lat2, lng: lng2));
          }
          break;
        } catch (_) {
          continue;
        }
      }
      if (results.length >= 20) break;
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
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) * math.cos(rLat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mawaqit calendar data model
// ─────────────────────────────────────────────────────────────────────────────

/// The 5 obligatory prayer times for a single date, sourced from a mosque's
/// Mawaqit calendar (adhan times, not iqama).
class MawaqitDayPrayers {
  const MawaqitDayPrayers({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  final DateTime fajr;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  /// Returns prayers in canonical order: Fajr, Dhuhr, Asr, Maghrib, Isha.
  List<MapEntry<String, DateTime>> get asList => [
    MapEntry('Fajr', fajr),
    MapEntry('Dhuhr', dhuhr),
    MapEntry('Asr', asr),
    MapEntry('Maghrib', maghrib),
    MapEntry('Isha', isha),
  ];
}

/// Full yearly calendar returned by `GET /2.0/mosque/{uuid}/prayer-times`.
///
/// Calendar structure from Mawaqit:
///   calendar[monthIndex (0-based)][dayString ("1"–"31")] =
///       ["HH:MM", "HH:MM", "HH:MM", "HH:MM", "HH:MM", "HH:MM"]
///   Order: Fajr (0), Shurouq (1, skip), Dhuhr (2), Asr (3), Maghrib (4), Isha (5)
class MawaqitCalendarData {
  const MawaqitCalendarData({
    required this.mosqueUuid,
    required this.label,
    required this.calendar,
  });

  final String mosqueUuid;
  final String label;

  // calendar[0..11][dayKey] = [Fajr, Shurouq, Dhuhr, Asr, Maghrib, Isha]
  final List<Map<String, List<String>>> calendar;

  factory MawaqitCalendarData.fromJson(
    String mosqueUuid,
    Map<String, dynamic> json,
  ) {
    final raw = json['calendar'] as List<dynamic>? ?? [];
    final cal = raw.map<Map<String, List<String>>>((month) {
      if (month is! Map) return {};
      return (month as Map<String, dynamic>).map((day, times) {
        final timesList = (times as List<dynamic>)
            .map((t) => t?.toString() ?? '00:00')
            .toList();
        return MapEntry(day, timesList);
      });
    }).toList();

    return MawaqitCalendarData(
      mosqueUuid: mosqueUuid,
      label: json['label'] as String? ?? json['name'] as String? ?? '',
      calendar: cal,
    );
  }

  /// Returns the 5 obligatory prayer times as [DateTime] objects for [date],
  /// or null if [date] is outside this calendar's available range.
  MawaqitDayPrayers? prayerTimesForDate(DateTime date) {
    final monthIndex = date.month - 1;
    final dayKey = date.day.toString();

    if (monthIndex < 0 || monthIndex >= calendar.length) return null;
    final monthData = calendar[monthIndex];
    final times = monthData[dayKey];
    if (times == null || times.length < 6) return null;

    DateTime parse(int index) {
      final raw = times[index];
      final parts = raw.split(':');
      final h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      return DateTime(date.year, date.month, date.day, h, m);
    }

    return MawaqitDayPrayers(
      fajr: parse(0),
      // index 1 is Shurouq — skip
      dhuhr: parse(2),
      asr: parse(3),
      maghrib: parse(4),
      isha: parse(5),
    );
  }
}

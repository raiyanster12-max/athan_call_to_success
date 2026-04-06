import 'dart:convert';

import 'package:http/http.dart' as http;

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

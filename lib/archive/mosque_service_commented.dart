// import 'dart:convert';
// import 'dart:math' as math;
// 
// import 'package:http/http.dart' as http;
// 
// class MasjidResult {
//   const MasjidResult({
//     required this.id,
//     required this.name,
//     required this.address,
//     required this.lat,
//     required this.lng,
//   });
// 
//   final String id;
//   final String name;
//   final String address;
//   final double lat;
//   final double lng;
// }
// 
// class MosqueLookupException implements Exception {
//   const MosqueLookupException(this.message);
// 
//   final String message;
// 
//   @override
//   String toString() => message;
// }
// 
// class MosqueService {
//   static const int _defaultRadiusMeters = 8047; // 5 miles
//   // NOTE: no (?i) prefix — Overpass uses ,i flag on the filter instead
//   static const String _nameRegex =
//       'masjid|mosque|islamic|muslim|musalla|mushalla|masjed|jami|jamia|jame|al-masjid|jumah|jumuah|prayer hall|salah center|islamic center|islamic centre|icna|isna|msa |al islam|noor|nur|ummah|deen|tabligh|foundation|islamic society|muslim association|muslim community|islamic foundation|muslim foundation|muslim federation|baitul|dar ul|darul|ijtima';
//   static const String _userAgent =
//       'athan_call_to_success/1.0 (contact: app-local)';
//   static const List<String> _geocodeFallbackHosts = [
//     'nominatim.openstreetmap.org',
//     'geocode.maps.co',
//   ];
//   static const List<String> _overpassUrls = [
//     'https://overpass-api.de/api/interpreter',
//     'https://overpass.kumi.systems/api/interpreter',
//     'https://overpass.openstreetmap.ru/api/interpreter',
//   ];
// 
//   /// Set your Google Places API key here to enable Places-based mosque search.
//   /// Leave empty to rely only on the free OpenStreetMap sources.
//   static const String _googlePlacesApiKey = '';
// 
//   /// Finds mosques and Islamic places of worship within [radiusMeters] of
//   /// the given coordinates. Runs Overpass and Nominatim in parallel.
//   Future<List<MasjidResult>> findNearbyMosques(
//     double lat,
//     double lng, {
//     int radiusMeters = _defaultRadiusMeters,
//     String? zipcode,
//   }) async {
//     final futures = await Future.wait([
//       _fetchFromOverpass(lat, lng, radiusMeters),
//       _fetchFromNominatim(
//         lat: lat,
//         lng: lng,
//         radiusMeters: radiusMeters,
//         zipcode: zipcode,
//       ),
//       _fetchFromGooglePlaces(lat, lng, radiusMeters),
//     ], eagerError: false);
// 
//     final merged = _mergeAndSortByDistance(
//       lat: lat,
//       lng: lng,
//       lists: futures,
//     );
//     if (merged.isNotEmpty) {
//       return merged;
//     }
// 
//     throw const MosqueLookupException(
//       'Unable to load nearby masjids right now. Please retry in a moment.',
//     );
//   }
// 
//   /// Google Places Nearby Search — returns results if [_googlePlacesApiKey]
//   /// is configured, otherwise returns an empty list immediately.
//   Future<List<MasjidResult>> _fetchFromGooglePlaces(
//     double lat,
//     double lng,
//     int radiusMeters,
//   ) async {
//     if (_googlePlacesApiKey.isEmpty) return const [];
// 
//     final uri = Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', {
//       'location': '$lat,$lng',
//       'radius': '$radiusMeters',
//       'type': 'mosque',
//       'keyword': 'masjid mosque islamic center',
//       'key': _googlePlacesApiKey,
//     });
// 
//     try {
//       final response = await http
//           .get(uri, headers: {'User-Agent': _userAgent})
//           .timeout(const Duration(seconds: 10));
// 
//       if (response.statusCode != 200) return const [];
// 
//       final data = json.decode(response.body) as Map<String, dynamic>;
//       if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') return const [];
// 
//       final results = data['results'] as List<dynamic>? ?? [];
//       return results.map((r) {
//         final map = r as Map<String, dynamic>;
//         final loc = (map['geometry'] as Map<String, dynamic>)['location'] as Map<String, dynamic>;
//         return MasjidResult(
//           id: 'places_${map['place_id']}',
//           name: map['name'] as String? ?? 'Unknown Masjid',
//           address: map['vicinity'] as String? ?? '',
//           lat: (loc['lat'] as num).toDouble(),
//           lng: (loc['lng'] as num).toDouble(),
//         );
//       }).toList();
//     } catch (_) {
//       return const [];
//     }
//   }
// 
//   Future<List<MasjidResult>> _fetchFromOverpass(
//     double lat,
//     double lng,
//     int radiusMeters,
//   ) async {
//     final query = '''
// [out:json][timeout:18];
// (
//   nwr["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);
//   nwr["amenity"="mosque"](around:$radiusMeters,$lat,$lng);
//   nwr["amenity"="prayer_hall"](around:$radiusMeters,$lat,$lng);
//   nwr["building"="mosque"](around:$radiusMeters,$lat,$lng);
//   nwr["amenity"="community_centre"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);
//   nwr["office"="religious"]["religion"="muslim"](around:$radiusMeters,$lat,$lng);
//   nwr["name"~"$_nameRegex",i]["amenity"](around:$radiusMeters,$lat,$lng);
//   nwr["name"~"$_nameRegex",i]["building"](around:$radiusMeters,$lat,$lng);
//   nwr["name"~"$_nameRegex",i]["office"](around:$radiusMeters,$lat,$lng);
//   nwr["amenity"="community_centre"]["name"~"$_nameRegex",i](around:$radiusMeters,$lat,$lng);
// );
// out center;
// ''';
// 
//     for (final baseUrl in _overpassUrls) {
//       try {
//         final response = await http
//             .post(
//               Uri.parse(baseUrl),
//               headers: {
//                 'User-Agent': _userAgent,
//                 'Content-Type': 'text/plain; charset=utf-8',
//               },
//               body: query,
//             )
//             .timeout(const Duration(seconds: 22));
// 
//         if (response.statusCode != 200) {
//           if (response.statusCode >= 500 ||
//               response.statusCode == 429 ||
//               response.statusCode == 504) {
//             continue;
//           }
//           break;
//         }
// 
//         final data = json.decode(response.body) as Map<String, dynamic>;
//         final elements = data['elements'] as List<dynamic>? ?? [];
//         final results = _parseOverpassElements(elements);
//         if (results.isNotEmpty) return results;
//       } catch (_) {
//         // Try next server
//       }
//     }
//     return const [];
//   }
// 
//   List<MasjidResult> _parseOverpassElements(List<dynamic> elements) {
//     final results = <MasjidResult>[];
//     final seenIds = <String>{};
// 
//     for (final element in elements) {
//       final tags = (element['tags'] as Map<String, dynamic>?) ?? {};
// 
//       // Prefer English name, then any Latin-script variant, then Arabic/Urdu, then place type
//       final name = ((tags['name:en'] as String?) ??
//               (tags['name'] as String?) ??
//               (tags['name:ar'] as String?) ??
//               (tags['name:ur'] as String?) ??
//               (tags['name:tr'] as String?) ??
//               (tags['alt_name'] as String?) ??
//               _inferPlaceName(tags))
//           ?.trim();
//       if (name == null || name.isEmpty) continue;
// 
//       final double? lat2 =
//           (element['lat'] as num?)?.toDouble() ??
//           (element['center']?['lat'] as num?)?.toDouble();
//       final double? lng2 =
//           (element['lon'] as num?)?.toDouble() ??
//           (element['center']?['lon'] as num?)?.toDouble();
//       if (lat2 == null || lng2 == null) continue;
// 
//       final street = tags['addr:street'] as String? ?? '';
//       final city = tags['addr:city'] as String? ?? '';
//       final fallbackAddress = tags['addr:full'] as String? ?? '';
//       final address = [
//         street,
//         city,
//         fallbackAddress,
//       ].where((s) => s.isNotEmpty).join(', ');
// 
//       final id = '${element['type']}_${element['id']}';
//       if (!seenIds.add(id)) continue;
// 
//       results.add(
//         MasjidResult(
//           id: id,
//           name: name,
//           address: address,
//           lat: lat2,
//           lng: lng2,
//         ),
//       );
//     }
// 
//     return results;
//   }
// 
//   /// Returns a human-readable placeholder name when no explicit name tag is set.
//   String? _inferPlaceName(Map<String, dynamic> tags) {
//     final amenity = tags['amenity'] as String?;
//     final building = tags['building'] as String?;
//     final religion = tags['religion'] as String?;
//     final denomination = tags['denomination'] as String?;
//     if (amenity == 'mosque' || building == 'mosque') return 'Masjid';
//     if (amenity == 'prayer_hall') return 'Prayer Hall';
//     if (religion == 'muslim') {
//       if (denomination != null && denomination.isNotEmpty) {
//         return '${denomination[0].toUpperCase()}${denomination.substring(1)} Masjid';
//       }
//       return 'Islamic Place of Worship';
//     }
//     return null;
//   }
// 
//   Future<List<MasjidResult>> _fetchFromNominatim({
//     required double lat,
//     required double lng,
//     required int radiusMeters,
//     String? zipcode,
//   }) async {
//     final latDelta = radiusMeters / 111320.0;
//     final cosLat = math.cos(lat * math.pi / 180).abs().clamp(0.1, 1.0);
//     final lngDelta = radiusMeters / (111320.0 * cosLat);
// 
//     final left = (lng - lngDelta).toStringAsFixed(6);
//     final right = (lng + lngDelta).toStringAsFixed(6);
//     final top = (lat + latDelta).toStringAsFixed(6);
//     final bottom = (lat - latDelta).toStringAsFixed(6);
// 
//     // Focused query list — only the most common terms to keep latency low.
//     final queries = [
//       'masjid',
//       'mosque',
//       'islamic center',
//     ];
//     if (zipcode != null && zipcode.trim().isNotEmpty) {
//       queries.add('masjid $zipcode');
//     }
//     final results = <MasjidResult>[];
// 
//     for (final q in queries) {
//       final params = <String, String>{
//         'format': 'jsonv2',
//         'q': q,
//         'bounded': '1',
//         'limit': '50',
//         'addressdetails': '1',
//         'viewbox': '$left,$top,$right,$bottom',
//       };
// 
//       for (final host in _geocodeFallbackHosts) {
//         try {
//           final uri = Uri.https(host, '/search', params);
//           final response = await http
//               .get(
//                 uri,
//                 headers: {
//                   'User-Agent': _userAgent,
//                   'Accept': 'application/json',
//                 },
//               )
//               .timeout(const Duration(seconds: 5));
// 
//           if (response.statusCode != 200) continue;
// 
//           final data = json.decode(response.body) as List<dynamic>;
//           for (final item in data) {
//             final map = item as Map<String, dynamic>;
//             final lat2 = double.tryParse(map['lat'] as String? ?? '');
//             final lng2 = double.tryParse(map['lon'] as String? ?? '');
//             if (lat2 == null || lng2 == null) continue;
// 
//             final name = (map['name'] as String?)?.trim().isNotEmpty == true
//                 ? (map['name'] as String).trim()
//                 : ((map['display_name'] as String?) ?? '')
//                       .split(',')
//                       .first
//                       .trim();
//             if (name.isEmpty) continue;
// 
//             if (_distanceMeters(lat, lng, lat2, lng2) > radiusMeters * 1.5) {
//               continue;
//             }
// 
//             final id = 'nominatim_${map['osm_type']}_${map['osm_id']}';
//             results.add(
//               MasjidResult(
//                 id: id,
//                 name: name,
//                 address: (map['display_name'] as String?) ?? '',
//                 lat: lat2,
//                 lng: lng2,
//               ),
//             );
//           }
//           // First responding host wins for this query.
//           break;
//         } catch (_) {
//           continue;
//         }
//       }
// 
//       if (results.length >= 20) break;
//     }
// 
//     return results;
//   }
// 
//   List<MasjidResult> _mergeAndSortByDistance({
//     required double lat,
//     required double lng,
//     required List<List<MasjidResult>> lists,
//   }) {
//     final merged = <MasjidResult>[];
//     final seen = <String>{};
// 
//     for (final list in lists) {
//       for (final item in list) {
//         final key =
//             '${item.name.toLowerCase()}_${item.lat.toStringAsFixed(4)}_${item.lng.toStringAsFixed(4)}';
//         if (!seen.add(key)) continue;
//         merged.add(item);
//       }
//     }
// 
//     merged.sort((a, b) {
//       final da = _distanceMeters(lat, lng, a.lat, a.lng);
//       final db = _distanceMeters(lat, lng, b.lat, b.lng);
//       return da.compareTo(db);
//     });
//     return merged;
//   }
// 
//   double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
//     const earthRadius = 6371000.0;
//     final dLat = (lat2 - lat1) * math.pi / 180.0;
//     final dLon = (lon2 - lon1) * math.pi / 180.0;
//     final rLat1 = lat1 * math.pi / 180.0;
//     final rLat2 = lat2 * math.pi / 180.0;
// 
//     final a =
//         math.sin(dLat / 2) * math.sin(dLat / 2) +
//         math.cos(rLat1) *
//             math.cos(rLat2) *
//             math.sin(dLon / 2) *
//             math.sin(dLon / 2);
//     final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
//     return earthRadius * c;
//   }
// 
//   /// Geocodes a zip code, city name, or free-text location query to (lat, lng).
//   /// Falls back to [geocodeZipcode] for 5-digit US zip codes.
//   Future<({double lat, double lng})> geocodeQuery(String query) async {
//     final q = query.trim();
//     if (RegExp(r'^\d{5}(-\d{4})?$').hasMatch(q)) {
//       return geocodeZipcode(q);
//     }
//     try {
//       return _geocodeFromHosts({'q': q, 'addressdetails': '1'});
//     } on MosqueLookupException {
//       rethrow;
//     } catch (e) {
//       throw MosqueLookupException('Failed to find location: $e');
//     }
//   }
// 
//   /// Geocodes a US zip code to (lat, lng) using the Nominatim API.
//   /// Throws [MosqueLookupException] if the zip code cannot be resolved.
//   Future<({double lat, double lng})> geocodeZipcode(String zipcode) async {
//     try {
//       final clean = zipcode.trim();
// 
//       // US-focused attempt first.
//       try {
//         return _geocodeFromHosts({
//           'postalcode': clean,
//           'countrycodes': 'us',
//         });
//       } on MosqueLookupException {
//         // Fall through to global postal lookup.
//       }
// 
//       // Global fallback for non-US postal codes.
//       return _geocodeFromHosts({'q': clean, 'addressdetails': '1'});
//     } on MosqueLookupException {
//       rethrow;
//     } catch (e) {
//       throw MosqueLookupException(
//         'Failed to look up zip code: ${e.toString()}',
//       );
//     }
//   }
// 
//   Future<({double lat, double lng})> _geocodeFromHosts(
//     Map<String, String> params,
//   ) async {
//     Object? lastFailure;
// 
//     for (final host in _geocodeFallbackHosts) {
//       final query = <String, String>{
//         'format': 'jsonv2',
//         'limit': '1',
//         ...params,
//       };
// 
//       final uri = Uri.https(host, '/search', query);
//       try {
//         final response = await http
//             .get(
//               uri,
//               headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
//             )
//             .timeout(const Duration(seconds: 10));
// 
//         if (response.statusCode == 429) {
//           lastFailure = MosqueLookupException(
//             'Location service is rate-limited right now.',
//           );
//           continue;
//         }
//         if (response.statusCode != 200) {
//           lastFailure = MosqueLookupException(
//             'Could not find location (HTTP ${response.statusCode}).',
//           );
//           continue;
//         }
// 
//         final data = json.decode(response.body) as List<dynamic>;
//         if (data.isEmpty) {
//           lastFailure = const MosqueLookupException('Location was not found.');
//           continue;
//         }
// 
//         final item = data.first as Map<String, dynamic>;
//         final lat = double.tryParse('${item['lat']}');
//         final lng = double.tryParse('${item['lon']}');
//         if (lat == null || lng == null) {
//           lastFailure = const MosqueLookupException(
//             'Location response had invalid coordinates.',
//           );
//           continue;
//         }
// 
//         return (lat: lat, lng: lng);
//       } catch (e) {
//         lastFailure = e;
//       }
//     }
// 
//     throw MosqueLookupException('Failed to find location: $lastFailure');
//   }
// }

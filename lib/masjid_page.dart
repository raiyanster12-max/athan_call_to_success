import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hijri_date/hijri.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_palette.dart';
import 'db_helper.dart';
import 'mosque_service.dart';
import 'prayer_service.dart';

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

class _PrayerEntry {
  const _PrayerEntry({
    required this.name,
    required this.adhanTime,
    required this.iqamahOffset,
  });

  final String name;
  final DateTime adhanTime;
  final int iqamahOffset; // minutes after adhan
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class MasjidPage extends StatefulWidget {
  const MasjidPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<MasjidPage> createState() => _MasjidPageState();
}

enum _MasjidView { home, results, map }

class _MasjidPageState extends State<MasjidPage> {
  static const int _searchRadiusMeters = 16093; // 10 miles
  static const String _kMawaqitToken = 'mawaqit_token';
  static const String _kMawaqitMosqueUuid = 'mawaqit_selected_mosque_uuid';
  static const String _kMawaqitMosqueName = 'mawaqit_selected_mosque_name';

  static const List<String> _hijriMonths = [
    'Muharram',
    'Safar',
    "Rabi' al-Awwal",
    "Rabi' al-Akhir",
    'Jumada al-Ula',
    'Jumada al-Akhira',
    'Rajab',
    "Sha'ban",
    'Ramadan',
    'Shawwal',
    "Dhu al-Qi'dah",
    'Dhu al-Hijjah',
  ];

  final TextEditingController _locationController = TextEditingController();
  final MosqueService _mosqueService = MosqueService();

  _MasjidView _view = _MasjidView.home;
  List<MasjidResult> _results = const [];
  bool _isLoading = false;
  String? _error;
  String _resultsTitle = '';

  // Map state
  final Completer<GoogleMapController> _mapController = Completer();
  double? _userLat;
  double? _userLng;
  Set<Marker> _markers = {};
  LatLng? _mapCenter;

  // My Masjid state
  Map<String, dynamic>? _pinnedMasjid;
  Map<String, dynamic> _iqamahSettings = const {};
  bool _isLoadingPinned = true;
  bool _isMawaqitBusy = false;
  String? _selectedMawaqitMosqueName;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _loadPinnedMasjid();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _locationController.dispose();
    if (_mapController.isCompleted) {
      _mapController.future.then((c) => c.dispose());
    }
    super.dispose();
  }

  // -- DB helpers -------------------------------------------------------------

  Future<void> _loadPinnedMasjid() async {
    final masjid = await DBHelper.getPinnedMasjid();
    final iqamah = await DBHelper.getIqamahSettings();
    final mawaqitMosqueName = await DBHelper.getSetting(_kMawaqitMosqueName);
    if (!mounted) return;
    setState(() {
      _pinnedMasjid = masjid;
      _iqamahSettings = iqamah;
      _selectedMawaqitMosqueName = mawaqitMosqueName;
      _isLoadingPinned = false;
    });
  }

  Future<void> _setPinnedMasjid(MasjidResult item) async {
    await DBHelper.setPinnedMasjid(
      id: item.id,
      name: item.name,
      address: item.address,
      lat: item.lat,
      lng: item.lng,
    );
    await _loadPinnedMasjid();
    if (mounted) _goHome();
  }

  // -- Navigation -------------------------------------------------------------

  void _goHome() {
    setState(() {
      _view = _MasjidView.home;
      _results = const [];
      _error = null;
      _mapCenter = null;
      _markers.clear();
    });
  }

  // -- Search -----------------------------------------------------------------

  Future<List<MasjidResult>> _findNearbyWithExpandedRadius(
    double lat,
    double lng, {
    String? zipcode,
  }) async {
    final token = await DBHelper.getSetting(_kMawaqitToken);
    return _mosqueService.findNearbyMosques(
      lat,
      lng,
      radiusMeters: _searchRadiusMeters,
      zipcode: zipcode,
      mawaqitToken: token,
    );
  }

  Future<Position> _getCurrentPositionForSearch() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw Exception('Location permission denied.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  Future<Map<String, String>?> _promptMawaqitCredentials() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppPalette.surfaceRaised,
        title: const Text(
          'Mawaqit Sign In',
          style: TextStyle(color: AppPalette.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(color: AppPalette.textPrimary),
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              style: const TextStyle(color: AppPalette.textPrimary),
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Used only to request a Mawaqit API token on-device.',
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final email = emailController.text.trim();
              final password = passwordController.text;
              if (email.isEmpty || password.isEmpty) {
                return;
              }
              Navigator.of(
                dialogContext,
              ).pop({'email': email, 'password': password});
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );

    emailController.dispose();
    passwordController.dispose();
    return result;
  }

  String _mawaqitAddress(MosqueSummary mosque) {
    if (mosque.fullAddress.trim().isNotEmpty) {
      return mosque.fullAddress.trim();
    }
    final city = mosque.city?.trim();
    final country = mosque.country?.trim();
    return [city, country].where((v) => v != null && v.isNotEmpty).join(', ');
  }

  Future<void> _signInAndFindNearestMawaqitMasjid() async {
    if (_isMawaqitBusy) return;

    final credentials = await _promptMawaqitCredentials();
    if (credentials == null) return;

    setState(() {
      _isMawaqitBusy = true;
      _isLoading = true;
      _error = null;
      _resultsTitle = 'Mawaqit Nearby';
      _view = _MasjidView.results;
    });

    try {
      final position = await _getCurrentPositionForSearch();
      final token = await MosqueService.login(
        credentials['email']!,
        credentials['password']!,
      );

      final nearby = await MosqueService.searchNearby(
        token,
        position.latitude,
        position.longitude,
      );

      if (nearby.isEmpty) {
        if (!mounted) return;
        setState(() {
          _results = const [];
          _markers = {};
          _error = 'No nearby mosques found from Mawaqit.';
        });
        return;
      }

      nearby.sort((a, b) {
        final da = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          a.lat ?? position.latitude,
          a.lng ?? position.longitude,
        );
        final db = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          b.lat ?? position.latitude,
          b.lng ?? position.longitude,
        );
        return da.compareTo(db);
      });

      final mapped = nearby
          .map(
            (m) => MasjidResult(
              id: 'mawaqit_${m.uuid}',
              name: m.displayName,
              address: _mawaqitAddress(m),
              lat: m.lat!,
              lng: m.lng!,
            ),
          )
          .toList(growable: false);

      final markers = <Marker>{
        for (final item in mapped)
          Marker(
            markerId: MarkerId(item.id),
            position: LatLng(item.lat, item.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: item.name,
              snippet: item.address,
              onTap: () => _showMasjidDetailsFromMarker(item),
            ),
          ),
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(title: 'My Location'),
        ),
      };

      final nearest = nearby.first;
      await DBHelper.setSetting(_kMawaqitToken, token);
      await DBHelper.setSetting(_kMawaqitMosqueUuid, nearest.uuid);
      await DBHelper.setSetting(_kMawaqitMosqueName, nearest.displayName);

      await DBHelper.setPinnedMasjid(
        id: 'mawaqit_${nearest.uuid}',
        name: nearest.displayName,
        address: _mawaqitAddress(nearest),
        lat: nearest.lat!,
        lng: nearest.lng!,
      );

      if (!mounted) return;
      setState(() {
        _results = mapped;
        _markers = markers;
        _userLat = position.latitude;
        _userLng = position.longitude;
        _mapCenter = LatLng(position.latitude, position.longitude);
        _selectedMawaqitMosqueName = nearest.displayName;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Signed in to Mawaqit. Nearest mosque selected: ${nearest.displayName}',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } on MawaqitAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _error = e.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _error = 'Mawaqit login/search failed: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isMawaqitBusy = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _searchNearYou() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _resultsTitle = 'Near You';
      _view = _MasjidView.results;
    });

    try {
      final position = await _getCurrentPositionForSearch();

      if (!mounted) return;

      final items = await _findNearbyWithExpandedRadius(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      // Build markers from results
      final markers = <Marker>{};
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        markers.add(
          Marker(
            markerId: MarkerId(item.id),
            position: LatLng(item.lat, item.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: item.name,
              snippet: item.address,
              onTap: () => _showMasjidDetailsFromMarker(item),
            ),
          ),
        );
      }
      // User location marker
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(title: 'My Location'),
        ),
      );

      setState(() {
        _results = items;
        _markers = markers;
        _userLat = position.latitude;
        _userLng = position.longitude;
        _mapCenter = LatLng(position.latitude, position.longitude);
        if (items.isEmpty) {
          _error = 'No nearby masjids found.';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchByLocation() async {
    final input = _locationController.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _resultsTitle = input;
      _view = _MasjidView.results;
    });

    try {
      final coords = await _mosqueService.geocodeQuery(input);
      final radiusMeters = (_searchRadiusMiles * 1609.34).toInt();
      final token = await DBHelper.getSetting(_kMawaqitToken);

      final items = await _mosqueService.findNearbyMosques(
        coords.lat,
        coords.lng,
        radiusMeters: radiusMeters,
        zipcode: input,
        mawaqitToken: token,
      );

      if (!mounted) return;

      // Build markers from results
      final markers = <Marker>{};
      for (final item in items) {
        markers.add(
          Marker(
            markerId: MarkerId(item.id),
            position: LatLng(item.lat, item.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: item.name,
              snippet: item.address,
              onTap: () => _showMasjidDetailsFromMarker(item),
            ),
          ),
        );
      }

      setState(() {
        _results = items;
        _markers = markers;
        _mapCenter = LatLng(coords.lat, coords.lng);
        if (items.isEmpty) {
          _error = 'No nearby masjids found. Try a different zip or city.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = const [];
          _error = '$e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -- Map and Navigation helpers ---------------------------------------------

  void _showMasjidDetailsFromMarker(MasjidResult item) {
    _showMasjidDetailsDialog(item);
  }

  Future<void> _openInGoogleMaps(double lat, double lng, String name) async {
    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$name';
    final mapsAppUrl =
        'comgooglemaps://?center=$lat,$lng&zoom=15&views=traffic';

    try {
      if (await canLaunchUrl(Uri.parse(mapsAppUrl))) {
        await launchUrl(Uri.parse(mapsAppUrl));
      } else if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(
          Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Google Maps.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddMosqueDialog() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surfaceRaised,
        title: const Text(
          'Add New Mosque',
          style: TextStyle(color: AppPalette.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppPalette.textPrimary),
              decoration: InputDecoration(
                hintText: 'Mosque Name',
                hintStyle: const TextStyle(color: AppPalette.textMuted),
                filled: true,
                fillColor: AppPalette.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              style: const TextStyle(color: AppPalette.textPrimary),
              decoration: InputDecoration(
                hintText: 'Address',
                hintStyle: const TextStyle(color: AppPalette.textMuted),
                filled: true,
                fillColor: AppPalette.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            const Text(
              'Currently using pinned location coordinates.',
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppPalette.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.accent),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final address = addressCtrl.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter mosque name.')),
                );
                return;
              }

              // Save to local favorites (community input)
              if (_pinnedMasjid != null) {
                await DBHelper.insertMasjid({
                  'id': 'community_${DateTime.now().millisecondsSinceEpoch}',
                  'name': name,
                  'address': address,
                  'lat': _pinnedMasjid!['lat'] as double,
                  'lng': _pinnedMasjid!['lng'] as double,
                });
              }

              if (mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Mosque added! Thank you for your contribution.',
                    ),
                  ),
                );
              }

              nameCtrl.dispose();
              addressCtrl.dispose();
            },
            child: const Text('Submit', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showMasjidDetailsDialog(MasjidResult item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surfaceRaised,
        title: Text(
          item.name,
          style: const TextStyle(color: AppPalette.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.address.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  item.address,
                  style: const TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            Text(
              'Coordinates: ${item.lat.toStringAsFixed(4)}, ${item.lng.toStringAsFixed(4)}',
              style: const TextStyle(color: AppPalette.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: AppPalette.textSecondary),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.accent),
            onPressed: () {
              Navigator.of(ctx).pop();
              _openInGoogleMaps(item.lat, item.lng, item.name);
            },
            icon: const Icon(Icons.directions, size: 16),
            label: const Text(
              'Directions',
              style: TextStyle(color: Colors.black),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.accent),
            onPressed: () {
              Navigator.of(ctx).pop();
              _setPinnedMasjid(item);
            },
            icon: const Icon(Icons.star, size: 16),
            label: const Text('Pin It', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // -- Dialogs / sheets -------------------------------------------------------

  int _searchRadiusMiles = 10;

  void _showSearchDialog() {
    _locationController.clear();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppPalette.surfaceRaised,
          title: const Text(
            'Search Masjid',
            style: TextStyle(color: AppPalette.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _locationController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: AppPalette.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Zip code or city name',
                  hintStyle: const TextStyle(color: AppPalette.textMuted),
                  filled: true,
                  fillColor: AppPalette.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: (_) {
                  Navigator.of(ctx).pop();
                  _searchByLocation();
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text(
                    'Radius:',
                    style: TextStyle(color: AppPalette.textSecondary),
                  ),
                  Expanded(
                    child: Slider(
                      value: _searchRadiusMiles.toDouble(),
                      min: 5,
                      max: 50,
                      divisions: 9,
                      activeColor: AppPalette.accent,
                      label: '$_searchRadiusMiles miles',
                      onChanged: (val) {
                        setDialogState(() => _searchRadiusMiles = val.toInt());
                      },
                    ),
                  ),
                  Text(
                    '$_searchRadiusMiles mi',
                    style: const TextStyle(color: AppPalette.textPrimary),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppPalette.textSecondary),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppPalette.accent),
              onPressed: () {
                Navigator.of(ctx).pop();
                _searchByLocation();
              },
              child: const Text('Search', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  void _showMasjidOptionsSheet(MasjidResult item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  item.name,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (item.address.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    item.address,
                    style: const TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const Divider(color: AppPalette.outline),
              ListTile(
                leading: const Icon(Icons.star, color: AppPalette.accent),
                title: const Text(
                  'Set as My Masjid',
                  style: TextStyle(color: AppPalette.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setPinnedMasjid(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.directions, color: AppPalette.accent),
                title: const Text(
                  'Open in Google Maps',
                  style: TextStyle(color: AppPalette.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openInGoogleMaps(item.lat, item.lng, item.name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add, color: AppPalette.accent),
                title: const Text(
                  'View Details',
                  style: TextStyle(color: AppPalette.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showMasjidDetailsDialog(item);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.close,
                  color: AppPalette.textSecondary,
                ),
                title: const Text(
                  'Cancel',
                  style: TextStyle(color: AppPalette.textSecondary),
                ),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIqamahEditSheet() {
    final fajr = ValueNotifier<int>(_iqamahSettings['fajr'] as int? ?? 30);
    final dhuhr = ValueNotifier<int>(_iqamahSettings['dhuhr'] as int? ?? 15);
    final asr = ValueNotifier<int>(_iqamahSettings['asr'] as int? ?? 15);
    final maghrib = ValueNotifier<int>(
      _iqamahSettings['maghrib'] as int? ?? 10,
    );
    final isha = ValueNotifier<int>(_iqamahSettings['isha'] as int? ?? 15);
    final jumaa1Ctrl = TextEditingController(
      text: _iqamahSettings['jumaa1'] as String? ?? '13:45',
    );
    final jumaa2Ctrl = TextEditingController(
      text: _iqamahSettings['jumaa2'] as String? ?? '15:15',
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surfaceRaised,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Iqamah Offsets (minutes)',
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                for (final (label, notifier) in [
                  ('Fajr', fajr),
                  ('Dhuhr', dhuhr),
                  ('Asr', asr),
                  ('Maghrib', maghrib),
                  ('Isha', isha),
                ])
                  _OffsetRow(label: label, notifier: notifier),
                const SizedBox(height: 12),
                const Text(
                  "Jum'a Times",
                  style: TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _JumaaField(
                        label: "1st Jum'a",
                        controller: jumaa1Ctrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _JumaaField(
                        label: "2nd Jum'a",
                        controller: jumaa2Ctrl,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.accent,
                    ),
                    onPressed: () async {
                      final settings = {
                        'fajr': fajr.value,
                        'dhuhr': dhuhr.value,
                        'asr': asr.value,
                        'maghrib': maghrib.value,
                        'isha': isha.value,
                        'jumaa1': jumaa1Ctrl.text.trim(),
                        'jumaa2': jumaa2Ctrl.text.trim(),
                      };
                      await DBHelper.setIqamahSettings(settings);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      await _loadPinnedMasjid();
                    },
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      fajr.dispose();
      dhuhr.dispose();
      asr.dispose();
      maghrib.dispose();
      isha.dispose();
      jumaa1Ctrl.dispose();
      jumaa2Ctrl.dispose();
    });
  }

  // -- Helpers ----------------------------------------------------------------

  String _formatCountdown(Duration d) {
    if (d.isNegative) return '00:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$m:$s' : '$m:$s';
  }

  String _hijriDateLabel(DateTime date) {
    final h = HijriDate.fromDate(date);
    final monthName = (h.hMonth >= 1 && h.hMonth <= 12)
        ? _hijriMonths[h.hMonth - 1]
        : '';
    return '${h.hDay} $monthName ${h.hYear}';
  }

  // -- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final hasPinned = _pinnedMasjid != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _view == _MasjidView.results || _view == _MasjidView.map
              ? _resultsTitle
              : (hasPinned
                    ? (_pinnedMasjid!['name'] as String)
                    : 'Masjid Finder'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _view == _MasjidView.results || _view == _MasjidView.map
              ? _goHome
              : (widget.onBack ?? () => Navigator.of(context).maybePop()),
        ),
        actions: (_view == _MasjidView.home && hasPinned)
            ? [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add mosque',
                  onPressed: _showAddMosqueDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_calendar_outlined),
                  tooltip: 'Edit iqamah times',
                  onPressed: _showIqamahEditSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Change masjid',
                  onPressed: _showSearchDialog,
                ),
              ]
            : null,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: _view == _MasjidView.map
            ? _buildMapView()
            : _view == _MasjidView.results
            ? _buildResults()
            : _isLoadingPinned
            ? const Center(
                child: CircularProgressIndicator(color: AppPalette.accent),
              )
            : hasPinned
            ? _buildMyMasjidView()
            : _buildHome(),
      ),
    );
  }

  // -- My Masjid view ---------------------------------------------------------

  Widget _buildMyMasjidView() {
    final masjid = _pinnedMasjid!;
    final lat = masjid['lat'] as double;
    final lng = masjid['lng'] as double;

    final times = PrayerService.getTimesForDate(lat, lng, _now);
    final next = PrayerService.getNextPrayer(lat, lng, now: _now);

    final fajrOff = _iqamahSettings['fajr'] as int? ?? 30;
    final dhuhrOff = _iqamahSettings['dhuhr'] as int? ?? 15;
    final asrOff = _iqamahSettings['asr'] as int? ?? 15;
    final maghribOff = _iqamahSettings['maghrib'] as int? ?? 10;
    final ishaOff = _iqamahSettings['isha'] as int? ?? 15;
    final jumaa1 = _iqamahSettings['jumaa1'] as String? ?? '13:45';
    final jumaa2 = _iqamahSettings['jumaa2'] as String? ?? '15:15';

    final fmt = DateFormat('HH:mm');

    final prayers = [
      _PrayerEntry(name: 'Fajr', adhanTime: times.fajr, iqamahOffset: fajrOff),
      _PrayerEntry(
        name: 'Dhuhr',
        adhanTime: times.dhuhr,
        iqamahOffset: dhuhrOff,
      ),
      _PrayerEntry(name: 'Asr', adhanTime: times.asr, iqamahOffset: asrOff),
      _PrayerEntry(
        name: 'Maghrib',
        adhanTime: times.maghrib,
        iqamahOffset: maghribOff,
      ),
      _PrayerEntry(name: 'Isha', adhanTime: times.isha, iqamahOffset: ishaOff),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              // Keep the Mawaqit-style discovery flow accessible even when
              // a masjid is already pinned.
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Masjid Finder',
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Search and switch to another masjid anytime.',
                      style: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _searchNearYou,
                          icon: const Icon(Icons.my_location, size: 16),
                          label: const Text('Near You'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _showSearchDialog,
                          icon: const Icon(Icons.search, size: 16),
                          label: const Text('By Location'),
                        ),
                        /*
                        FilledButton.icon(
                          onPressed: _isMawaqitBusy
                              ? null
                              : _signInAndFindNearestMawaqitMasjid,
                          icon: const Icon(Icons.login, size: 16),
                          label: Text(
                            _isMawaqitBusy
                                ? 'Signing In...'
                                : 'Mawaqit Sign In',
                          ),
                        ),
                        */
                      ],
                    ),
                    if ((_selectedMawaqitMosqueName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Selected Mawaqit mosque: $_selectedMawaqitMosqueName',
                        style: const TextStyle(
                          color: AppPalette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Prayer list card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppPalette.surfaceRaised,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppPalette.outline),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < prayers.length; i++)
                      _buildPrayerTile(
                        prayers[i],
                        next.name,
                        fmt,
                        isLast: i == prayers.length - 1,
                      ),
                  ],
                ),
              ),

              // Sunrise + Jum'a info row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wb_sunny_outlined,
                          color: AppPalette.textMuted,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sunrise  ${fmt.format(times.sunrise)}',
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (jumaa1.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.mosque,
                            color: AppPalette.textMuted,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Jum'a  $jumaa1${jumaa2.isNotEmpty ? '  |  $jumaa2' : ''}",
                            style: const TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Clear pinned button
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton.icon(
                  icon: const Icon(
                    Icons.clear,
                    size: 15,
                    color: AppPalette.textMuted,
                  ),
                  label: const Text(
                    'Clear pinned masjid',
                    style: TextStyle(color: AppPalette.textMuted, fontSize: 12),
                  ),
                  onPressed: () async {
                    await DBHelper.clearPinnedMasjid();
                    await _loadPinnedMasjid();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerTile(
    _PrayerEntry prayer,
    String nextPrayerName,
    DateFormat fmt, {
    required bool isLast,
  }) {
    final isNext = prayer.name == nextPrayerName;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isNext ? AppPalette.accent.withAlpha(38) : null,
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppPalette.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 108,
              child: Text(
                prayer.name,
                style: TextStyle(
                  color: isNext ? AppPalette.accent : AppPalette.textSecondary,
                  fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    fmt.format(prayer.adhanTime),
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
                      fontSize: isNext ? 26 : 22,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '+${prayer.iqamahOffset}',
                    style: TextStyle(
                      color: isNext
                          ? AppPalette.accentSoft
                          : AppPalette.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Home (no pinned masjid) ------------------------------------------------

  Widget _buildHome() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.outline),
            ),
            child: const Row(
              children: [
                Icon(Icons.mosque, color: AppPalette.textMuted, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No local masjid set. Search below and tap a result to pin it as My Masjid.',
                    style: TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(16),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            children: [
              _GridTile(
                icon: Icons.my_location,
                label: 'NEAR YOU',
                onTap: _searchNearYou,
              ),
              _GridTile(
                icon: Icons.search,
                label: 'BY LOCATION',
                onTap: _showSearchDialog,
              ),
            /*
              _GridTile(
                icon: Icons.login,
                label: _isMawaqitBusy ? 'SIGNING IN' : 'MAWAQIT LOGIN',
                onTap: _isMawaqitBusy
                    ? () {}
                    : _signInAndFindNearestMawaqitMasjid,
              ),
            */
            ],
          ),
        ),
      ],
    );
  }

  // -- Results list -----------------------------------------------------------

  Widget _buildMapView() {
    if (_mapCenter == null) {
      return const Center(
        child: Text(
          'Map not available',
          style: TextStyle(color: AppPalette.textSecondary),
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) {
            if (!_mapController.isCompleted) {
              _mapController.complete(controller);
            }
          },
          initialCameraPosition: CameraPosition(target: _mapCenter!, zoom: 14),
          markers: _markers,
          mapType: MapType.normal,
          compassEnabled: true,
          myLocationEnabled: _userLat != null && _userLng != null,
          myLocationButtonEnabled: false, // replaced by custom FAB
          zoomControlsEnabled: false,
        ),
        // Top info bar
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: AppPalette.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${_results.length} masjids found',
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.list, color: AppPalette.accent),
                  onPressed: () => setState(() => _view = _MasjidView.results),
                  tooltip: 'List view',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppPalette.textMuted),
                  onPressed: _goHome,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
        ),
        // FAB: re-center map on user location with camera animation
        if (_userLat != null && _userLng != null)
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: AppPalette.accent,
              onPressed: () async {
                final controller = await _mapController.future;
                await controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(_userLat!, _userLng!),
                      zoom: 15,
                    ),
                  ),
                );
              },
              child: const Icon(Icons.my_location_sharp, color: Colors.black),
            ),
          ),
      ],
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppPalette.accent),
            SizedBox(height: 16),
            Text(
              'Searching for masjids...',
              style: TextStyle(color: AppPalette.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null && _results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppPalette.danger),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Map/List toggle bar
        Container(
          color: AppPalette.surfaceRaised,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_results.length} masjids found',
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  if (_mapCenter != null)
                    IconButton(
                      icon: const Icon(Icons.map, color: AppPalette.accent),
                      onPressed: () {
                        setState(() => _view = _MasjidView.map);
                      },
                      tooltip: 'Map view',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppPalette.textMuted),
                    onPressed: _goHome,
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40),
                  ),
                ],
              ),
            ],
          ),
        ),
        // List of masjids
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            itemCount: _results.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _results[index];
              final isPinned = _pinnedMasjid?['id'] == item.id;
              return Card(
                color: AppPalette.surfaceRaised,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.mosque,
                    color: isPinned ? AppPalette.accent : AppPalette.textMuted,
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(color: AppPalette.textPrimary),
                  ),
                  subtitle: Text(
                    item.address.isEmpty ? 'Address unavailable' : item.address,
                    style: const TextStyle(color: AppPalette.textSecondary),
                  ),
                  trailing: isPinned
                      ? const Icon(
                          Icons.star,
                          color: AppPalette.accent,
                          size: 18,
                        )
                      : const Icon(
                          Icons.chevron_right,
                          color: AppPalette.textMuted,
                        ),
                  onTap: () => _showMasjidOptionsSheet(item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Iqamah edit sheet sub-widgets
// ---------------------------------------------------------------------------

class _OffsetRow extends StatelessWidget {
  const _OffsetRow({required this.label, required this.notifier});

  final String label;
  final ValueNotifier<int> notifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (context, value, child) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: const TextStyle(color: AppPalette.textPrimary),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove, color: AppPalette.textSecondary),
              onPressed: value > 0 ? () => notifier.value = value - 1 : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '+$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: AppPalette.textSecondary),
              onPressed: value < 90 ? () => notifier.value = value + 1 : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }
}

class _JumaaField extends StatelessWidget {
  const _JumaaField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppPalette.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppPalette.textMuted, fontSize: 12),
        filled: true,
        fillColor: AppPalette.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home grid tile
// ---------------------------------------------------------------------------

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E7D52), Color(0xFF1B5E34)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x5056D39A),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: Colors.white70),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

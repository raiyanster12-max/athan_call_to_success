import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_palette.dart';
import 'db_helper.dart';
import 'mosque_service.dart';
import 'notification_service.dart';

class MasjidPage extends StatefulWidget {
  const MasjidPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<MasjidPage> createState() => _MasjidPageState();
}

class _MasjidPageState extends State<MasjidPage> {
  static const String _googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  // DB keys for stored Mawaqit session
  static const String _kEmail = 'mawaqit_email';
  static const String _kToken = 'mawaqit_token';

  bool _isLoading = false;
  String? _error;
  int _foundCount = 0;

  /// UUID of the mosque pinned for prayer notifications (null = none selected).
  String? _selectedMosqueUuid;
  String? _selectedMosqueName;

  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  LatLng? _mapCenter;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadSelectedMosque();
    _loadNearbyMosques();
  }

  @override
  void dispose() {
    if (_controller.isCompleted) {
      _controller.future.then((c) => c.dispose());
    }
    super.dispose();
  }

  Future<void> _loadSelectedMosque() async {
    final uuid = await DBHelper.getSetting(
      NotificationService.kMawaqitMosqueUuid,
    );
    final name = await DBHelper.getSetting(
      NotificationService.kMawaqitMosqueName,
    );
    if (!mounted) return;
    setState(() {
      _selectedMosqueUuid = uuid?.isEmpty == true ? null : uuid;
      _selectedMosqueName = name;
    });
  }

  Future<Position> _getUserLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  Future<void> _loadNearbyMosques() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pos = await _getUserLocation();
      final center = LatLng(pos.latitude, pos.longitude);
      final userMarker = Marker(
        markerId: const MarkerId('user_location'),
        position: center,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'My Location'),
      );

      // Load cached Mawaqit token
      final token = await DBHelper.getSetting(_kToken);
      if (token == null || token.isEmpty) {
        // No token – show user location and prompt login
        if (!mounted) return;
        setState(() {
          _currentPosition = pos;
          _markers = {userMarker};
          _mapCenter = center;
          _isLoading = false;
        });
        await _promptCredentials(retryAfter: true);
        return;
      }

      List<MosqueSummary> mosques;
      try {
        mosques = await MosqueService.searchNearby(
          token,
          pos.latitude,
          pos.longitude,
        );
      } on MawaqitAuthException {
        // Token expired – clear it and prompt for re-login
        await DBHelper.setSetting(_kToken, '');
        if (!mounted) return;
        setState(() {
          _currentPosition = pos;
          _markers = {userMarker};
          _mapCenter = center;
          _isLoading = false;
        });
        await _promptCredentials(retryAfter: true);
        return;
      }

      final markers = <Marker>{};
      for (final mosque in mosques) {
        final lat = mosque.lat!;
        final lng = mosque.lng!;
        final addr =
            mosque.fullAddress.isNotEmpty ? mosque.fullAddress : null;
        final isSelected = mosque.uuid == _selectedMosqueUuid;
        markers.add(
          Marker(
            markerId: MarkerId(mosque.uuid),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isSelected
                  ? BitmapDescriptor.hueAzure
                  : BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: isSelected
                  ? '✔ ${mosque.displayName}'
                  : mosque.displayName,
              snippet: addr,
              onTap: () => _showMosqueSheet(mosque),
            ),
          ),
        );
      }
      markers.add(userMarker);

      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
        _markers = markers;
        _mapCenter = center;
        _foundCount = mosques.length;
      });

      if (_controller.isCompleted) {
        final c = await _controller.future;
        await c.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: center, zoom: 14),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Mosque selection ───────────────────────────────────────────────────────

  /// Bottom sheet with details for [mosque] and option to pin it for prayer
  /// notifications (triggers the notification service to use its calendar).
  Future<void> _showMosqueSheet(MosqueSummary mosque) async {
    if (!mounted) return;
    final isSelected = mosque.uuid == _selectedMosqueUuid;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppPalette.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                mosque.displayName,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (mosque.fullAddress.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  mosque.fullAddress,
                  style: const TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
              if (isSelected) ...[
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Icon(Icons.check_circle, color: AppPalette.accent, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Selected for prayer notifications',
                      style: TextStyle(
                        color: AppPalette.accent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppPalette.textSecondary,
                        side: const BorderSide(color: AppPalette.outline),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Open in Maps'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openInGoogleMaps(
                          mosque.lat!,
                          mosque.lng!,
                          mosque.displayName,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? AppPalette.outline
                            : AppPalette.accent,
                        foregroundColor: Colors.black,
                      ),
                      icon: Icon(
                        isSelected ? Icons.notifications_off : Icons.notifications_active,
                        size: 18,
                      ),
                      label: Text(
                        isSelected ? 'Deselect' : 'Use for Athan',
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _selectMosqueForNotifications(
                          isSelected ? null : mosque,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Save (or clear when [mosque] is null) the selected mosque for prayer
  /// notifications and refresh the map markers to reflect the new selection.
  Future<void> _selectMosqueForNotifications(MosqueSummary? mosque) async {
    if (mosque == null) {
      await DBHelper.setSetting(NotificationService.kMawaqitMosqueUuid, '');
      await DBHelper.setSetting(NotificationService.kMawaqitMosqueName, '');
      setState(() {
        _selectedMosqueUuid = null;
        _selectedMosqueName = null;
      });
    } else {
      await DBHelper.setSetting(
        NotificationService.kMawaqitMosqueUuid,
        mosque.uuid,
      );
      await DBHelper.setSetting(
        NotificationService.kMawaqitMosqueName,
        mosque.displayName,
      );
      setState(() {
        _selectedMosqueUuid = mosque.uuid;
        _selectedMosqueName = mosque.displayName;
      });
    }

    // Refresh markers so the selected mosque shows the blue pin.
    _rebuildMarkers();

    // Inform the user.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mosque == null
              ? 'Notification mosque cleared. Using calculated times.'
              : 'Prayer notifications will now use ${mosque.displayName}\'s schedule.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Rebuild _markers in-place to update the selected mosque pin colour without
  /// making a full API call.
  void _rebuildMarkers() {
    setState(() {
      _markers = _markers.map((m) {
        if (m.markerId.value == 'user_location') return m;
        final isSelected = m.markerId.value == _selectedMosqueUuid;
        // Preserve existing title but prepend/remove checkmark.
        final oldTitle = m.infoWindow.title ?? '';
        final cleanTitle = oldTitle.startsWith('✔ ')
            ? oldTitle.substring(2)
            : oldTitle;
        final newTitle = isSelected ? '✔ $cleanTitle' : cleanTitle;
        return m.copyWith(
          iconParam: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueGreen,
          ),
          infoWindowParam: m.infoWindow.copyWith(titleParam: newTitle),
        );
      }).toSet();
    });
  }

  /// Show a sign-in dialog for mawaqit.net credentials.
  /// If [retryAfter] is true, refreshes the map once login succeeds.
  Future<void> _promptCredentials({bool retryAfter = false}) async {
    String savedEmail = '';
    try {
      savedEmail = await DBHelper.getSetting(_kEmail) ?? '';
    } catch (_) {}
    final emailCtrl = TextEditingController(text: savedEmail);
    final passCtrl = TextEditingController();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String? dialogError;
        bool loggingIn = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AppPalette.surfaceRaised,
            title: const Text(
              'Sign in to Mawaqit',
              style: TextStyle(color: AppPalette.textPrimary),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sign in with your mawaqit.net account to find nearby mosques.',
                    style: TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'If you do not have a mawaqit.net account, but would like to see your local Masjid\'s prayer time - https://mawaqit.net/en/backoffice/register/ register here today for your free account.',
                    style: TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    style: const TextStyle(color: AppPalette.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      labelStyle:
                          TextStyle(color: AppPalette.textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: AppPalette.textSecondary),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppPalette.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    style: const TextStyle(color: AppPalette.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      labelStyle:
                          TextStyle(color: AppPalette.textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: AppPalette.textSecondary),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppPalette.accent),
                      ),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      dialogError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    loggingIn ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppPalette.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.accent,
                ),
                onPressed: loggingIn
                    ? null
                    : () async {
                        setDialogState(() {
                          loggingIn = true;
                          dialogError = null;
                        });
                        try {
                          final token = await MosqueService.login(
                            emailCtrl.text.trim(),
                            passCtrl.text,
                          );
                          try {
                            await DBHelper.setSetting(
                              _kEmail,
                              emailCtrl.text.trim(),
                            );
                            await DBHelper.setSetting(_kToken, token);
                          } catch (_) {}
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setDialogState(() {
                            loggingIn = false;
                            dialogError = e
                                .toString()
                                .replaceFirst('Exception: ', '');
                          });
                        }
                      },
                child: loggingIn
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(color: Colors.black),
                      ),
              ),
            ],
          ),
        );
      },
    );

    emailCtrl.dispose();
    passCtrl.dispose();

    if (retryAfter && mounted) {
      String? token;
      try {
        token = await DBHelper.getSetting(_kToken);
      } catch (_) {}
      if (token != null && token.isNotEmpty) {
        _loadNearbyMosques();
      }
    }
  }

  Future<void> _recenterToUser() async {
    final pos = _currentPosition;
    if (pos == null) return;
    final c = await _controller.future;
    await c.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 15),
      ),
    );
  }

  Future<void> _openInGoogleMaps(double lat, double lng, String label) async {
    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$label';
    final mapsAppUrl = 'comgooglemaps://?center=$lat,$lng&zoom=15&views=traffic';

    try {
      if (await canLaunchUrl(Uri.parse(mapsAppUrl))) {
        await launchUrl(Uri.parse(mapsAppUrl));
      } else if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(
          Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open Google Maps.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.backgroundBottom,
      appBar: AppBar(
        backgroundColor: AppPalette.surfaceRaised,
        title: const Text('Masjid Near Me'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadNearbyMosques,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: _buildMapBody(),
      ),
      floatingActionButton: _currentPosition == null
          ? null
          : FloatingActionButton(
              backgroundColor: AppPalette.accent,
              onPressed: _recenterToUser,
              child: const Icon(Icons.my_location_sharp, color: Colors.black),
            ),
    );
  }

  Widget _buildMapBody() {
    if (_googleMapsApiKey.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mosque, color: AppPalette.accent, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Don\'t have a mawaqit.net account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Register for a free account today to find your local Masjid\'s prayer times.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.app_registration),
                label: const Text(
                  'Register for Free',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () => launchUrl(
                  Uri.parse('https://mawaqit.net/en/backoffice/register/'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'You already have a mawaqit.net account, Login in here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.surfaceRaised,
                  foregroundColor: AppPalette.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppPalette.accent),
                  ),
                ),
                icon: const Icon(Icons.login),
                label: const Text(
                  'Login',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () => _promptCredentials(retryAfter: true),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading && _mapCenter == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppPalette.accent),
      );
    }

    if (_mapCenter == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error ?? 'Map not available yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppPalette.textSecondary),
          ),
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) {
            if (!_controller.isCompleted) {
              _controller.complete(controller);
            }
          },
          initialCameraPosition: CameraPosition(target: _mapCenter!, zoom: 14),
          markers: _markers,
          mapType: MapType.normal,
          compassEnabled: true,
          myLocationEnabled: _currentPosition != null,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppPalette.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.outline),
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
                const Icon(Icons.mosque, color: AppPalette.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isLoading
                            ? 'Searching via Mawaqit...'
                            : '$_foundCount mosque(s) found nearby',
                        style: const TextStyle(
                          color: AppPalette.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      if (_selectedMosqueName != null &&
                          _selectedMosqueName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '🕌 $_selectedMosqueName',
                            style: const TextStyle(
                              color: AppPalette.accent,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppPalette.accent),
                  onPressed: _loadNearbyMosques,
                  tooltip: 'Refresh',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppPalette.textMuted),
                  onPressed:
                      widget.onBack ?? () => Navigator.of(context).maybePop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
        ),
        if (_error != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppPalette.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.danger.withAlpha(130)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppPalette.textSecondary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}

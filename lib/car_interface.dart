import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _cardinal(double deg) {
  if (deg < 22.5 || deg >= 337.5) return 'N';
  if (deg < 67.5) return 'NE';
  if (deg < 112.5) return 'E';
  if (deg < 157.5) return 'SE';
  if (deg < 202.5) return 'S';
  if (deg < 247.5) return 'SW';
  if (deg < 292.5) return 'W';
  return 'NW';
}

// ── Page ──────────────────────────────────────────────────────────────────────

/// Phone-side companion page for the Android Auto car interface.
/// Shows prayer times, Qibla bearing (degrees + cardinal), and a
/// location-permission reminder.
class CarInterfacePage extends StatefulWidget {
  const CarInterfacePage({super.key});

  @override
  State<CarInterfacePage> createState() => _CarInterfacePageState();
}

class _CarInterfacePageState extends State<CarInterfacePage> {
  Position? _position;
  bool _loading = true;
  bool _permissionDenied = false;
  String _locationLabel = '';

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });

    final status = await Permission.locationWhenInUse.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() {
        _permissionDenied = true;
        _loading = false;
      });
      return;
    }

    try {
      // Try last-known first (instant), then fall back to a fresh fix.
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 15));

      setState(() {
        _position = pos;
        _loading = false;
        _locationLabel =
            '${pos!.latitude.toStringAsFixed(4)}°, '
            '${pos.longitude.toStringAsFixed(4)}°';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _locationLabel = 'Could not obtain location.';
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Interface Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLocation,
            tooltip: 'Refresh location',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _permissionDenied
              ? _PermissionGate(onOpenSettings: openAppSettings)
              : _Body(position: _position, locationLabel: _locationLabel),
    );
  }
}

// ── Body (location available) ─────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({required this.position, required this.locationLabel});

  final Position? position;
  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    if (position == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(locationLabel.isNotEmpty
              ? locationLabel
              : 'Location unavailable.'),
        ),
      );
    }

    final lat  = position!.latitude;
    final lon  = position!.longitude;
    final coords = Coordinates(lat, lon);

    // Prayer times (Muslim World League + Shafi madhab)
    final params = CalculationMethod.muslim_world_league.getParameters()
      ..madhab = Madhab.shafi;
    final pt = PrayerTimes(coords, DateComponents.from(DateTime.now()), params);
    final fmt = DateFormat.jm();

    // Qibla — adhan provides the bearing directly
    final qiblaDir = Qibla(coords).direction;  // degrees from North
    final card     = _cardinal(qiblaDir);

    final prayers = <_PrayerRow>[
      _PrayerRow('Fajr',    pt.fajr),
      _PrayerRow('Dhuhr',   pt.dhuhr),
      _PrayerRow('Asr',     pt.asr),
      _PrayerRow('Maghrib', pt.maghrib),
      _PrayerRow('Isha',    pt.isha),
    ];

    final next         = pt.nextPrayer();
    final nextLabel    = next == Prayer.none ? 'None' : next.name.toUpperCase()[0] +
                         next.name.substring(1);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Location permission note ──────────────────────────────────────
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Location Permission (Car)'),
            subtitle: const Text(
              'Android Auto cannot prompt for permissions. '
              'Ensure ACCESS_FINE_LOCATION is granted on this phone '
              'before connecting to your car.',
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── GPS source ────────────────────────────────────────────────────
        Card(
          child: ListTile(
            leading: const Icon(Icons.gps_fixed),
            title: const Text('Current Location'),
            subtitle: Text(locationLabel),
            trailing: Text(
              'Next: $nextLabel',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Qibla direction ───────────────────────────────────────────────
        // Displayed as degrees + cardinal because Android Auto templates
        // cannot render custom drawings or animations.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qibla Direction',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${qiblaDir.toStringAsFixed(1)}°  $card',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Face this bearing on your car compass to face Mecca.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Prayer times ──────────────────────────────────────────────────
        Text(
          'Prayer Times',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...prayers.map(
          (p) => Card(
            child: ListTile(
              dense: true,
              title: Text(p.name),
              trailing: Text(fmt.format(p.time)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Quran audio note ──────────────────────────────────────────────
        // Safety: long-form Quran text is blocked while driving by Android Auto.
        // Audio playback is the recommended in-car experience.
        const Card(
          child: ListTile(
            leading: Icon(Icons.music_note),
            title: Text('Quran (Car)'),
            subtitle: Text(
              'Quran text is disabled by Android Auto while driving. '
              'Select a Surah here to queue it for audio playback on the car head unit.',
            ),
          ),
        ),
      ],
    );
  }
}

// ── Permission gate ───────────────────────────────────────────────────────────

class _PermissionGate extends StatelessWidget {
  const _PermissionGate({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 64),
            const SizedBox(height: 16),
            Text(
              'Location Permission Required',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Android Auto cannot prompt for permissions on the car screen. '
              'Please grant ACCESS_FINE_LOCATION on this phone before '
              'connecting to your car.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Open App Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _PrayerRow {
  const _PrayerRow(this.name, this.time);

  final String name;
  final DateTime time;
}

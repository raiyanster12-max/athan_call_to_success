import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'app_palette.dart';
import 'db_helper.dart';
import 'mosque_service.dart';

class MasjidPage extends StatefulWidget {
  const MasjidPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<MasjidPage> createState() => _MasjidPageState();
}

class _MasjidPageState extends State<MasjidPage> {
  final MosqueService _mosqueService = MosqueService();
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();

  List<MasjidResult> _results = [];
  List<Map<String, dynamic>> _savedMasjids = [];
  bool _isLoading = false;
  String? _error;
  LatLng _mapCenter = const LatLng(39.5, -98.35);
  double? _userLat;
  double? _userLng;
  MasjidResult? _selectedMasjid;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _fetchByGPS();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchByGPS() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      final results = await _mosqueService.findNearbyMosques(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;
      final center = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _results = results;
        _mapCenter = center;
        _isLoading = false;
      });
      if (_mapReady) _mapController.move(center, 13);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchByQuery(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      _fetchByGPS();
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final coords = await _mosqueService.geocodeQuery(q);
      if (!mounted) return;
      final results = await _mosqueService.findNearbyMosques(
        coords.lat,
        coords.lng,
      );
      if (!mounted) return;
      final center = LatLng(coords.lat, coords.lng);
      setState(() {
        _results = results;
        _mapCenter = center;
        _isLoading = false;
      });
      if (_mapReady) _mapController.move(center, 13);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSaved() async {
    final saved = await DBHelper.getMasjids();
    if (!mounted) return;
    setState(() => _savedMasjids = saved);
  }

  Future<void> _saveMasjid(MasjidResult m) async {
    await DBHelper.insertMasjid({
      'id': m.id,
      'name': m.name,
      'address': m.address,
      'lat': m.lat,
      'lng': m.lng,
    });
    await _loadSaved();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${m.name} saved.')));
  }

  Future<void> _removeMasjid(String id, String name) async {
    await DBHelper.deleteMasjid(id);
    await _loadSaved();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name removed.')));
  }

  bool _isSaved(String id) => _savedMasjids.any((m) => m['id'] == id);

  double _distanceKm(MasjidResult m) {
    if (_userLat == null || _userLng == null) return 0;
    const R = 6371.0;
    final dLat = (m.lat - _userLat!) * math.pi / 180;
    final dLng = (m.lng - _userLng!) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_userLat! * math.pi / 180) *
            math.cos(m.lat * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: AppPalette.panel,
            elevation: 4,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    _CircleMapButton(
                      icon: Icons.arrow_back,
                      onPressed:
                          widget.onBack ??
                          () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Material(
                        color: AppPalette.surface,
                        borderRadius: BorderRadius.circular(14),
                        elevation: 0,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Search for a masjid, or a city',
                            hintStyle: TextStyle(
                              color: AppPalette.textMuted,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppPalette.textMuted,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: _fetchByQuery,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CircleMapButton(
                      icon: Icons.my_location,
                      onPressed: () {
                        _searchController.clear();
                        _fetchByGPS();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
          // â”€â”€ Full-screen map â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 13,
              onMapReady: () => setState(() => _mapReady = true),
              onTap: (_, _) => setState(() => _selectedMasjid = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.athan_call_to_success',
              ),
              MarkerLayer(
                markers: [
                  for (final m in _results)
                    Marker(
                      point: LatLng(m.lat, m.lng),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedMasjid = m);
                          _mapController.move(LatLng(m.lat, m.lng), 15);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedMasjid?.id == m.id
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.mosque,
                            size: 22,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (_selectedMasjid != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_selectedMasjid!.lat, _selectedMasjid!.lng),
                      width: 180,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppPalette.surface,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: Text(
                          _selectedMasjid!.name,
                          style: const TextStyle(
                            color: AppPalette.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.12,
            maxChildSize: 0.78,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppPalette.textMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        'Masjids around you',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(child: _buildList(scrollController)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading masjids'),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 40,
                color: AppPalette.danger,
                semanticLabel: 'Error loading masjids',
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _fetchByQuery(_searchController.text),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(child: Text('No masjids found in this area.'));
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final m = _results[i];
        final saved = _isSaved(m.id);
        return _MasjidCard(
          masjid: m,
          distanceKm: _distanceKm(m),
          isSaved: saved,
          isSelected: _selectedMasjid?.id == m.id,
          onTap: () {
            setState(() => _selectedMasjid = m);
            _mapController.move(LatLng(m.lat, m.lng), 15);
          },
          onSave: saved ? null : () => _saveMasjid(m),
          onRemove: saved ? () => _removeMasjid(m.id, m.name) : null,
        );
      },
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CircleMapButton extends StatelessWidget {
  const _CircleMapButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.panel,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MasjidCard extends StatelessWidget {
  const _MasjidCard({
    required this.masjid,
    required this.distanceKm,
    required this.isSaved,
    required this.isSelected,
    required this.onTap,
    this.onSave,
    this.onRemove,
  });

  final MasjidResult masjid;
  final double distanceKm;
  final bool isSaved;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onSave;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleColor = theme.listTileTheme.subtitleTextStyle?.color;
    final distText = distanceKm > 0
        ? (distanceKm < 1
              ? '${(distanceKm * 1000).round()} m'
              : '${distanceKm.toStringAsFixed(2)} km')
        : '';

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected
            ? theme.colorScheme.surface.withValues(alpha: 0.6)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.mosque,
                color: theme.colorScheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    masjid.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (distText.isNotEmpty) ...[
                        Icon(Icons.near_me, size: 12, color: subtitleColor),
                        const SizedBox(width: 3),
                        Text(
                          distText,
                          style: TextStyle(fontSize: 12, color: subtitleColor),
                        ),
                        if (masjid.address.isNotEmpty)
                          Text(
                            '  Â·  ',
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                          ),
                      ],
                      if (masjid.address.isNotEmpty)
                        Expanded(
                          child: Text(
                            masjid.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (onRemove != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onRemove,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.danger,
                          side: const BorderSide(color: AppPalette.danger),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Remove this masjid'),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onSave,
                        icon: const Icon(Icons.bookmark_border, size: 16),
                        label: const Text('Save masjid'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
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
}

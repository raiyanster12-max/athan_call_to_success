import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'app_palette.dart';
import 'mosque_service.dart';

class MasjidPage extends StatefulWidget {
  const MasjidPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<MasjidPage> createState() => _MasjidPageState();
}

enum _MasjidView { home, results }

class _MasjidPageState extends State<MasjidPage> {
  static const int _radiusMeters = 8047; // 5 miles

  final TextEditingController _locationController = TextEditingController();
  final MosqueService _mosqueService = MosqueService();

  _MasjidView _view = _MasjidView.home;
  List<MasjidResult> _results = const [];
  bool _isLoading = false;
  String? _error;
  String _resultsTitle = '';

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _goHome() {
    setState(() {
      _view = _MasjidView.home;
      _results = const [];
      _error = null;
    });
  }

  Future<void> _searchNearYou() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _resultsTitle = 'Near You';
      _view = _MasjidView.results;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _error = 'Location services are disabled.');
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _error = 'Location permission denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;

      final items = await _mosqueService.findNearbyMosques(
        position.latitude,
        position.longitude,
        radiusMeters: _radiusMeters,
      );

      if (!mounted) return;
      setState(() {
        _results = items;
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
      final items = await _mosqueService.findNearbyMosques(
        coords.lat,
        coords.lng,
        radiusMeters: _radiusMeters,
        zipcode: input,
      );
      if (!mounted) return;
      setState(() {
        _results = items;
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

  void _showSearchDialog() {
    _locationController.clear();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surfaceRaised,
        title: const Text(
          'Search by Location',
          style: TextStyle(color: AppPalette.textPrimary),
        ),
        content: TextField(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppPalette.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.accent),
            onPressed: () {
              Navigator.of(ctx).pop();
              _searchByLocation();
            },
            child: const Text('Search',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_view == _MasjidView.home ? 'Masjid Finder' : _resultsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _view == _MasjidView.results
              ? _goHome
              : (widget.onBack ?? () => Navigator.of(context).maybePop()),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppPalette.backgroundGradient),
        child: _view == _MasjidView.home ? _buildHome() : _buildResults(),
      ),
    );
  }

  Widget _buildHome() {
    return GridView.count(
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
            Text('Searching for masjids…',
                style: TextStyle(color: AppPalette.textSecondary)),
          ],
        ),
      );
    }

    if (_error != null && _results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppPalette.danger)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _results[index];
        return Card(
          color: AppPalette.surfaceRaised,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.mosque, color: AppPalette.accent),
            title: Text(item.name,
                style: const TextStyle(color: AppPalette.textPrimary)),
            subtitle: Text(
              item.address.isEmpty ? 'Address unavailable' : item.address,
              style: const TextStyle(color: AppPalette.textSecondary),
            ),
          ),
        );
      },
    );
  }
}

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

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'db_helper.dart';
import 'mosque_service.dart';

class MasjidPage extends StatefulWidget {
  const MasjidPage({super.key});

  @override
  State<MasjidPage> createState() => _MasjidPageState();
}

class _MasjidPageState extends State<MasjidPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MosqueService _mosqueService = MosqueService();

  List<MasjidResult> _nearbyMasjids = [];
  List<Map<String, dynamic>> _savedMasjids = [];
  bool _isLoadingNearby = false;
  bool _isLoadingSaved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSaved();
    _fetchNearby();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchNearby() async {
    setState(() {
      _isLoadingNearby = true;
      _error = null;
    });
    try {
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final results = await _mosqueService.findNearbyMosques(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _nearbyMasjids = results;
        _isLoadingNearby = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoadingNearby = false;
      });
    }
  }

  Future<void> _loadSaved() async {
    setState(() => _isLoadingSaved = true);
    final saved = await DBHelper.getMasjids();
    if (!mounted) return;
    setState(() {
      _savedMasjids = saved;
      _isLoadingSaved = false;
    });
  }

  Future<void> _saveMasjid(MasjidResult masjid) async {
    await DBHelper.insertMasjid({
      'id': masjid.id,
      'name': masjid.name,
      'address': masjid.address,
      'lat': masjid.lat,
      'lng': masjid.lng,
    });
    await _loadSaved();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${masjid.name} saved.')),
    );
  }

  Future<void> _removeMasjid(String id, String name) async {
    await DBHelper.deleteMasjid(id);
    await _loadSaved();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name removed.')),
    );
  }

  bool _isSaved(String id) =>
      _savedMasjids.any((m) => m['id'] == id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Masjid Finder'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.location_on), text: 'Nearby'),
            Tab(icon: Icon(Icons.bookmark), text: 'Saved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNearbyTab(),
          _buildSavedTab(),
        ],
      ),
    );
  }

  Widget _buildNearbyTab() {
    if (_isLoadingNearby) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text(
                'Could not load nearby masjids.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tip: Make sure location permission is granted and you have an internet connection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchNearby,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_nearbyMasjids.isEmpty) {
      return const Center(child: Text('No masjids found nearby.'));
    }
    return RefreshIndicator(
      onRefresh: _fetchNearby,
      child: ListView.builder(
        itemCount: _nearbyMasjids.length,
        itemBuilder: (context, i) {
          final m = _nearbyMasjids[i];
          final saved = _isSaved(m.id);
          return ListTile(
            leading: const Icon(Icons.mosque, color: Color(0xFF00796B)),
            title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: m.address.isNotEmpty ? Text(m.address) : null,
            trailing: IconButton(
              icon: Icon(
                saved ? Icons.bookmark : Icons.bookmark_border,
                color: const Color(0xFF00796B),
              ),
              tooltip: saved ? 'Already saved' : 'Save masjid',
              onPressed: saved ? null : () => _saveMasjid(m),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSavedTab() {
    if (_isLoadingSaved) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_savedMasjids.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No saved masjids yet.\nSearch nearby and tap the bookmark icon to save one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _savedMasjids.length,
      itemBuilder: (context, i) {
        final m = _savedMasjids[i];
        return ListTile(
          leading: const Icon(Icons.mosque, color: Color(0xFF00796B)),
          title: Text(
            m['name'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(m['address'] ?? ''),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Remove',
            onPressed: () => _removeMasjid(m['id'], m['name'] ?? ''),
          ),
        );
      },
    );
  }
}

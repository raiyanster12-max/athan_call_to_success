import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'db_helper.dart';
import 'mosque_service.dart';

class MasjidPage extends StatefulWidget {
  const MasjidPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<MasjidPage> createState() => _MasjidPageState();
}

class _MasjidPageState extends State<MasjidPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MosqueService _mosqueService = MosqueService();
  final TextEditingController _zipcodeController = TextEditingController();

  List<MasjidResult> _nearbyMasjids = [];
  List<Map<String, dynamic>> _savedMasjids = [];
  bool _isLoadingNearby = false;
  bool _isLoadingSaved = false;
  String? _error;
  String? _searchLabel; // describes the active search (GPS or zip)

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
    _zipcodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchNearby() async {
    setState(() {
      _isLoadingNearby = true;
      _error = null;
      _searchLabel = null;
    });
    try {
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
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
        _searchLabel = 'Showing results near your GPS location';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoadingNearby = false;
      });
    }
  }

  Future<void> _fetchNearbyByZipcode(String zipcode) async {
    final zip = zipcode.trim();
    if (zip.isEmpty) {
      _fetchNearby();
      return;
    }

    setState(() {
      _isLoadingNearby = true;
      _error = null;
      _searchLabel = null;
    });

    try {
      final coords = await _mosqueService.geocodeZipcode(zip);
      if (!mounted) return;
      final results = await _mosqueService.findNearbyMosques(
        coords.lat,
        coords.lng,
        zipcode: zip,
      );
      if (!mounted) return;
      setState(() {
        _nearbyMasjids = results;
        _isLoadingNearby = false;
        _searchLabel = 'Showing results within 10 miles of $zip';
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${masjid.name} saved.')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.onBack == null,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: widget.onBack,
              )
            : null,
        title: const Text('Masjid Finder'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4CAF50),
          tabs: const [
            Tab(icon: Icon(Icons.location_on), text: 'Nearby'),
            Tab(icon: Icon(Icons.bookmark), text: 'Saved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildNearbyTab(), _buildSavedTab()],
      ),
    );
  }

  Widget _buildNearbyTab() {
    if (_isLoadingNearby) {
      return const Center(
        child: CircularProgressIndicator(
          // WCAG 4.1.2: announce loading state
          semanticsLabel: 'Loading nearby masjids',
        ),
      );
    }

    return Column(
      children: [
        // ── Zipcode search row ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _zipcodeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Search by zip code (optional)',
                    hintText: 'e.g. 10001',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    counterText: '',
                    isDense: true,
                  ),
                  onSubmitted: _fetchNearbyByZipcode,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _fetchNearbyByZipcode(_zipcodeController.text),
                child: const Text('Go'),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Use my GPS location',
                icon: const Icon(Icons.my_location),
                onPressed: () {
                  _zipcodeController.clear();
                  _fetchNearby();
                },
              ),
            ],
          ),
        ),
        if (_searchLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _searchLabel!,
                // WCAG 1.4.3: Color(0xFF616161) ~5.6:1 on white (passes AA)
                style: const TextStyle(color: Color(0xFF616161), fontSize: 12),
              ),
            ),
          ),
        const SizedBox(height: 8),
        // ── Results ────────────────────────────────────────────────────
        if (_error != null)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // WCAG 1.1.1: semantic label for the error icon
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                      semanticLabel: 'Error loading masjids',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load nearby masjids.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      // WCAG 1.4.3: accessible contrast
                      style: const TextStyle(color: Color(0xFF616161)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tip: Check the zip code, location permission, and internet connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF616161), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _fetchNearbyByZipcode(_zipcodeController.text),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_nearbyMasjids.isEmpty)
          const Expanded(
            child: Center(child: Text('No masjids found in this area.')),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchNearbyByZipcode(_zipcodeController.text),
              child: ListView.builder(
                itemCount: _nearbyMasjids.length,
                itemBuilder: (context, i) {
                  final m = _nearbyMasjids[i];
                  final saved = _isSaved(m.id);
                  return ListTile(
                    leading: const Icon(Icons.mosque, color: Color(0xFF4CAF50)),
                    title: Text(
                      m.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: m.address.isNotEmpty ? Text(m.address) : null,
                    trailing: IconButton(
                      icon: Icon(
                        saved ? Icons.bookmark : Icons.bookmark_border,
                        color: const Color(0xFF4CAF50),
                      ),
                      tooltip: saved ? 'Already saved' : 'Save masjid',
                      onPressed: saved ? null : () => _saveMasjid(m),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSavedTab() {
    if (_isLoadingSaved) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading saved masjids',
        ),
      );
    }
    if (_savedMasjids.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No saved masjids yet.\nSearch nearby and tap the bookmark icon to save one.',
            textAlign: TextAlign.center,
            // WCAG 1.4.3: accessible contrast
            style: TextStyle(color: Color(0xFF616161)),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _savedMasjids.length,
      itemBuilder: (context, i) {
        final m = _savedMasjids[i];
        return ListTile(
          leading: const Icon(Icons.mosque, color: Color(0xFF4CAF50)),
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

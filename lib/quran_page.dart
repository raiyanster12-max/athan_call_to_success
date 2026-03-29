import 'package:flutter/material.dart';

import 'db_helper.dart';
import 'settings_page.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  static const String _favoritesKey = 'quran_favorite_surahs';
  static const String _lastReadKey = 'quran_last_read_surah';

  static const List<_Surah> _surahs = [
    _Surah(1, 'Al-Fatihah', 'The Opening'),
    _Surah(2, 'Al-Baqarah', 'The Cow'),
    _Surah(3, 'Ali Imran', 'Family of Imran'),
    _Surah(4, 'An-Nisa', 'The Women'),
    _Surah(5, 'Al-Ma_idah', 'The Table Spread'),
    _Surah(6, 'Al-Anam', 'The Cattle'),
    _Surah(7, 'Al-Araf', 'The Heights'),
    _Surah(8, 'Al-Anfal', 'The Spoils of War'),
    _Surah(9, 'At-Tawbah', 'The Repentance'),
    _Surah(10, 'Yunus', 'Jonah'),
    _Surah(11, 'Hud', 'Hud'),
    _Surah(12, 'Yusuf', 'Joseph'),
    _Surah(13, 'Ar-Rad', 'The Thunder'),
    _Surah(14, 'Ibrahim', 'Abraham'),
    _Surah(15, 'Al-Hijr', 'The Rocky Tract'),
    _Surah(16, 'An-Nahl', 'The Bee'),
    _Surah(17, 'Al-Isra', 'The Night Journey'),
    _Surah(18, 'Al-Kahf', 'The Cave'),
    _Surah(19, 'Maryam', 'Mary'),
    _Surah(20, 'Ta-Ha', 'Ta-Ha'),
    _Surah(21, 'Al-Anbiya', 'The Prophets'),
    _Surah(22, 'Al-Hajj', 'The Pilgrimage'),
    _Surah(23, 'Al-Muminun', 'The Believers'),
    _Surah(24, 'An-Nur', 'The Light'),
    _Surah(25, 'Al-Furqan', 'The Criterion'),
    _Surah(26, 'Ash-Shuara', 'The Poets'),
    _Surah(27, 'An-Naml', 'The Ant'),
    _Surah(28, 'Al-Qasas', 'The Stories'),
    _Surah(29, 'Al-Ankabut', 'The Spider'),
    _Surah(30, 'Ar-Rum', 'The Romans'),
    _Surah(31, 'Luqman', 'Luqman'),
    _Surah(32, 'As-Sajdah', 'The Prostration'),
    _Surah(33, 'Al-Ahzab', 'The Combined Forces'),
    _Surah(34, 'Saba', 'Sheba'),
    _Surah(35, 'Fatir', 'Originator'),
    _Surah(36, 'Ya-Sin', 'Ya-Sin'),
    _Surah(37, 'As-Saffat', 'Those Who Set The Ranks'),
    _Surah(38, 'Sad', 'Sad'),
    _Surah(39, 'Az-Zumar', 'The Troops'),
    _Surah(40, 'Ghafir', 'The Forgiver'),
    _Surah(41, 'Fussilat', 'Explained In Detail'),
    _Surah(42, 'Ash-Shuraa', 'The Consultation'),
    _Surah(43, 'Az-Zukhruf', 'The Gold Adornments'),
    _Surah(44, 'Ad-Dukhan', 'The Smoke'),
    _Surah(45, 'Al-Jathiyah', 'The Kneeling'),
    _Surah(46, 'Al-Ahqaf', 'The Wind-Curved Sandhills'),
    _Surah(47, 'Muhammad', 'Muhammad'),
    _Surah(48, 'Al-Fath', 'The Victory'),
    _Surah(49, 'Al-Hujurat', 'The Rooms'),
    _Surah(50, 'Qaf', 'Qaf'),
    _Surah(51, 'Adh-Dhariyat', 'The Winnowing Winds'),
    _Surah(52, 'At-Tur', 'The Mount'),
    _Surah(53, 'An-Najm', 'The Star'),
    _Surah(54, 'Al-Qamar', 'The Moon'),
    _Surah(55, 'Ar-Rahman', 'The Most Merciful'),
    _Surah(56, 'Al-Waqiah', 'The Inevitable'),
    _Surah(57, 'Al-Hadid', 'The Iron'),
    _Surah(58, 'Al-Mujadilah', 'The Pleading Woman'),
    _Surah(59, 'Al-Hashr', 'The Exile'),
    _Surah(60, 'Al-Mumtahanah', 'The Woman To Be Examined'),
    _Surah(61, 'As-Saff', 'The Ranks'),
    _Surah(62, 'Al-Jumuah', 'The Congregation'),
    _Surah(63, 'Al-Munafiqun', 'The Hypocrites'),
    _Surah(64, 'At-Taghabun', 'Mutual Loss And Gain'),
    _Surah(65, 'At-Talaq', 'The Divorce'),
    _Surah(66, 'At-Tahrim', 'The Prohibition'),
    _Surah(67, 'Al-Mulk', 'The Sovereignty'),
    _Surah(68, 'Al-Qalam', 'The Pen'),
    _Surah(69, 'Al-Haqqah', 'The Reality'),
    _Surah(70, 'Al-Maarij', 'The Ascending Stairways'),
    _Surah(71, 'Nuh', 'Noah'),
    _Surah(72, 'Al-Jinn', 'The Jinn'),
    _Surah(73, 'Al-Muzzammil', 'The Enshrouded One'),
    _Surah(74, 'Al-Muddaththir', 'The Cloaked One'),
    _Surah(75, 'Al-Qiyamah', 'The Resurrection'),
    _Surah(76, 'Al-Insan', 'The Human'),
    _Surah(77, 'Al-Mursalat', 'Those Sent Forth'),
    _Surah(78, 'An-Naba', 'The Great News'),
    _Surah(79, 'An-Naziat', 'Those Who Drag Forth'),
    _Surah(80, 'Abasa', 'He Frowned'),
    _Surah(81, 'At-Takwir', 'The Overthrowing'),
    _Surah(82, 'Al-Infitar', 'The Cleaving'),
    _Surah(83, 'Al-Mutaffifin', 'Defrauding'),
    _Surah(84, 'Al-Inshiqaq', 'The Splitting Open'),
    _Surah(85, 'Al-Buruj', 'The Mansions Of The Stars'),
    _Surah(86, 'At-Tariq', 'The Morning Star'),
    _Surah(87, 'Al-Ala', 'The Most High'),
    _Surah(88, 'Al-Ghashiyah', 'The Overwhelming'),
    _Surah(89, 'Al-Fajr', 'The Dawn'),
    _Surah(90, 'Al-Balad', 'The City'),
    _Surah(91, 'Ash-Shams', 'The Sun'),
    _Surah(92, 'Al-Layl', 'The Night'),
    _Surah(93, 'Ad-Duhaa', 'The Morning Brightness'),
    _Surah(94, 'Ash-Sharh', 'The Relief'),
    _Surah(95, 'At-Tin', 'The Fig'),
    _Surah(96, 'Al-Alaq', 'The Clot'),
    _Surah(97, 'Al-Qadr', 'The Power'),
    _Surah(98, 'Al-Bayyinah', 'The Clear Evidence'),
    _Surah(99, 'Az-Zalzalah', 'The Earthquake'),
    _Surah(100, 'Al-Adiyat', 'The Courser'),
    _Surah(101, 'Al-Qariah', 'The Calamity'),
    _Surah(102, 'At-Takathur', 'Competition In Increase'),
    _Surah(103, 'Al-Asr', 'The Declining Day'),
    _Surah(104, 'Al-Humazah', 'The Traducer'),
    _Surah(105, 'Al-Fil', 'The Elephant'),
    _Surah(106, 'Quraysh', 'Quraysh'),
    _Surah(107, 'Al-Maun', 'Small Kindnesses'),
    _Surah(108, 'Al-Kawthar', 'Abundance'),
    _Surah(109, 'Al-Kafirun', 'The Disbelievers'),
    _Surah(110, 'An-Nasr', 'The Divine Support'),
    _Surah(111, 'Al-Masad', 'The Palm Fiber'),
    _Surah(112, 'Al-Ikhlas', 'Sincerity'),
    _Surah(113, 'Al-Falaq', 'The Daybreak'),
    _Surah(114, 'An-Nas', 'Mankind'),
  ];

  final TextEditingController _searchController = TextEditingController();
  final Set<int> _favorites = <int>{};
  int? _lastReadSurah;
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuranSettings();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuranSettings() async {
    final favoritesCsv = await DBHelper.getSetting(_favoritesKey);
    final lastRead = await DBHelper.getSetting(_lastReadKey);

    final parsedFavorites = favoritesCsv == null || favoritesCsv.trim().isEmpty
        ? <int>{}
        : favoritesCsv
            .split(',')
            .map((entry) => int.tryParse(entry.trim()))
            .whereType<int>()
            .toSet();

    if (!mounted) return;
    setState(() {
      _favorites
        ..clear()
        ..addAll(parsedFavorites);
      _lastReadSurah = int.tryParse(lastRead ?? '');
      _isLoading = false;
    });
  }

  Future<void> _saveFavorites() async {
    final sorted = _favorites.toList()..sort();
    await DBHelper.setSetting(_favoritesKey, sorted.join(','));
  }

  Future<void> _toggleFavorite(int surahNumber) async {
    setState(() {
      if (_favorites.contains(surahNumber)) {
        _favorites.remove(surahNumber);
      } else {
        _favorites.add(surahNumber);
      }
    });
    await _saveFavorites();
  }

  Future<void> _markAsLastRead(_Surah surah) async {
    await DBHelper.setSetting(_lastReadKey, surah.number.toString());
    if (!mounted) return;
    setState(() {
      _lastReadSurah = surah.number;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Marked ${surah.displayTitle} as last read.')),
    );
  }

  Future<void> _openSurahDetails(_Surah surah) async {
    await _markAsLastRead(surah);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SurahDetailsPage(surah: surah),
      ),
    );
  }

  _Surah? get _lastRead {
    final number = _lastReadSurah;
    if (number == null) return null;
    for (final surah in _surahs) {
      if (surah.number == number) {
        return surah;
      }
    }
    return null;
  }

  List<_Surah> _applyFilters(Iterable<_Surah> items) {
    final filtered = _searchQuery.isEmpty
        ? items.toList()
        : items
            .where(
              (surah) => surah.matches(_searchQuery),
            )
            .toList();

    final lastRead = _lastReadSurah;
    if (lastRead == null) {
      return filtered;
    }

    filtered.sort((a, b) {
      if (a.number == lastRead) return -1;
      if (b.number == lastRead) return 1;
      return a.number.compareTo(b.number);
    });
    return filtered;
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  Widget _buildLastReadCard() {
    final lastRead = _lastRead;
    if (lastRead == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No last-read surah yet. Tap any surah to start tracking.'),
        ),
      );
    }

    return Card(
      color: const Color(0xFF00796B),
      child: ListTile(
        leading: const Icon(Icons.auto_stories, color: Colors.white),
        title: const Text(
          'Continue Reading',
          style: TextStyle(color: Colors.white70),
        ),
        subtitle: Text(
          lastRead.displayTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white),
        onTap: () => _openSurahDetails(lastRead),
      ),
    );
  }

  Widget _buildSurahList(List<_Surah> surahs) {
    if (surahs.isEmpty) {
      return const Center(
        child: Text('No surah found for this filter.'),
      );
    }

    return ListView.builder(
      itemCount: surahs.length,
      itemBuilder: (context, index) {
        final surah = surahs[index];
        final isFavorite = _favorites.contains(surah.number);
        final isLastRead = _lastReadSurah == surah.number;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF00796B),
            foregroundColor: Colors.white,
            child: Text(surah.number.toString()),
          ),
          title: Text(surah.name),
          subtitle: Text(surah.meaning),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLastRead)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.history, size: 18, color: Color(0xFF00796B)),
                ),
              IconButton(
                onPressed: () => _toggleFavorite(surah.number),
                tooltip: isFavorite ? 'Remove favorite' : 'Add favorite',
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.redAccent : null,
                ),
              ),
            ],
          ),
          onTap: () => _openSurahDetails(surah),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allFiltered = _applyFilters(_surahs);
    final favoriteFiltered =
        _applyFilters(_surahs.where((surah) => _favorites.contains(surah.number)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildLastReadCard(),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by surah name, meaning, or number',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => _searchController.clear(),
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.menu_book_outlined), text: 'All Surahs'),
                      Tab(icon: Icon(Icons.favorite_outline), text: 'Favorites'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildSurahList(allFiltered),
                        _buildSurahList(favoriteFiltered),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Surah {
  const _Surah(this.number, this.name, this.meaning);

  final int number;
  final String name;
  final String meaning;

  String get displayTitle => '$number. $name';

  bool matches(String query) {
    if (name.toLowerCase().contains(query)) {
      return true;
    }
    if (meaning.toLowerCase().contains(query)) {
      return true;
    }
    return number.toString() == query;
  }
}

class _SurahDetailsPage extends StatelessWidget {
  const _SurahDetailsPage({required this.surah});

  final _Surah surah;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(surah.displayTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF00796B),
            child: ListTile(
              leading: const Icon(Icons.history, color: Colors.white),
              title: const Text(
                'You Were Reading',
                style: TextStyle(color: Colors.white70),
              ),
              subtitle: Text(
                surah.displayTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    surah.meaning,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Arabic (placeholder)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bismillahir Rahmanir Rahim',
                    style: TextStyle(fontSize: 20, height: 1.5),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Translation (placeholder)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran/quran.dart' as quran;

import 'app_palette.dart';
import 'db_helper.dart';

enum _QuranBrowseMode { chapters, parts, bookmarks }

const Color _quranPageBackground = Color(0xFF121214);
const Color _quranPanelColor = Color(0xFF1C1C1F);
const Color _quranPanelRaised = Color(0xFF232326);
const Color _quranPanelSoft = Color(0xFF2B2B30);
const Color _quranDividerColor = Color(0xFF37373D);
const Color _quranMutedText = Color(0xFF9B9BA2);
const Color _quranSoftText = Color(0xFF73737A);
const Color _quranHighlight = Color(0xFF56D39A);

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  static const String _favoritesKey = 'quran_favorite_surahs';
  static const String _lastReadKey = 'quran_last_read_surah';
  static const String _recentReadsKey = 'quran_recent_read_surahs';

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
  final Map<int, double> _readingProgress = <int, double>{};
  final List<int> _recentReads = <int>[];

  int? _lastReadSurah;
  String _searchQuery = '';
  bool _isLoading = true;
  bool _ascending = true;
  _QuranBrowseMode _browseMode = _QuranBrowseMode.chapters;

  @override
  void initState() {
    super.initState();
    _loadQuranSettings();
    _searchController.addListener(() {
      if (!mounted) return;
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
    final recentReadsCsv = await DBHelper.getSetting(_recentReadsKey);

    final parsedFavorites = favoritesCsv == null || favoritesCsv.trim().isEmpty
        ? <int>{}
        : favoritesCsv
              .split(',')
              .map((entry) => int.tryParse(entry.trim()))
              .whereType<int>()
              .toSet();

    final parsedRecentReads =
        recentReadsCsv == null || recentReadsCsv.trim().isEmpty
        ? <int>[]
        : recentReadsCsv
              .split(',')
              .map((entry) => int.tryParse(entry.trim()))
              .whereType<int>()
              .toList();

    final progressEntries = await Future.wait(
      _surahs.map((surah) async {
        final storedAyah = await DBHelper.getSetting(
          'quran_last_read_ayah_${surah.number}',
        );
        final ayah = int.tryParse(storedAyah ?? '');
        if (ayah == null || ayah <= 0) {
          return MapEntry<int, double>(surah.number, 0);
        }

        final progress = (ayah / quran.getVerseCount(surah.number))
            .clamp(0.0, 1.0)
            .toDouble();
        return MapEntry<int, double>(surah.number, progress);
      }),
    );

    if (!mounted) return;
    setState(() {
      _favorites
        ..clear()
        ..addAll(parsedFavorites);
      _recentReads
        ..clear()
        ..addAll(parsedRecentReads);
      _readingProgress
        ..clear()
        ..addEntries(progressEntries);
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
    final updatedRecentReads = <int>[
      surah.number,
      ..._recentReads.where((number) => number != surah.number),
    ].take(10).toList();
    await DBHelper.setSetting(_recentReadsKey, updatedRecentReads.join(','));

    if (!mounted) return;
    setState(() {
      _lastReadSurah = surah.number;
      _recentReads
        ..clear()
        ..addAll(updatedRecentReads);
    });
  }

  Future<void> _openSurahDetails(_Surah surah) async {
    await _markAsLastRead(surah);
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _SurahDetailsPage(surah: surah)));
    await _loadQuranSettings();
  }

  _Surah? _surahByNumber(int number) {
    for (final surah in _surahs) {
      if (surah.number == number) {
        return surah;
      }
    }
    return null;
  }

  _Surah? get _lastRead {
    final number = _lastReadSurah;
    if (number == null) return null;
    return _surahByNumber(number);
  }

  List<_Surah> _applyFilters(Iterable<_Surah> items) {
    final filtered = _searchQuery.isEmpty
        ? items.toList()
        : items.where((surah) => surah.matches(_searchQuery)).toList();

    filtered.sort((a, b) {
      final compare = a.number.compareTo(b.number);
      return _ascending ? compare : -compare;
    });
    return filtered;
  }

  List<_Surah> get _recentReadSurahs {
    final numbers = <int>[
      ?_lastReadSurah,
      ..._recentReads,
      ..._favorites,
      1,
      2,
      3,
    ];

    final seen = <int>{};
    final result = <_Surah>[];
    for (final number in numbers) {
      if (!seen.add(number)) continue;
      final surah = _surahByNumber(number);
      if (surah != null) {
        result.add(surah);
      }
      if (result.length == 6) break;
    }
    return result;
  }

  Widget _buildPinnedReadCard() {
    final lastRead = _lastRead;
    if (lastRead == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _quranPanelRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _quranDividerColor),
        ),
        child: const Text(
          'No recent reading saved yet. Open any surah to start building your reading history.',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: _quranPanelRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _quranDividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lastRead.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Page ${lastRead.pageNumber} | Juz ${lastRead.juzNumber} | ${lastRead.revelationLabel}',
                  style: const TextStyle(color: _quranMutedText, fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _openSurahDetails(lastRead),
            icon: const Icon(Icons.bookmark_border_rounded),
            color: _quranMutedText,
            tooltip: 'Open last read surah',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search by surah name, Arabic, page, or number',
        hintStyle: const TextStyle(color: _quranMutedText),
        filled: true,
        fillColor: _quranPanelRaised,
        prefixIcon: const Icon(Icons.search, color: _quranMutedText),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.clear, color: _quranMutedText),
                onPressed: () => _searchController.clear(),
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _quranDividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _quranDividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _quranHighlight),
        ),
      ),
    );
  }

  Widget _buildRecentlyReadSection() {
    final items = _recentReadSurahs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recently Read',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final surah = items[index];
              return _buildRecentReadTile(
                surah,
                isActive: surah.number == _lastReadSurah,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentReadTile(_Surah surah, {required bool isActive}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSurahDetails(surah),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 240,
          decoration: BoxDecoration(
            color: _quranPanelRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? _quranHighlight : _quranDividerColor,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? _quranHighlight : _quranMutedText,
                    ),
                  ),
                  child: Text(
                    '${surah.number}:${surah.verseCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        surah.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PG. ${surah.pageNumber} • Juz ${surah.juzNumber}',
                        style: const TextStyle(
                          color: _quranMutedText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isActive ? _quranHighlight : _quranSoftText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrowseModeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildBrowseModeChip(
            label: 'Chapters',
            mode: _QuranBrowseMode.chapters,
            icon: Icons.menu_book_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildBrowseModeChip(
            label: 'Parts',
            mode: _QuranBrowseMode.parts,
            icon: Icons.grid_view_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildBrowseModeChip(
            label: 'Bookmarks',
            mode: _QuranBrowseMode.bookmarks,
            icon: Icons.bookmark_border_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildBrowseModeChip({
    required String label,
    required _QuranBrowseMode mode,
    required IconData icon,
  }) {
    final selected = _browseMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _browseMode = mode),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: selected ? Colors.transparent : _quranPanelColor,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: selected ? Colors.white54 : Colors.transparent,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : _quranMutedText,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _quranMutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUtilityStrip() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _ascending = !_ascending),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _ascending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: _quranSoftText,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SORT BY',
                        style: TextStyle(
                          color: _quranSoftText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _ascending ? 'ASCENDING' : 'DESCENDING',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.track_changes_outlined,
                  color: _quranSoftText,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SHOWN PROGRESS',
                      style: TextStyle(
                        color: _quranSoftText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'READING',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _quranPanelRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _quranDividerColor),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _quranMutedText, fontSize: 15),
      ),
    );
  }

  Widget _buildJuzHeader(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSurahRow(_Surah surah) {
    final progress = _readingProgress[surah.number] ?? 0;
    final isLastRead = surah.number == _lastReadSurah;
    final isFavorite = _favorites.contains(surah.number);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _quranPanelRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLastRead ? _quranHighlight : _quranDividerColor,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openSurahDetails(surah),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 12, 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        surah.number.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            surah.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${surah.verseCount} Verses',
                            style: const TextStyle(
                              color: _quranMutedText,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            surah.revelationLabel,
                            style: const TextStyle(
                              color: _quranMutedText,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          surah.arabicName,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: isFavorite
                              ? 'Remove bookmark'
                              : 'Add bookmark',
                          onPressed: () => _toggleFavorite(surah.number),
                          icon: Icon(
                            isFavorite
                                ? Icons.bookmark
                                : Icons.bookmark_border_rounded,
                            color: isFavorite
                                ? _quranHighlight
                                : _quranMutedText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                height: 6,
                decoration: const BoxDecoration(
                  color: _quranPanelSoft,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(18),
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _quranHighlight,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChapterSectionList(List<_Surah> surahs) {
    if (surahs.isEmpty) {
      return _buildEmptyState('No surahs match this filter.');
    }

    final children = <Widget>[];
    int? currentJuz;
    for (final surah in surahs) {
      if (surah.juzNumber != currentJuz) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: 10));
        }
        children.add(_buildJuzHeader('Juz ${surah.juzNumber}'));
        currentJuz = surah.juzNumber;
      }
      children.add(_buildSurahRow(surah));
    }
    return Column(children: children);
  }

  Widget _buildBookmarksList(List<_Surah> surahs) {
    if (surahs.isEmpty) {
      return _buildEmptyState('No bookmarked surahs yet.');
    }

    return Column(
      children: [for (final surah in surahs) _buildSurahRow(surah)],
    );
  }

  Widget _buildJuzCard(int juz, List<_Surah> surahs) {
    final first = surahs.first;
    final last = surahs.last;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _quranPanelRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _quranDividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        title: Text(
          'Juz $juz',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${surahs.length} surahs • ${first.name} to ${last.name}',
          style: const TextStyle(color: _quranMutedText),
        ),
        trailing: const Icon(Icons.chevron_right, color: _quranMutedText),
        onTap: () => _openSurahDetails(first),
      ),
    );
  }

  Widget _buildPartsList(List<_Surah> surahs) {
    final juzGroups = <int, List<_Surah>>{};
    for (final surah in surahs) {
      juzGroups.putIfAbsent(surah.juzNumber, () => <_Surah>[]).add(surah);
    }

    if (juzGroups.isEmpty) {
      return _buildEmptyState('No parts match this filter.');
    }

    final juzNumbers = juzGroups.keys.toList()..sort();
    if (!_ascending) {
      juzNumbers
        ..clear()
        ..addAll(juzNumbers.reversed);
    }

    return Column(
      children: [
        for (final juz in juzNumbers) _buildJuzCard(juz, juzGroups[juz]!),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final allFiltered = _applyFilters(_surahs);
    final favoriteFiltered = _applyFilters(
      _surahs.where((surah) => _favorites.contains(surah.number)),
    );

    final content = switch (_browseMode) {
      _QuranBrowseMode.chapters => _buildChapterSectionList(allFiltered),
      _QuranBrowseMode.parts => _buildPartsList(allFiltered),
      _QuranBrowseMode.bookmarks => _buildBookmarksList(favoriteFiltered),
    };

    return Scaffold(
      backgroundColor: _quranPageBackground,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Loading Quran'),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Quran',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildPinnedReadCard(),
                  const SizedBox(height: 14),
                  _buildSearchField(),
                  const SizedBox(height: 20),
                  _buildRecentlyReadSection(),
                  const SizedBox(height: 22),
                  const Text(
                    'Chapter and Juz Lists',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBrowseModeSelector(),
                  const SizedBox(height: 14),
                  _buildUtilityStrip(),
                  const SizedBox(height: 14),
                  content,
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

  String get arabicName => quran.getSurahNameArabic(number);

  int get verseCount => quran.getVerseCount(number);

  int get pageNumber => quran.getPageNumber(number, 1);

  int get juzNumber => quran.getJuzNumber(number, 1);

  String get revelationLabel {
    final raw = quran.getPlaceOfRevelation(number).trim().toLowerCase();
    if (raw == 'makkah') return 'Meccan';
    if (raw == 'madinah') return 'Medinan';
    return quran.getPlaceOfRevelation(number);
  }

  bool matches(String query) {
    if (name.toLowerCase().contains(query)) {
      return true;
    }
    if (meaning.toLowerCase().contains(query)) {
      return true;
    }
    if (arabicName.contains(query)) {
      return true;
    }
    if (pageNumber.toString() == query) {
      return true;
    }
    return number.toString() == query;
  }
}

class _SurahDetailsPage extends StatefulWidget {
  const _SurahDetailsPage({required this.surah});

  final _Surah surah;

  @override
  State<_SurahDetailsPage> createState() => _SurahDetailsPageState();
}

class _SurahDetailsPageState extends State<_SurahDetailsPage> {
  static const int _readingGoalMinutes = 5;

  late final int _verseCount;
  late final List<GlobalKey> _verseKeys;

  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _reciterPlayer = AudioPlayer();
  Timer? _readingTimer;

  List<_AyahContent> _verses = <_AyahContent>[];
  bool _isLoading = true;
  bool _showTranslation = true;
  bool _showTransliteration = true;
  bool _showTafsir = true;
  bool _isReciting = false;
  int _selectedAyah = 1;
  int _lastReadAyah = 1;
  Duration _readingDuration = Duration.zero;
  quran.Reciter _selectedReciter = quran.Reciter.arAlafasy;

  String get _lastReadAyahKey => 'quran_last_read_ayah_${widget.surah.number}';

  @override
  void initState() {
    super.initState();
    _verseCount = quran.getVerseCount(widget.surah.number);
    _verseKeys = List<GlobalKey>.generate(_verseCount, (_) => GlobalKey());
    _loadReaderState();
    _reciterPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _isReciting = false);
    });
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _readingDuration += const Duration(seconds: 1);
      });
    });
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    _scrollController.dispose();
    _reciterPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadReaderState() async {
    final storedLastRead = await DBHelper.getSetting(_lastReadAyahKey);
    final parsedLastRead = int.tryParse(storedLastRead ?? '') ?? 1;

    final verseItems = List<_AyahContent>.generate(_verseCount, (index) {
      final ayah = index + 1;
      final arabicVerse = quran.getVerse(
        widget.surah.number,
        ayah,
        verseEndSymbol: true,
      );
      return _AyahContent(
        ayahNumber: ayah,
        arabic: arabicVerse,
        transliteration: _romanizeArabic(arabicVerse),
        translation: quran.getVerseTranslation(
          widget.surah.number,
          ayah,
          translation: quran.Translation.enSaheeh,
        ),
      );
    });

    if (!mounted) return;
    setState(() {
      _verses = verseItems;
      _lastReadAyah = parsedLastRead.clamp(1, _verseCount);
      _selectedAyah = _lastReadAyah;
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToAyah(_selectedAyah, animated: false);
    });
  }

  Future<void> _setSelectedAyah(int ayah) async {
    setState(() {
      _selectedAyah = ayah;
      _lastReadAyah = ayah;
    });
    await DBHelper.setSetting(_lastReadAyahKey, ayah.toString());
  }

  Future<void> _scrollToAyah(int ayah, {bool animated = true}) async {
    if (ayah < 1 || ayah > _verseCount) return;
    _setSelectedAyah(ayah);

    final targetContext = _verseKeys[ayah - 1].currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: animated ? const Duration(milliseconds: 350) : Duration.zero,
      curve: Curves.easeOut,
      alignment: 0.08,
    );
  }

  Future<void> _copyAyah(_AyahContent ayah) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(
        text:
            'Surah ${widget.surah.number}:${ayah.ayahNumber}\n${ayah.arabic}\n${ayah.translation}',
      ),
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Copied ayah ${widget.surah.number}:${ayah.ayahNumber}'),
      ),
    );
  }

  String _romanizeArabic(String input) {
    const map = {
      'ا': 'a',
      'أ': 'a',
      'إ': 'i',
      'آ': 'aa',
      'ب': 'b',
      'ت': 't',
      'ث': 'th',
      'ج': 'j',
      'ح': 'h',
      'خ': 'kh',
      'د': 'd',
      'ذ': 'dh',
      'ر': 'r',
      'ز': 'z',
      'س': 's',
      'ش': 'sh',
      'ص': 's',
      'ض': 'd',
      'ط': 't',
      'ظ': 'z',
      'ع': 'a',
      'غ': 'gh',
      'ف': 'f',
      'ق': 'q',
      'ك': 'k',
      'ل': 'l',
      'م': 'm',
      'ن': 'n',
      'ه': 'h',
      'و': 'w',
      'ي': 'y',
      'ى': 'a',
      'ة': 'h',
      'ئ': 'y',
      'ؤ': 'w',
      'ء': '\'',
      ' ': ' ',
    };

    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      if (map.containsKey(char)) {
        buffer.write(map[char]);
      } else if (RegExp(r'[0-9]').hasMatch(char)) {
        continue;
      }
    }

    final normalized = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return 'Transliteration unavailable';
    }
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  Future<void> _toggleRecitation() async {
    try {
      if (_isReciting) {
        await _reciterPlayer.pause();
        if (mounted) setState(() => _isReciting = false);
        return;
      }

      final url = quran.getAudioURLBySurah(
        widget.surah.number,
        reciter: _selectedReciter,
      );
      await _reciterPlayer.play(UrlSource(url));
      if (mounted) setState(() => _isReciting = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Recitation failed: $e')));
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  void _cycleReciter() {
    const reciters = [
      quran.Reciter.arAlafasy,
      quran.Reciter.arHusary,
      quran.Reciter.arMaherMuaiqly,
      quran.Reciter.arShaatree,
    ];
    final index = reciters.indexOf(_selectedReciter);
    final next = reciters[(index + 1) % reciters.length];
    setState(() => _selectedReciter = next);
  }

  double get _readingGoalProgress {
    final goalSeconds = _readingGoalMinutes * 60;
    return (_readingDuration.inSeconds / goalSeconds).clamp(0, 1);
  }

  String get _readingGoalLabel {
    final minutes = _readingDuration.inMinutes;
    final completed = minutes.clamp(0, _readingGoalMinutes);
    return 'Reading goal: $completed/$_readingGoalMinutes mins';
  }

  String get _surahArabicName => quran.getSurahNameArabic(widget.surah.number);

  bool get _showBasmala => widget.surah.number != 9;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(widget.surah.displayTitle)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: double.infinity,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                FloatingActionButton.small(
                  heroTag: 'quran-scroll-top',
                  backgroundColor: AppPalette.surfaceRaised,
                  foregroundColor: Colors.white,
                  onPressed: _scrollToTop,
                  tooltip: 'Back to top',
                  child: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
                const SizedBox(width: 10),
                FloatingActionButton.small(
                  heroTag: 'quran-toggle-translation',
                  backgroundColor: AppPalette.surfaceRaised,
                  foregroundColor: _showTranslation
                      ? AppPalette.accent
                      : Colors.white,
                  onPressed: () {
                    setState(() => _showTranslation = !_showTranslation);
                  },
                  tooltip: 'Toggle translation',
                  child: const Icon(Icons.translate_rounded),
                ),
                const SizedBox(width: 10),
                FloatingActionButton.small(
                  heroTag: 'quran-toggle-tafsir',
                  backgroundColor: AppPalette.surfaceRaised,
                  foregroundColor: _showTafsir
                      ? AppPalette.accent
                      : Colors.white,
                  onPressed: () {
                    setState(() => _showTafsir = !_showTafsir);
                  },
                  tooltip: 'Toggle tafsir',
                  child: Icon(
                    _showTafsir
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
              ],
            ),
            FloatingActionButton.large(
              heroTag: 'quran-recitation',
              backgroundColor: const Color(0xFF65DA98),
              foregroundColor: Colors.white,
              onPressed: _toggleRecitation,
              child: Icon(
                _isReciting ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          children: [
            Card(
              elevation: 0,
              color: AppPalette.surfaceRaised,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppPalette.outline),
                        color: AppPalette.panel,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.surah.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Page ${widget.surah.pageNumber} | Juz ${widget.surah.juzNumber}',
                                  style: const TextStyle(
                                    color: AppPalette.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _cycleReciter,
                            tooltip: 'Change reciter',
                            icon: const Icon(Icons.record_voice_over_outlined),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppPalette.outline),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white70,
                                width: 1.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                _surahArabicName,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white70,
                                width: 1.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.surah.meaning,
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _readingGoalLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppPalette.textSecondary,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _cycleReciter,
                          icon: const Icon(Icons.record_voice_over_outlined),
                          label: const Text('Reciter'),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: _readingGoalProgress,
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(6),
                                backgroundColor: AppPalette.outline,
                                color: AppPalette.accent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: _selectedAyah,
                          underline: const SizedBox.shrink(),
                          items: List<DropdownMenuItem<int>>.generate(
                            _verseCount,
                            (index) {
                              final ayah = index + 1;
                              return DropdownMenuItem<int>(
                                value: ayah,
                                child: Text(
                                  'Ayah ${widget.surah.number}:$ayah',
                                ),
                              );
                            },
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            _scrollToAyah(value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          selected: _showTransliteration,
                          label: const Text('Transliteration'),
                          onSelected: (enabled) {
                            setState(() => _showTransliteration = enabled);
                          },
                        ),
                        FilterChip(
                          selected: _showTranslation,
                          label: const Text('Translation'),
                          onSelected: (enabled) {
                            setState(() => _showTranslation = enabled);
                          },
                        ),
                        FilterChip(
                          selected: _showTafsir,
                          label: const Text('Tafsir'),
                          onSelected: (enabled) {
                            setState(() => _showTafsir = enabled);
                          },
                        ),
                        Chip(
                          label: Text(
                            'Last read: ${widget.surah.number}:$_lastReadAyah',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_showBasmala)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 10),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppPalette.outline),
                ),
                child: Text(
                  quran.basmala,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 34, height: 1.5),
                ),
              ),
            ..._verses.map((ayah) {
              final isCurrent = ayah.ayahNumber == _selectedAyah;
              return Container(
                key: _verseKeys[ayah.ayahNumber - 1],
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppPalette.surfaceHighlight
                      : AppPalette.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCurrent ? AppPalette.accent : AppPalette.outline,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.expand_more, size: 18),
                            label: Text(
                              'Aya ${widget.surah.number}:${ayah.ayahNumber}',
                            ),
                            onPressed: () => _scrollToAyah(ayah.ayahNumber),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Copy ayah',
                            onPressed: () => _copyAyah(ayah),
                            icon: const Icon(Icons.copy_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ayah.arabic,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontSize: 34, height: 1.75),
                      ),
                      if (_showTransliteration) ...[
                        const SizedBox(height: 10),
                        Text(
                          ayah.transliteration,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 17,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (_showTranslation) ...[
                        const SizedBox(height: 12),
                        Text(
                          ayah.translation,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 18,
                            color: AppPalette.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (_showTafsir) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Tafsir',
                          style: TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ayah.translation,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppPalette.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AyahContent {
  const _AyahContent({
    required this.ayahNumber,
    required this.arabic,
    required this.transliteration,
    required this.translation,
  });

  final int ayahNumber;
  final String arabic;
  final String transliteration;
  final String translation;
}

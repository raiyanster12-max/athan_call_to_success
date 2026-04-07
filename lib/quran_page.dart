import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:google_fonts/google_fonts.dart';
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
  static const String _ayahBookmarksKey = 'quran_bookmarked_ayahs';
  static const String _lastReadKey = 'quran_last_read_surah';
  static const String _recentReadsKey = 'quran_recent_read_surahs';
  static int? _sessionLastReadSurah;

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
  final ScrollController _recentReadsScrollController = ScrollController();
  final Set<int> _favorites = <int>{};
  final Set<String> _ayahBookmarks = <String>{};
  final Map<int, double> _readingProgress = <int, double>{};
  final List<int> _recentReads = <int>[];
  final Map<int, int> _recentReadAyahBySurah = <int, int>{};

  int? _lastReadSurah;
  String _searchQuery = '';
  bool _isLoading = true;
  final bool _ascending = true;
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
    _recentReadsScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuranSettings() async {
    final currentLastReadSurah = _lastReadSurah ?? _sessionLastReadSurah;
    try {
      final favoritesCsv = await DBHelper.getSetting(_favoritesKey);
      final ayahBookmarksCsv = await DBHelper.getSetting(_ayahBookmarksKey);
      final lastRead = await DBHelper.getSetting(_lastReadKey);
      final recentReadsCsv = await DBHelper.getSetting(_recentReadsKey);
      final parsedLastReadSurah =
          int.tryParse(lastRead ?? '') ?? currentLastReadSurah;

      final parsedFavorites =
          favoritesCsv == null || favoritesCsv.trim().isEmpty
          ? <int>{}
          : favoritesCsv
                .split(',')
                .map((entry) => int.tryParse(entry.trim()))
                .whereType<int>()
                .toSet();

      final parsedAyahBookmarks =
          ayahBookmarksCsv == null || ayahBookmarksCsv.trim().isEmpty
          ? <String>{}
          : ayahBookmarksCsv
            .split(',')
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toSet();

      final parsedRecentReads =
          recentReadsCsv == null || recentReadsCsv.trim().isEmpty
          ? <int>[]
          : () {
              final ordered = <int>[];
              final ayahMap = <int, int>{};
              for (final rawToken in recentReadsCsv.split(',')) {
                final token = rawToken.trim();
                if (token.isEmpty) continue;

                final parts = token.split(':');
                final surah = int.tryParse(parts.first.trim());
                if (surah == null) continue;

                final ayah = parts.length > 1
                    ? int.tryParse(parts[1].trim())
                    : null;

                if (!ordered.contains(surah)) {
                  ordered.add(surah);
                }
                if (ayah != null && ayah > 0) {
                  ayahMap[surah] = ayah;
                }
              }
              _recentReadAyahBySurah
                ..clear()
                ..addAll(ayahMap);
              return ordered;
            }();

      final progressEntries = await Future.wait(
        _surahs.map((surah) async {
          try {
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
          } catch (_) {
            return MapEntry<int, double>(surah.number, 0);
          }
        }),
      );

      if (!mounted) return;
      setState(() {
        _favorites
          ..clear()
          ..addAll(parsedFavorites);
        _ayahBookmarks
          ..clear()
          ..addAll(parsedAyahBookmarks);
        _recentReads
          ..clear()
          ..addAll(parsedRecentReads);
        _readingProgress
          ..clear()
          ..addEntries(progressEntries);
        _lastReadSurah = parsedLastReadSurah;
      });
      _sessionLastReadSurah = parsedLastReadSurah;
    } catch (_) {
      // sqflite unavailable on web — keep in-memory/session last-read value.
      if (mounted && currentLastReadSurah != null) {
        setState(() {
          _lastReadSurah = currentLastReadSurah;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFavorites() async {
    final sorted = _favorites.toList()..sort();
    try {
      await DBHelper.setSetting(_favoritesKey, sorted.join(','));
    } catch (_) {}
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
    await _markAsLastReadWithAyah(surah, ayahNumber: null);
  }

  Future<void> _markAsLastReadWithAyah(_Surah surah, {int? ayahNumber}) async {
    _sessionLastReadSurah = surah.number;
    try {
      await DBHelper.setSetting(_lastReadKey, surah.number.toString());
    } catch (_) {}

    if (ayahNumber != null && ayahNumber > 0) {
      _recentReadAyahBySurah[surah.number] = ayahNumber;
    }

    final updatedRecentReads = <int>[
      surah.number,
      ..._recentReads.where((number) => number != surah.number),
    ].take(10).toList();

    final recentCsv = updatedRecentReads
        .map((surahNumber) {
          final ayah = _recentReadAyahBySurah[surahNumber];
          if (ayah == null || ayah <= 0) {
            return surahNumber.toString();
          }
          return '$surahNumber:$ayah';
        })
        .join(',');

    try {
      await DBHelper.setSetting(_recentReadsKey, recentCsv);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _lastReadSurah = surah.number;
      _recentReads
        ..clear()
        ..addAll(updatedRecentReads);
    });
  }

  Future<void> _openSurahDetails(
    _Surah surah, {
    int? initialAyahOverride,
  }) async {
    int? resumeAyah = initialAyahOverride ?? _recentReadAyahBySurah[surah.number];
    try {
      final storedAyah = await DBHelper.getSetting(
        'quran_last_read_ayah_${surah.number}',
      );
      final parsed = int.tryParse(storedAyah ?? '');
      if (parsed != null && parsed > 0) {
        resumeAyah = parsed;
      }
    } catch (_) {}

    debugPrint(
      'Quran Recently Read: opening surah=${surah.number} ${surah.name} ayah=${resumeAyah ?? 1}',
    );
    await _markAsLastReadWithAyah(surah, ayahNumber: resumeAyah);
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) => _SurahDetailsPage(surah: surah, initialAyah: resumeAyah),
      ),
    );

    int? latestAyah = _recentReadAyahBySurah[surah.number];
    try {
      final storedAyah = await DBHelper.getSetting(
        'quran_last_read_ayah_${surah.number}',
      );
      final parsed = int.tryParse(storedAyah ?? '');
      if (parsed != null && parsed > 0) {
        latestAyah = parsed;
      }
    } catch (_) {}

    await _markAsLastReadWithAyah(surah, ayahNumber: latestAyah);
    debugPrint(
      'Quran Recently Read: returned from surah=${surah.number}, saved ayah=${latestAyah ?? 1}, reloading settings',
    );
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

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _quranPanelRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _quranDividerColor),
        ),
        child: const Text(
          'Recently Read will appear here after you open a surah.',
          style: TextStyle(color: _quranMutedText, fontSize: 14),
        ),
      );
    }

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
          child: ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
              },
            ),
            child: Scrollbar(
              controller: _recentReadsScrollController,
              thumbVisibility: true,
              interactive: true,
              child: ListView.separated(
                controller: _recentReadsScrollController,
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
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        surah.number.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            surah.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${surah.verseCount} Verses • ${surah.revelationLabel}',
                            style: const TextStyle(
                              color: _quranMutedText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      surah.arabicName,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.scheherazadeNew(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 4,
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

  List<({int surahNumber, int ayahNumber})> _filteredAyahBookmarks() {
    final items = <({int surahNumber, int ayahNumber})>[];

    for (final token in _ayahBookmarks) {
      final parts = token.split(':');
      if (parts.length != 2) continue;
      final surahNumber = int.tryParse(parts[0].trim());
      final ayahNumber = int.tryParse(parts[1].trim());
      if (surahNumber == null || ayahNumber == null) continue;
      if (surahNumber < 1 || surahNumber > 114 || ayahNumber < 1) continue;
      if (ayahNumber > quran.getVerseCount(surahNumber)) continue;

      final surah = _surahByNumber(surahNumber);
      if (surah == null) continue;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery;
        final ref = '$surahNumber:$ayahNumber';
        final matches =
            surah.matches(query) ||
            ref.contains(query) ||
            surah.number.toString() == query;
        if (!matches) continue;
      }

      items.add((surahNumber: surahNumber, ayahNumber: ayahNumber));
    }

    items.sort((a, b) {
      final surahCompare = a.surahNumber.compareTo(b.surahNumber);
      if (surahCompare != 0) return surahCompare;
      return a.ayahNumber.compareTo(b.ayahNumber);
    });

    return items;
  }

  Widget _buildAyahBookmarkRow(({int surahNumber, int ayahNumber}) bookmark) {
    final surah = _surahByNumber(bookmark.surahNumber)!;
    final arabic = quran.getVerse(
      bookmark.surahNumber,
      bookmark.ayahNumber,
      verseEndSymbol: false,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _quranPanelRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _quranDividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: const Icon(Icons.bookmark, color: _quranHighlight),
        title: Text(
          '${surah.name} ${bookmark.surahNumber}:${bookmark.ayahNumber}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          arabic,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.rtl,
          style: GoogleFonts.scheherazadeNew(
            color: _quranMutedText,
            fontSize: 18,
            height: 1.4,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: _quranMutedText),
        onTap: () => _openSurahDetails(
          surah,
          initialAyahOverride: bookmark.ayahNumber,
        ),
      ),
    );
  }

  Widget _buildBookmarksList(List<({int surahNumber, int ayahNumber})> bookmarks) {
    if (bookmarks.isEmpty) {
      return _buildEmptyState('No bookmarked ayahs yet.');
    }

    return Column(
      children: [for (final bookmark in bookmarks) _buildAyahBookmarkRow(bookmark)],
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
    final ayahBookmarks = _filteredAyahBookmarks();

    final content = switch (_browseMode) {
      _QuranBrowseMode.chapters => _buildChapterSectionList(allFiltered),
      _QuranBrowseMode.parts => _buildPartsList(allFiltered),
      _QuranBrowseMode.bookmarks => _buildBookmarksList(ayahBookmarks),
    };

    return Scaffold(
      backgroundColor: _quranPageBackground,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Loading Quran'),
            )
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
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
                  content,
                    ],
                  ),
                ),
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
  const _SurahDetailsPage({required this.surah, this.initialAyah});

  final _Surah surah;
  final int? initialAyah;

  @override
  State<_SurahDetailsPage> createState() => _SurahDetailsPageState();
}

class _SurahDetailsPageState extends State<_SurahDetailsPage> {
  static const int _readingGoalMinutes = 5;
  static const String _ayahBookmarksKey = 'quran_bookmarked_ayahs';
  static final Map<int, int> _sessionLastReadAyahBySurah = <int, int>{};

  late final int _verseCount;
  late final List<GlobalKey> _verseKeys;

  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _reciterPlayer = AudioPlayer();
  Timer? _readingTimer;

  List<_AyahContent> _verses = <_AyahContent>[];
  bool _isLoading = true;
  bool _showTranslation = true;
  bool _showSurahControls = false;
  int _selectedAyah = 1;
  int _lastReadAyah = 1;
  Duration _readingDuration = Duration.zero;
  double _arabicFontSize = 36;
  double _translationFontSize = 18;
  bool _showTajweed = false;
  String? _loadError;
  final Set<String> _ayahBookmarks = <String>{};

  String _ayahBookmarkToken(int ayahNumber) =>
      '${widget.surah.number}:$ayahNumber';

  bool _isAyahBookmarked(int ayahNumber) =>
      _ayahBookmarks.contains(_ayahBookmarkToken(ayahNumber));

  Future<void> _saveAyahBookmarks() async {
    final sorted = _ayahBookmarks.toList()..sort();
    try {
      await DBHelper.setSetting(_ayahBookmarksKey, sorted.join(','));
    } catch (_) {}
  }

  Future<void> _toggleAyahBookmark(_AyahContent ayah) async {
    final token = _ayahBookmarkToken(ayah.ayahNumber);
    final wasBookmarked = _ayahBookmarks.contains(token);
    setState(() {
      if (wasBookmarked) {
        _ayahBookmarks.remove(token);
      } else {
        _ayahBookmarks.add(token);
      }
    });
    await _saveAyahBookmarks();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasBookmarked
              ? 'Removed bookmark ${widget.surah.number}:${ayah.ayahNumber}'
              : 'Bookmarked ayah ${widget.surah.number}:${ayah.ayahNumber}',
        ),
      ),
    );
  }

  int? _bestEffortVisibleAyah() {
    if (!mounted) return null;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return null;

    final topAnchor = mediaQuery.padding.top + kToolbarHeight + 12;
    final screenHeight = mediaQuery.size.height;

    int? bestAyah;
    double bestDistance = double.infinity;

    for (int i = 0; i < _verseKeys.length; i++) {
      final ctx = _verseKeys[i].currentContext;
      if (ctx == null) continue;

      final render = ctx.findRenderObject();
      if (render is! RenderBox || !render.attached) continue;

      final top = render.localToGlobal(Offset.zero).dy;
      final bottom = top + render.size.height;
      if (bottom < topAnchor || top > screenHeight) continue;

      final distance = (top - topAnchor).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestAyah = i + 1;
      }
    }
    return bestAyah;
  }

  Future<void> _persistLastReadAyah(int ayah, {bool updateUi = true}) async {
    final safeAyah = ayah.clamp(1, _verseCount);
    if (updateUi && mounted) {
      setState(() {
        _selectedAyah = safeAyah;
        _lastReadAyah = safeAyah;
      });
    } else {
      _selectedAyah = safeAyah;
      _lastReadAyah = safeAyah;
    }

    _sessionLastReadAyahBySurah[widget.surah.number] = safeAyah;
    try {
      await DBHelper.setSetting(_lastReadAyahKey, safeAyah.toString());
    } catch (_) {}
  }

  String get _lastReadAyahKey => 'quran_last_read_ayah_${widget.surah.number}';

  /// Builds a list of [TextSpan]s for [text] with basic Tajweed color-coding.
  /// Rules applied (standard colour convention):
  ///  • Madd (ا/و/ي followed by ّ or sukun-context) — blue
  ///  • Qalqalah letters (ق ط ب ج د) — orange
  ///  • Ghunna / Shaddah on ن or م — green
  ///  • Idgham / Ikhfa / Iqlab markers (tanwin + specific letters) — purple
  /// Everything else is rendered in the default text colour.
  static List<TextSpan> _tajweedSpans(String text, double fontSize) {
    // Each rule: pattern → color
    final rules = <(RegExp, Color)>[
      // Qalqalah letters (ق ط ب ج د) with sukun
      (RegExp(r'[قطبجد]ْ'), const Color(0xFFFF9800)),
      // Shaddah on ن or م (Ghunna)
      (RegExp(r'[نم]ّ'), const Color(0xFF4CAF50)),
      // Any madd carrier (long vowels: alef + fatha-madda, or waw/ya with sukun)
      (RegExp(r'[اوي]ٓ|[اوي]ّ|ٱ'), const Color(0xFF42A5F5)),
      // Tanwin (any harakat doubled) – idgham/ikhfa context
      (RegExp(r'[\u064B\u064C\u064D]'), const Color(0xFF9C27B0)),
    ];

    if (text.isEmpty) return [TextSpan(text: text)];

    // Build spans by splitting on rule boundaries.
    // Font is inherited from the parent RichText's TextSpan style.
    final spans = <TextSpan>[];
    int pos = 0;
    while (pos < text.length) {
      // Find the earliest match among all rules
      int earliestStart = text.length;
      Match? earliestMatch;
      Color? earliestColor;
      for (final (pattern, color) in rules) {
        final m = pattern.firstMatch(text.substring(pos));
        if (m != null) {
          final absStart = pos + m.start;
          if (absStart < earliestStart) {
            earliestStart = absStart;
            earliestMatch = m;
            earliestColor = color;
          }
        }
      }
      if (earliestMatch == null) {
        // No more matches — rest is plain
        spans.add(TextSpan(text: text.substring(pos)));
        break;
      }
      // Plain text before match
      if (earliestStart > pos) {
        spans.add(TextSpan(text: text.substring(pos, earliestStart)));
      }
      // Colored match — override only color, inherit font from parent
      spans.add(TextSpan(
        text: earliestMatch.group(0),
        style: TextStyle(
          color: earliestColor,
          fontWeight: FontWeight.w600,
        ),
      ));
      pos = earliestStart + earliestMatch.group(0)!.length;
    }
    return spans;
  }

  @override
  void initState() {
    super.initState();
    _verseCount = quran.getVerseCount(widget.surah.number);
    _verseKeys = List<GlobalKey>.generate(_verseCount, (_) => GlobalKey());
    _loadReaderState();
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _readingDuration += const Duration(seconds: 1);
      });
    });
  }

  @override
  void dispose() {
    final visibleAyah = _bestEffortVisibleAyah() ?? _selectedAyah;
    _sessionLastReadAyahBySurah[widget.surah.number] = visibleAyah;
    unawaited(DBHelper.setSetting(_lastReadAyahKey, visibleAyah.toString()));

    _readingTimer?.cancel();
    _scrollController.dispose();
    _reciterPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadReaderState() async {
    int parsedLastRead =
        widget.initialAyah ?? _sessionLastReadAyahBySurah[widget.surah.number] ?? 1;
    try {
      final storedLastRead = await DBHelper.getSetting(_lastReadAyahKey);
      parsedLastRead = int.tryParse(storedLastRead ?? '') ?? parsedLastRead;
    } catch (_) {}

    try {
      try {
        final rawAyahBookmarks = await DBHelper.getSetting(_ayahBookmarksKey);
        _ayahBookmarks
          ..clear()
          ..addAll(
            (rawAyahBookmarks ?? '')
                .split(',')
                .map((entry) => entry.trim())
                .where((entry) => entry.isNotEmpty),
          );
      } catch (_) {}

      final verseItems = List<_AyahContent>.generate(_verseCount, (index) {
        final ayah = index + 1;
        final arabicVerse = quran.getVerse(
          widget.surah.number,
          ayah,
          verseEndSymbol: true,
        );

        // Keep details page usable even if a translation lookup fails.
        String translation;
        try {
          translation = quran.getVerseTranslation(
            widget.surah.number,
            ayah,
            translation: quran.Translation.enSaheeh,
          );
        } catch (_) {
          translation = 'Translation unavailable for this ayah.';
        }

        return _AyahContent(
          ayahNumber: ayah,
          arabic: arabicVerse,
          translation: translation,
        );
      });

      if (!mounted) return;
      setState(() {
        _verses = verseItems;
        _lastReadAyah = parsedLastRead.clamp(1, _verseCount);
        _selectedAyah = _lastReadAyah;
        _loadError = null;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToAyah(_selectedAyah, animated: false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verses = const <_AyahContent>[];
        _loadError = 'Unable to load this surah right now.';
        _isLoading = false;
      });
      debugPrint('Failed to load surah ${widget.surah.number}: $e');
    }
  }

  Future<void> _setSelectedAyah(int ayah) async {
    await _persistLastReadAyah(ayah);
  }

  Future<void> _scrollToAyah(int ayah, {bool animated = true}) async {
    if (ayah < 1 || ayah > _verseCount) return;
    await _setSelectedAyah(ayah);

    Future<bool> ensureTargetVisible() async {
      final targetContext = _verseKeys[ayah - 1].currentContext;
      if (targetContext == null) return false;
      await Scrollable.ensureVisible(
        targetContext,
        duration: animated ? const Duration(milliseconds: 350) : Duration.zero,
        curve: Curves.easeOut,
        alignment: 0.08,
      );
      return true;
    }

    if (await ensureTargetVisible()) return;
    if (!_scrollController.hasClients) return;

    // Long surahs lazily build off-screen cards. Jump by list fraction first,
    // then retry ensureVisible over a few frames once widgets are materialized.
    final maxExtent = _scrollController.position.maxScrollExtent;
    final fraction = _verseCount <= 1 ? 0.0 : (ayah - 1) / (_verseCount - 1);
    final estimatedOffset = (maxExtent * fraction).clamp(0.0, maxExtent);

    if (animated) {
      await _scrollController.animateTo(
        estimatedOffset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(estimatedOffset);
    }

    if (!mounted) return;
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      if (await ensureTargetVisible()) return;
    }
  }

  String _normalizeAudioUrl(String url) {
    if (url.startsWith('http://')) {
      return 'https://${url.substring('http://'.length)}';
    }
    return url;
  }

  String _everyAyahUrl(int surahNumber, int ayahNumber) {
    final surah = surahNumber.toString().padLeft(3, '0');
    final ayah = ayahNumber.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/Alafasy_128kbps/$surah$ayah.mp3';
  }

  Future<void> _playAyahRecitation(int ayahNumber) async {
    final quranUrl = _normalizeAudioUrl(
      quran.getAudioURLByVerse(
        widget.surah.number,
        ayahNumber,
        reciter: quran.Reciter.arAlafasy,
      ),
    );
    final fallbackUrl = _everyAyahUrl(widget.surah.number, ayahNumber);
    final candidates = <String>{quranUrl, fallbackUrl}.toList(growable: false);

    Object? lastError;
    for (final url in candidates) {
      try {
        await _reciterPlayer.stop();
        await _reciterPlayer.setSourceUrl(url);
        await _reciterPlayer.resume();
        return;
      } catch (e) {
        lastError = e;
        debugPrint('Ayah recitation source failed: $url -> $e');
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ayah recitation failed: $lastError')),
    );
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  Future<void> _openSurahControlsSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surfaceRaised,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void syncState(VoidCallback update) {
              if (mounted) {
                setState(update);
              }
              setSheetState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Surah Controls',
                          style: TextStyle(
                            color: AppPalette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(
                            Icons.close,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ControlRow(
                      label: 'Arabic',
                      value: _arabicFontSize.round(),
                      onDecrease: () => syncState(() {
                        _arabicFontSize =
                            (_arabicFontSize - 2).clamp(28, 52).toDouble();
                      }),
                      onIncrease: () => syncState(() {
                        _arabicFontSize =
                            (_arabicFontSize + 2).clamp(28, 52).toDouble();
                      }),
                    ),
                    const SizedBox(height: 6),
                    _ControlRow(
                      label: 'Translation',
                      value: _translationFontSize.round(),
                      onDecrease: () => syncState(() {
                        _translationFontSize =
                            (_translationFontSize - 1).clamp(14, 26).toDouble();
                      }),
                      onIncrease: () => syncState(() {
                        _translationFontSize =
                            (_translationFontSize + 1).clamp(14, 26).toDouble();
                      }),
                      trailing: Switch(
                        value: _showTranslation,
                        onChanged: (v) => syncState(() => _showTranslation = v),
                        activeThumbColor: AppPalette.accent,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        const Text(
                          'Tajweed',
                          style: TextStyle(
                            color: AppPalette.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _showTajweed,
                          onChanged: (v) => syncState(() => _showTajweed = v),
                          activeThumbColor: AppPalette.accent,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      children: [
                        const Text(
                          'Jump to',
                          style: TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: _selectedAyah,
                          underline: const SizedBox.shrink(),
                          items: List<DropdownMenuItem<int>>.generate(
                            _verseCount,
                            (index) {
                              final ayah = index + 1;
                              return DropdownMenuItem<int>(
                                value: ayah,
                                child: Text('Ayah ${widget.surah.number}:$ayah'),
                              );
                            },
                          ),
                          onChanged: (value) async {
                            if (value == null) return;
                            await _scrollToAyah(value);
                            if (!mounted) return;
                            setSheetState(() {});
                          },
                        ),
                        const Spacer(),
                        Text(
                          'Last read: ${widget.surah.number}:$_lastReadAyah',
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

  bool get _showBasmala => widget.surah.number != 9 && widget.surah.number != 1;

  String _displayArabicForAyah(_AyahContent ayah) {
    if (!_showBasmala || ayah.ayahNumber != 1) {
      return ayah.arabic;
    }

    final words = ayah.arabic.trim().split(RegExp(r'\s+'));
    if (words.length < 4) {
      return ayah.arabic;
    }

    final normalizedHead = words
        .take(4)
        .map(_normalizeArabicToken)
        .toList(growable: false);
    const normalizedBasmala = ['بسم', 'الله', 'الرحمن', 'الرحيم'];

    var isBasmalaPrefix = true;
    for (int i = 0; i < normalizedBasmala.length; i++) {
      if (normalizedHead[i] != normalizedBasmala[i]) {
        isBasmalaPrefix = false;
        break;
      }
    }

    if (!isBasmalaPrefix) {
      return ayah.arabic;
    }

    final remaining = words.skip(4).join(' ').trim();
    // If the whole verse IS the basmala (e.g. Surah 1 Ayah 1), stripping it
    // leaves only a verse-end symbol with no meaningful Arabic content.
    // In that case return the original so the card matches its translation.
    if (remaining.isEmpty || _normalizeArabicToken(remaining).isEmpty) {
      return ayah.arabic;
    }
    return remaining;
  }

  String _normalizeArabicToken(String token) {
    return token
        .replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
        .replaceAll(RegExp(r'[^\u0621-\u064A]'), '');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.surah.displayTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book_rounded, size: 40),
                const SizedBox(height: 12),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _loadError = null;
                    });
                    _loadReaderState();
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(widget.surah.displayTitle)),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'quran-surah-controls',
            backgroundColor: AppPalette.surfaceRaised,
            foregroundColor: Colors.white,
            onPressed: _openSurahControlsSheet,
            tooltip: 'Surah controls',
            child: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'quran-scroll-top',
            backgroundColor: AppPalette.surfaceRaised,
            foregroundColor: Colors.white,
            onPressed: _scrollToTop,
            tooltip: 'Back to top',
            child: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollEndNotification ||
                (notification is UserScrollNotification &&
                    notification.direction == ScrollDirection.idle)) {
              final visibleAyah = _bestEffortVisibleAyah();
              if (visibleAyah != null && visibleAyah != _lastReadAyah) {
                unawaited(_persistLastReadAyah(visibleAyah, updateUi: false));
              }
            }
            return false;
          },
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
                    Text(
                      'Page ${widget.surah.pageNumber} | Juz ${widget.surah.juzNumber}',
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.surah.meaning,
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _showSurahControls = !_showSurahControls);
                      },
                      icon: Icon(
                        _showSurahControls
                            ? Icons.tune_rounded
                            : Icons.tune_outlined,
                      ),
                      label: Text(
                        _showSurahControls ? 'Hide Surah Controls' : 'Show Surah Controls',
                      ),
                    ),
                    if (_showSurahControls) ...[
                      const SizedBox(height: 10),
                      // ── Arabic font size ─────────────────────────────────
                      _ControlRow(
                        label: 'Arabic',
                        value: _arabicFontSize.round(),
                        onDecrease: () => setState(() {
                          _arabicFontSize =
                              (_arabicFontSize - 2).clamp(28, 52).toDouble();
                        }),
                        onIncrease: () => setState(() {
                          _arabicFontSize =
                              (_arabicFontSize + 2).clamp(28, 52).toDouble();
                        }),
                      ),
                      const SizedBox(height: 4),
                      // ── Translation font size + toggle ───────────────────
                      _ControlRow(
                        label: 'Translation',
                        value: _translationFontSize.round(),
                        onDecrease: () => setState(() {
                          _translationFontSize = (_translationFontSize - 1)
                              .clamp(14, 26)
                              .toDouble();
                        }),
                        onIncrease: () => setState(() {
                          _translationFontSize = (_translationFontSize + 1)
                              .clamp(14, 26)
                              .toDouble();
                        }),
                        trailing: Switch(
                          value: _showTranslation,
                          onChanged: (v) =>
                              setState(() => _showTranslation = v),
                          activeThumbColor: AppPalette.accent,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ── Tajweed ──────────────────────────────────────────
                      Row(
                        children: [
                          const SizedBox(width: 4),
                          const Text(
                            'Tajweed',
                            style: TextStyle(
                              color: AppPalette.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: _showTajweed,
                            onChanged: (v) =>
                                setState(() => _showTajweed = v),
                            activeThumbColor: AppPalette.accent,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      const Divider(height: 12),
                      // ── Ayah jump + last read ────────────────────────────
                      Row(
                        children: [
                          const Text(
                            'Jump to',
                            style: TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                          const Spacer(),
                          Text(
                            'Last read: ${widget.surah.number}:$_lastReadAyah',
                            style: const TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                  style: GoogleFonts.scheherazadeNew(
                    fontSize: 34,
                    height: 1.5,
                  ),
                ),
              ),
            ..._verses.map((ayah) {
              final isCurrent = ayah.ayahNumber == _selectedAyah;
              final ayahArabicDisplay = _displayArabicForAyah(ayah);
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
                            tooltip: _isAyahBookmarked(ayah.ayahNumber)
                                ? 'Remove ayah bookmark'
                                : 'Bookmark ayah',
                            onPressed: () => _toggleAyahBookmark(ayah),
                            icon: Icon(
                              _isAyahBookmarked(ayah.ayahNumber)
                                  ? Icons.bookmark
                                  : Icons.bookmark_border_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _playAyahRecitation(ayah.ayahNumber),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 8,
                          textDirection: TextDirection.rtl,
                          children: [
                            for (final word
                                in ayahArabicDisplay
                                    .split(RegExp(r'\s+'))
                                    .where((w) => w.trim().isNotEmpty))
                              _showTajweed
                                  ? RichText(
                                      textDirection: TextDirection.rtl,
                                      text: TextSpan(
                                        style: GoogleFonts.scheherazadeNew(
                                          fontSize: _arabicFontSize,
                                          height: 1.75,
                                        ),
                                        children: _tajweedSpans(
                                          word,
                                          _arabicFontSize,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      word,
                                      textDirection: TextDirection.rtl,
                                      style: GoogleFonts.scheherazadeNew(
                                        fontSize: _arabicFontSize,
                                        height: 1.75,
                                      ),
                                    ),
                          ],
                        ),
                      ),
                      if (_showTranslation) ...[
                        const SizedBox(height: 12),
                        Text(
                          ayah.translation,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: _translationFontSize,
                            color: AppPalette.textSecondary,
                            height: 1.5,
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
      ),
    );
  }
}

class _AyahContent {
  const _AyahContent({
    required this.ayahNumber,
    required this.arabic,
    required this.translation,
  });

  final int ayahNumber;
  final String arabic;
  final String translation;
}

/// A labelled font-size control row used inside Surah Controls panel.
/// Shows:  [Label]  [−]  [value]  [+]  [optional trailing widget]
class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.label,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
    this.trailing,
  });

  final String label;
  final int value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 4),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onDecrease,
          icon: const Icon(Icons.remove_circle_outline, size: 20),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppPalette.textSecondary),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onIncrease,
          icon: const Icon(Icons.add_circle_outline, size: 20),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

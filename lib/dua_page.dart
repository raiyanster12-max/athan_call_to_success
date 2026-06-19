import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_palette.dart';

class DuaCategory {
  const DuaCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.duas,
  });

  final String id;
  final String name;
  final String icon;
  final List<Dua> duas;

  factory DuaCategory.fromJson(Map<String, dynamic> json) {
    return DuaCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      duas: (json['duas'] as List).map((d) => Dua.fromJson(d as Map<String, dynamic>)).toList(),
    );
  }
}

class Dua {
  const Dua({
    required this.id,
    required this.arabic,
    required this.translation,
    required this.transliteration,
    required this.source,
    required this.repeat,
  });

  final int id;
  final String arabic;
  final String translation;
  final String transliteration;
  final String source;
  final int repeat;

  factory Dua.fromJson(Map<String, dynamic> json) {
    return Dua(
      id: json['id'] as int,
      arabic: json['arabic'] as String,
      translation: json['translation'] as String,
      transliteration: json['transliteration'] as String,
      source: json['source'] as String,
      repeat: json['repeat'] as int,
    );
  }
}

const Map<String, IconData> _iconMap = {
  'wb_sunny': Icons.wb_sunny_outlined,
  'nightlight_round': Icons.nightlight_round_outlined,
  'mosque': Icons.mosque_outlined,
  'restaurant': Icons.restaurant_outlined,
  'home': Icons.home_outlined,
  'shield': Icons.shield_outlined,
  'flight': Icons.flight_outlined,
  'favorite': Icons.favorite_outline,
  'bedtime': Icons.bedtime_outlined,
};

class DuaPage extends StatefulWidget {
  const DuaPage({super.key});

  @override
  State<DuaPage> createState() => _DuaPageState();
}

class _DuaPageState extends State<DuaPage> {
  static const String _favoritesKey = 'dua_favorites';

  List<DuaCategory> _categories = [];
  Set<int> _favoriteIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final jsonStr = await rootBundle.loadString('assets/data/duas.json');
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final categories = (data['categories'] as List)
        .map((c) => DuaCategory.fromJson(c as Map<String, dynamic>))
        .toList();

    final prefs = await SharedPreferences.getInstance();
    final savedFavs = prefs.getStringList(_favoritesKey) ?? [];
    final favIds = savedFavs.map((s) => int.tryParse(s)).whereType<int>().toSet();

    if (!mounted) return;
    setState(() {
      _categories = categories;
      _favoriteIds = favIds;
      _isLoading = false;
    });
  }

  Future<void> _toggleFavorite(int duaId) async {
    setState(() {
      if (_favoriteIds.contains(duaId)) {
        _favoriteIds.remove(duaId);
      } else {
        _favoriteIds.add(duaId);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoritesKey,
      _favoriteIds.map((id) => id.toString()).toList(),
    );
  }

  List<Dua> get _allDuas =>
      _categories.expand((c) => c.duas).toList();

  List<Dua> get _favoriteDuas =>
      _allDuas.where((d) => _favoriteIds.contains(d.id)).toList();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Duas & Adhkar')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? palette.backgroundTop : null,
      appBar: AppBar(
        title: const Text('Duas & Adhkar'),
        backgroundColor: isDark ? palette.backgroundTop : null,
      ),
      body: _buildCategoryList(palette, isDark, cs),
    );
  }

  Widget _buildCategoryList(AppPaletteData palette, bool isDark, ColorScheme cs) {
    final favDuas = _favoriteDuas;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (favDuas.isNotEmpty) ...[
          _buildFavoritesCard(favDuas, palette, isDark, cs),
          const SizedBox(height: 16),
        ],
        ..._categories.map((cat) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildCategoryCard(cat, palette, isDark, cs),
        )),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFavoritesCard(
    List<Dua> favDuas,
    AppPaletteData palette,
    bool isDark,
    ColorScheme cs,
  ) {
    return Card(
      color: isDark ? palette.surface : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDuaList('Favorites', favDuas),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppPalette.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite, color: AppPalette.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Favorites',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isDark ? palette.textPrimary : cs.onSurface,
                      ),
                    ),
                    Text(
                      '${favDuas.length} saved',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? palette.textMuted : cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? palette.textMuted : cs.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    DuaCategory category,
    AppPaletteData palette,
    bool isDark,
    ColorScheme cs,
  ) {
    final icon = _iconMap[category.icon] ?? Icons.menu_book_outlined;

    return Card(
      color: isDark ? palette.surface : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDuaList(category.name, category.duas),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppPalette.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppPalette.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isDark ? palette.textPrimary : cs.onSurface,
                      ),
                    ),
                    Text(
                      '${category.duas.length} duas',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? palette.textMuted : cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? palette.textMuted : cs.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDuaList(String title, List<Dua> duas) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DuaListPage(
          title: title,
          duas: duas,
          favoriteIds: _favoriteIds,
          onToggleFavorite: _toggleFavorite,
        ),
      ),
    );
  }

}

class _DuaListPage extends StatelessWidget {
  const _DuaListPage({
    required this.title,
    required this.duas,
    required this.favoriteIds,
    required this.onToggleFavorite,
  });

  final String title;
  final List<Dua> duas;
  final Set<int> favoriteIds;
  final Future<void> Function(int) onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? palette.backgroundTop : null,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: isDark ? palette.backgroundTop : null,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: duas.length,
        itemBuilder: (context, index) => _DuaCardWidget(
          dua: duas[index],
          isFavorite: favoriteIds.contains(duas[index].id),
          onToggleFavorite: () => onToggleFavorite(duas[index].id),
          palette: palette,
          isDark: isDark,
          cs: cs,
        ),
      ),
    );
  }
}

class _DuaCardWidget extends StatefulWidget {
  const _DuaCardWidget({
    required this.dua,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.palette,
    required this.isDark,
    required this.cs,
  });

  final Dua dua;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final AppPaletteData palette;
  final bool isDark;
  final ColorScheme cs;

  @override
  State<_DuaCardWidget> createState() => _DuaCardWidgetState();
}

class _DuaCardWidgetState extends State<_DuaCardWidget> {
  bool _showTransliteration = false;

  @override
  Widget build(BuildContext context) {
    final dua = widget.dua;
    final isDark = widget.isDark;
    final palette = widget.palette;
    final cs = widget.cs;

    return Card(
      color: isDark ? palette.surface : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              dua.arabic,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 22,
                height: 1.8,
                color: isDark ? palette.textPrimary : cs.onSurface,
                fontFamily: 'NotoNaskhArabic',
              ),
            ),
            const SizedBox(height: 14),
            Text(
              dua.translation,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? palette.textSecondary : cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _showTransliteration = !_showTransliteration),
              child: Row(
                children: [
                  Icon(
                    _showTransliteration ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppPalette.accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Transliteration',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppPalette.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (_showTransliteration) ...[
              const SizedBox(height: 6),
              Text(
                dua.transliteration,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                  color: isDark ? palette.textMuted : cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 14,
                  color: isDark ? palette.textMuted : cs.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dua.source,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? palette.textMuted : cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                if (dua.repeat > 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppPalette.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${dua.repeat}x',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: widget.onToggleFavorite,
                  child: Icon(
                    widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 22,
                    color: widget.isFavorite
                        ? AppPalette.danger
                        : (isDark ? palette.textMuted : cs.onSurface.withValues(alpha: 0.4)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

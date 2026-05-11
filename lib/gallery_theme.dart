import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'db_helper.dart';

class GalleryItem {
  const GalleryItem({
    required this.assetPath,
    required this.label,
    required this.darkPalette,
  });

  final String assetPath;
  final String label;
  final AppPaletteData darkPalette;
}

const List<GalleryItem> galleryItems = [
  // 0 — original hero (default)
  GalleryItem(
    assetPath: 'assets/images/hero_bg.png',
    label: 'Original',
    darkPalette: AppPaletteData(
      backgroundTop: Color(0xFF262943),
      backgroundMid: Color(0xFF2E3252),
      backgroundBottom: Color(0xFF343760),
      surface: Color(0xFF2E3252),
      surfaceRaised: Color(0xFF353960),
      surfaceHighlight: Color(0xFF3D4270),
      panel: Color(0xFF202340),
      outline: Color(0xFF4A4F7A),
      textPrimary: Color(0xFFF5F0E1),
      textSecondary: Color(0xFFE0D4C0),
      textMuted: Color(0xFF968A78),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.45, 1.0],
        colors: [Color(0xFF262943), Color(0xFF2E3252), Color(0xFF343760)],
      ),
      heroGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.5, 1.0],
        colors: [Color(0xFF1A1D38), Color(0xFF262943), Color(0xFF1E2238)],
      ),
      heroTextColor: Colors.white,
    ),
  ),

  // 1 — lantern on blue prayer mat
  GalleryItem(
    assetPath: 'assets/images/gallery_1.jpg',
    label: 'Lantern',
    darkPalette: AppPaletteData(
      backgroundTop: Color(0xFF0A1628),
      backgroundMid: Color(0xFF152035),
      backgroundBottom: Color(0xFF0A1220),
      surface: Color(0xFF1A2D45),
      surfaceRaised: Color(0xFF20364F),
      surfaceHighlight: Color(0xFF274055),
      panel: Color(0xFF0D1A2E),
      outline: Color(0xFF2A4060),
      textPrimary: Color(0xFFF5F0E1),
      textSecondary: Color(0xFFD0DDE8),
      textMuted: Color(0xFF7A96A8),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.45, 1.0],
        colors: [Color(0xFF0A1628), Color(0xFF152035), Color(0xFF0A1220)],
      ),
      heroGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.5, 1.0],
        colors: [Color(0xFF061020), Color(0xFF0A1628), Color(0xFF08121E)],
      ),
      heroTextColor: Colors.white,
    ),
  ),

  // 2 — mosque with shooting stars / crescent moon
  GalleryItem(
    assetPath: 'assets/images/gallery_2.jpg',
    label: 'Starry Night',
    darkPalette: AppPaletteData(
      backgroundTop: Color(0xFF0E0B22),
      backgroundMid: Color(0xFF1A1240),
      backgroundBottom: Color(0xFF231550),
      surface: Color(0xFF1E1545),
      surfaceRaised: Color(0xFF271C52),
      surfaceHighlight: Color(0xFF302460),
      panel: Color(0xFF0C0A1E),
      outline: Color(0xFF352B60),
      textPrimary: Color(0xFFF5F0E1),
      textSecondary: Color(0xFFD8C8F0),
      textMuted: Color(0xFF8878A8),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.45, 1.0],
        colors: [Color(0xFF0E0B22), Color(0xFF1A1240), Color(0xFF231550)],
      ),
      heroGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.5, 1.0],
        colors: [Color(0xFF08061A), Color(0xFF0E0B22), Color(0xFF0C0820)],
      ),
      heroTextColor: Colors.white,
    ),
  ),

  // 3 — flat periwinkle mosque silhouette
  GalleryItem(
    assetPath: 'assets/images/gallery_3.jpeg',
    label: 'Twilight',
    darkPalette: AppPaletteData(
      backgroundTop: Color(0xFF373760),
      backgroundMid: Color(0xFF3D3D6B),
      backgroundBottom: Color(0xFF303060),
      surface: Color(0xFF484878),
      surfaceRaised: Color(0xFF525285),
      surfaceHighlight: Color(0xFF5C5C90),
      panel: Color(0xFF2E2E58),
      outline: Color(0xFF5A5A88),
      textPrimary: Color(0xFFF5F0E1),
      textSecondary: Color(0xFFD8D0F0),
      textMuted: Color(0xFF9890C0),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.45, 1.0],
        colors: [Color(0xFF373760), Color(0xFF3D3D6B), Color(0xFF303060)],
      ),
      heroGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.5, 1.0],
        colors: [Color(0xFF282855), Color(0xFF373760), Color(0xFF2C2C58)],
      ),
      heroTextColor: Colors.white,
    ),
  ),

  // 4 — mosque through stone arch, milky way
  GalleryItem(
    assetPath: 'assets/images/gallery_4.jpg',
    label: 'Milky Way',
    darkPalette: AppPaletteData(
      backgroundTop: Color(0xFF050F20),
      backgroundMid: Color(0xFF0C1B35),
      backgroundBottom: Color(0xFF071428),
      surface: Color(0xFF122040),
      surfaceRaised: Color(0xFF1A2A50),
      surfaceHighlight: Color(0xFF20325A),
      panel: Color(0xFF060E1C),
      outline: Color(0xFF1E3060),
      textPrimary: Color(0xFFF5F0E1),
      textSecondary: Color(0xFFCCD8E8),
      textMuted: Color(0xFF7090A8),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.45, 1.0],
        colors: [Color(0xFF050F20), Color(0xFF0C1B35), Color(0xFF071428)],
      ),
      heroGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.5, 1.0],
        colors: [Color(0xFF030A18), Color(0xFF050F20), Color(0xFF040C1C)],
      ),
      heroTextColor: Colors.white,
    ),
  ),

  // 5 — minaret at dusk with hanging lantern
  GalleryItem(
    assetPath: 'assets/images/gallery_5.jpg',
    label: 'Dusk',
    darkPalette: AppPaletteData(
      backgroundTop: Color(0xFF0C1E25),
      backgroundMid: Color(0xFF152C35),
      backgroundBottom: Color(0xFF0A1820),
      surface: Color(0xFF1C3540),
      surfaceRaised: Color(0xFF22404C),
      surfaceHighlight: Color(0xFF284A56),
      panel: Color(0xFF091820),
      outline: Color(0xFF2A4F5C),
      textPrimary: Color(0xFFF5F0E1),
      textSecondary: Color(0xFFCCDDE0),
      textMuted: Color(0xFF6E9098),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.45, 1.0],
        colors: [Color(0xFF0C1E25), Color(0xFF152C35), Color(0xFF0A1820)],
      ),
      heroGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.5, 1.0],
        colors: [Color(0xFF07141A), Color(0xFF0C1E25), Color(0xFF081820)],
      ),
      heroTextColor: Colors.white,
    ),
  ),

  // 6 — golden hour / warm amber mosque
  GalleryItem(
    assetPath: 'assets/images/gallery_6.jpeg',
    label: 'Golden Hour',
    darkPalette: AppPaletteData(
      backgroundTop: Color(0xFF1E1205),
      backgroundMid: Color(0xFF2A1C0A),
      backgroundBottom: Color(0xFF1A1004),
      surface: Color(0xFF2E2010),
      surfaceRaised: Color(0xFF382A18),
      surfaceHighlight: Color(0xFF423220),
      panel: Color(0xFF160E02),
      outline: Color(0xFF503C20),
      textPrimary: Color(0xFFF5F0E1),
      textSecondary: Color(0xFFE8D8B0),
      textMuted: Color(0xFF9A8060),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.45, 1.0],
        colors: [Color(0xFF1E1205), Color(0xFF2A1C0A), Color(0xFF1A1004)],
      ),
      heroGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.5, 1.0],
        colors: [Color(0xFF140C02), Color(0xFF1E1205), Color(0xFF180E04)],
      ),
      heroTextColor: Colors.white,
    ),
  ),

  // 7 — moonlit silver / cool blue-grey
  GalleryItem(
    assetPath: 'assets/images/gallery_7.jpeg',
    label: 'Moonlit',
    darkPalette: AppPaletteData(
      backgroundTop: Color(0xFF10141E),
      backgroundMid: Color(0xFF181C28),
      backgroundBottom: Color(0xFF0E1218),
      surface: Color(0xFF1E2232),
      surfaceRaised: Color(0xFF262A3C),
      surfaceHighlight: Color(0xFF2E3248),
      panel: Color(0xFF0C1018),
      outline: Color(0xFF323A52),
      textPrimary: Color(0xFFF0F2F8),
      textSecondary: Color(0xFFCCD0E0),
      textMuted: Color(0xFF7880A0),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.45, 1.0],
        colors: [Color(0xFF10141E), Color(0xFF181C28), Color(0xFF0E1218)],
      ),
      heroGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.5, 1.0],
        colors: [Color(0xFF080C14), Color(0xFF10141E), Color(0xFF0C1018)],
      ),
      heroTextColor: Colors.white,
    ),
  ),

  // 8 — deep violet / cosmic purple
  GalleryItem(
    assetPath: 'assets/images/gallery_8.jpeg',
    label: 'Cosmos',
    darkPalette: AppPaletteData(
      backgroundTop: Color(0xFF120818),
      backgroundMid: Color(0xFF1C1028),
      backgroundBottom: Color(0xFF160A20),
      surface: Color(0xFF201430),
      surfaceRaised: Color(0xFF2A1C3C),
      surfaceHighlight: Color(0xFF342448),
      panel: Color(0xFF0E0614),
      outline: Color(0xFF3C2858),
      textPrimary: Color(0xFFF5F0E1),
      textSecondary: Color(0xFFDDC8F8),
      textMuted: Color(0xFF9070B8),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.45, 1.0],
        colors: [Color(0xFF120818), Color(0xFF1C1028), Color(0xFF160A20)],
      ),
      heroGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.5, 1.0],
        colors: [Color(0xFF0A0410), Color(0xFF120818), Color(0xFF0E0614)],
      ),
      heroTextColor: Colors.white,
    ),
  ),

  // 9 — earthy terracotta / desert sand
  GalleryItem(
    assetPath: 'assets/images/gallery_9.jpeg',
    label: 'Desert',
    darkPalette: AppPaletteData(
      backgroundTop: Color(0xFF1E1208),
      backgroundMid: Color(0xFF281A0E),
      backgroundBottom: Color(0xFF1A1006),
      surface: Color(0xFF2C1E12),
      surfaceRaised: Color(0xFF36261A),
      surfaceHighlight: Color(0xFF402E22),
      panel: Color(0xFF140C04),
      outline: Color(0xFF4A3020),
      textPrimary: Color(0xFFF5F0E1),
      textSecondary: Color(0xFFE8D4B8),
      textMuted: Color(0xFF9A8060),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.45, 1.0],
        colors: [Color(0xFF1E1208), Color(0xFF281A0E), Color(0xFF1A1006)],
      ),
      heroGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.5, 1.0],
        colors: [Color(0xFF120C04), Color(0xFF1E1208), Color(0xFF160E06)],
      ),
      heroTextColor: Colors.white,
    ),
  ),
];

class GalleryThemeService extends ChangeNotifier {
  GalleryThemeService._();
  static final GalleryThemeService instance = GalleryThemeService._();

  int _index = 0;
  int get index => _index;
  GalleryItem get current => galleryItems[_index];

  Future<void> loadFromDb() async {
    final stored = await DBHelper.getSetting('gallery_theme_index');
    final i = (int.tryParse(stored ?? '0') ?? 0).clamp(0, galleryItems.length - 1);
    _index = i;
    AppPalette.applyGalleryTheme(galleryItems[i].darkPalette);
  }

  Future<void> setIndex(int i) async {
    _index = i.clamp(0, galleryItems.length - 1);
    AppPalette.applyGalleryTheme(galleryItems[_index].darkPalette);
    await DBHelper.setSetting('gallery_theme_index', _index.toString());
    notifyListeners();
  }
}

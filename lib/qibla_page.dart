import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import 'app_palette.dart';

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  double? _qiblaBearing;
  double _compassHeading = 0;
  bool _activated = false;
  bool _calibrating = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _calibrating = true;
      _error = null;
      _activated = false;
      _qiblaBearing = null;
    });

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (!mounted) return;
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      setState(() {
        _error =
            'Location permission is required to calculate the Qibla direction.';
        _calibrating = false;
      });
      return;
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Could not get your location.\nPlease make sure location is enabled and try again.';
        _calibrating = false;
      });
      return;
    }

    if (!mounted) return;

    final bearing = Qibla(
      Coordinates(position.latitude, position.longitude),
    ).direction;

    setState(() {
      _qiblaBearing = bearing;
      _activated = true;
      _calibrating = false;
    });

    // Live compass requires a physical sensor — not available in web browsers.
    if (kIsWeb) return;

    final events = FlutterCompass.events;
    if (events == null) {
      setState(() => _error = 'No compass sensor found on this device.');
      return;
    }

    events.listen((CompassEvent event) {
      if (mounted && event.heading != null) {
        setState(() => _compassHeading = event.heading!);
      }
    });
  }

  /// Bearing in radians for Transform.rotate (positive = clockwise).
  double get _rotationAngle {
    if (_qiblaBearing == null) return 0;
    return (_qiblaBearing! - _compassHeading) * math.pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _GradientBackground(),
          const CustomPaint(painter: _MapGridPainter()),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const Text(
          'Qibla Compass',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.explore_off,
                color: AppPalette.textMuted,
                size: 56,
              ),
              const SizedBox(height: 20),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _initialize,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _activated ? () => Navigator.of(context).pop() : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          const SizedBox(height: 28),
          Text(
            _calibrating
                ? 'Finding your location…'
                : 'Your Qibla has been activated',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _calibrating
                ? 'Please wait'
                : kIsWeb
                ? 'Direction shown · device compass not available in browser'
                : 'Tap to Continue',
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          _buildCompass(),
          if (kIsWeb && _qiblaBearing != null) ...[
            const SizedBox(height: 16),
            Text(
              '${_qiblaBearing!.toStringAsFixed(1)}° from North',
              style: const TextStyle(
                color: AppPalette.accent,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Spacer(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCompass() {
    const compassDiameter = 260.0;
    const badgeSize = 52.0;
    const stalkHeight = 18.0;
    const totalHeight = compassDiameter + badgeSize + stalkHeight;

    return Transform.rotate(
      angle: _rotationAngle,
      child: SizedBox(
        width: compassDiameter,
        height: totalHeight,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            _KaabaBadge(size: badgeSize),
            Positioned(
              top: badgeSize - 1,
              child: Container(
                width: 3,
                height: stalkHeight + 2,
                decoration: const BoxDecoration(color: AppPalette.accent),
              ),
            ),
            Positioned(
              top: badgeSize + stalkHeight,
              child: CustomPaint(
                size: const Size(compassDiameter, compassDiameter),
                painter: _CompassPainter(),
              ),
            ),
            if (_calibrating)
              Positioned(
                top: badgeSize + stalkHeight + compassDiameter / 2 - 20,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: AppPalette.accent,
                    strokeWidth: 3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Kaaba badge ────────────────────────────────────────────────────────────

class _KaabaBadge extends StatelessWidget {
  const _KaabaBadge({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppPalette.accent, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppPalette.accent.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(child: Text('🕋', style: TextStyle(fontSize: 26))),
    );
  }
}

// ── Compass disc painter ───────────────────────────────────────────────────

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawCircle(
      c,
      r - 4,
      Paint()
        ..color = AppPalette.surface
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      c,
      r - 4,
      Paint()
        ..color = Colors.grey.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    _ring(canvas, c, r * 0.84);
    _ring(canvas, c, r * 0.61);
    _drawTicks(canvas, c, r);
    _drawStarPattern(canvas, c, r * 0.50);
    _drawNeedle(canvas, c, r);
    _drawCardinals(canvas, c, r);

    canvas.drawCircle(c, 9, Paint()..color = Colors.white);
    canvas.drawCircle(c, 6, Paint()..color = AppPalette.accent);
  }

  void _ring(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawTicks(Canvas canvas, Offset c, double r) {
    for (int i = 0; i < 72; i++) {
      final deg = i * 5.0;
      final isCardinal = deg % 90 == 0;
      final isMajor = deg % 45 == 0;
      final len = isCardinal ? r * 0.13 : (isMajor ? r * 0.08 : r * 0.04);
      final outer = r * 0.84;
      final angle = deg * math.pi / 180;
      final sinA = math.sin(angle);
      final cosA = math.cos(angle);
      canvas.drawLine(
        Offset(c.dx + (outer - len) * sinA, c.dy - (outer - len) * cosA),
        Offset(c.dx + outer * sinA, c.dy - outer * cosA),
        Paint()
          ..color = isCardinal
              ? Colors.white.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.28)
          ..strokeWidth = isCardinal ? 2.0 : 1.0,
      );
    }
  }

  void _drawStarPattern(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const points = 8;
    final inner = r * 0.4;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final angle = i * math.pi / points;
      final rr = i.isEven ? r : inner;
      final x = c.dx + rr * math.sin(angle);
      final y = c.dy - rr * math.cos(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawNeedle(Canvas canvas, Offset c, double r) {
    final upper = Path()
      ..moveTo(c.dx, c.dy - r * 0.72)
      ..lineTo(c.dx + r * 0.085, c.dy)
      ..lineTo(c.dx - r * 0.085, c.dy)
      ..close();

    final lower = Path()
      ..moveTo(c.dx, c.dy + r * 0.55)
      ..lineTo(c.dx + r * 0.085, c.dy)
      ..lineTo(c.dx - r * 0.085, c.dy)
      ..close();

    canvas.drawPath(
      upper,
      Paint()
        ..color = AppPalette.accent
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      upper,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.drawPath(
      lower,
      Paint()
        ..color = AppPalette.surfaceHighlight
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      lower,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawCardinals(Canvas canvas, Offset c, double r) {
    const labels = ['N', 'E', 'S', 'W'];
    const angles = [0.0, 90.0, 180.0, 270.0];
    final labelR = r * 0.68;

    for (int i = 0; i < labels.length; i++) {
      final angle = angles[i] * math.pi / 180;
      final pos = Offset(
        c.dx + labelR * math.sin(angle),
        c.dy - labelR * math.cos(angle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Background ─────────────────────────────────────────────────────────────

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppPalette.backgroundGradient),
    );
  }
}

// Draws a subtle lat/lon grid over the top portion of the screen.
class _MapGridPainter extends CustomPainter {
  const _MapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.6;
    final limit = size.height * 0.42;
    for (double y = 0; y < limit; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, limit), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

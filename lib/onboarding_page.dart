import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googlecast/googlecast.dart';

import 'app_palette.dart';
import 'db_helper.dart';
import 'notification_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const String _onboardingKey = 'onboarding_complete';

  final _googleSignIn = GoogleSignIn(scopes: ['email']);

  int _step = 0; // 0 = welcome, 1 = discovery, 2 = done
  GoogleSignInAccount? _account;
  bool _signingIn = false;
  bool _discovering = false;
  List<String> _devices = [];
  String? _errorMessage;
  Timer? _discoveryTimer;

  @override
  void initState() {
    super.initState();
    // Silently try to restore previous sign-in (no UI prompt).
    if (defaultTargetPlatform == TargetPlatform.android) {
      _googleSignIn
          .signInSilently()
          .then((account) {
            if (mounted && account != null) {
              setState(() => _account = account);
            }
          })
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _signingIn = true;
      _errorMessage = null;
    });
    try {
      final account = await _googleSignIn.signIn();
      if (!mounted) return;
      setState(() {
        _account = account;
        _signingIn = false;
      });
      await _startSpeakerDiscovery();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _signingIn = false;
        _errorMessage = 'Sign-in failed: $e';
      });
    }
  }

  Future<void> _startSpeakerDiscovery() async {
    setState(() {
      _step = 1;
      _discovering = true;
      _devices = [];
    });

    try {
      await GoogleChromeCast.startDiscovery();
    } catch (_) {}

    // Poll every second for up to 12 seconds.
    _discoveryTimer?.cancel();
    int elapsed = 0;
    _discoveryTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      elapsed++;
      final devices = await GoogleChromeCast.getDiscoveredDevices();
      if (!mounted) return;
      setState(() => _devices = devices);
      if (elapsed >= 12) {
        _discoveryTimer?.cancel();
        if (mounted) setState(() => _discovering = false);
      }
    });
  }

  Future<void> _refreshDiscovery() async {
    _discoveryTimer?.cancel();
    setState(() {
      _discovering = true;
      _devices = [];
    });
    try {
      await GoogleChromeCast.startDiscovery();
    } catch (_) {}
    int elapsed = 0;
    _discoveryTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      elapsed++;
      final devices = await GoogleChromeCast.getDiscoveredDevices();
      if (!mounted) return;
      setState(() => _devices = devices);
      if (elapsed >= 10) {
        _discoveryTimer?.cancel();
        if (mounted) setState(() => _discovering = false);
      }
    });
  }

  // onboarding_page.dart - Update the _selectDevice method
  Future<void> _selectDevice(String deviceName) async {
    _discoveryTimer?.cancel();

    // 1. Store the exact device name for the background service to find
    await DBHelper.setSetting(
      NotificationService.preferredCastSpeakerNameKey,
      deviceName,
    );

    // 2. Explicitly set the route to Google Cast
    await DBHelper.setSetting(
      'notification_speaker_route',
      NotificationService.speakerGoogleCast,
    );

    // 3. HANDSHAKE: Force a connection now. This primes the native
    // Cast SDK to remember this device's route.
    try {
      await GoogleChromeCast.reconnectToDevice(deviceName);
    } catch (e) {
      debugPrint('Handshake failed, but name is saved: $e');
    }

    await _finishOnboarding();
  }

  Future<void> _finishOnboarding() async {
    _discoveryTimer?.cancel();
    await DBHelper.setSetting(_onboardingKey, 'true');
    if (!mounted) return;
    setState(() => _step = 2);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: switch (_step) {
            0 => _buildWelcome(),
            1 => _buildDiscovery(),
            _ => _buildDone(),
          },
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          const Icon(Icons.mosque, size: 72, color: AppPalette.accent),
          const SizedBox(height: 24),
          const Text(
            'Athan – Call to Success',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sign in with your Google account to find and configure your Google Home or Chromecast speaker for automatic athan playback.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 2),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_account != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPalette.outline),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppPalette.accent,
                    child: Text(
                      (_account!.displayName ?? _account!.email)[0]
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_account!.displayName != null)
                          Text(
                            _account!.displayName!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        Text(
                          _account!.email,
                          style: const TextStyle(
                            color: AppPalette.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _googleSignIn.signOut().then((_) {
                      if (mounted) setState(() => _account = null);
                    }),
                    child: const Text('Switch'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _startSpeakerDiscovery,
              icon: const Icon(Icons.speaker),
              label: const Text('Find My Speakers'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ] else ...[
            FilledButton(
              onPressed: _signingIn ? null : _signIn,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
              ),
              child: _signingIn
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppPalette.accent,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://www.google.com/favicon.ico',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.login, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: _signingIn ? null : _startSpeakerDiscovery,
            child: const Text(
              'Skip — discover speakers without signing in',
              style: TextStyle(color: AppPalette.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildDiscovery() {
    final accountLabel = _account != null
        ? 'Signed in as ${_account!.email}'
        : 'Scanning local network…';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Text(
            'Select a Speaker',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            accountLabel,
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          if (_discovering) ...[
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppPalette.accent,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Scanning for speakers…',
                  style: TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: _devices.isEmpty && !_discovering
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.speaker_outlined,
                        size: 48,
                        color: AppPalette.textMuted,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No speakers found',
                        style: TextStyle(
                          color: AppPalette.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Make sure your phone and Google speaker\nare on the same Wi-Fi network.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _refreshDiscovery,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan Again'),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: _devices.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppPalette.outline),
                    itemBuilder: (context, i) {
                      final name = _devices[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppPalette.surfaceRaised,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.speaker,
                            color: AppPalette.accent,
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'Google / Chromecast speaker',
                          style: TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppPalette.textMuted,
                        ),
                        onTap: () => _selectDevice(name),
                      );
                    },
                  ),
          ),
          if (_devices.isNotEmpty && !_discovering)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: OutlinedButton.icon(
                onPressed: _refreshDiscovery,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Scan Again'),
              ),
            ),
          TextButton(
            onPressed: _finishOnboarding,
            child: const Text(
              'Skip speaker setup',
              style: TextStyle(color: AppPalette.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDone() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 72, color: AppPalette.accent),
          SizedBox(height: 20),
          Text(
            'All set!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

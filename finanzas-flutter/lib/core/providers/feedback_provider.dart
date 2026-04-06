import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSoundKey = 'pref_sound_enabled';
const _kHapticKey = 'pref_haptic_enabled';

/// Whether sound feedback is enabled (default: true)
final soundEnabledProvider = StateNotifierProvider<BoolPrefNotifier, bool>(
  (ref) => BoolPrefNotifier(_kSoundKey, defaultValue: true),
);

/// Whether haptic feedback is enabled (default: true)
final hapticEnabledProvider = StateNotifierProvider<BoolPrefNotifier, bool>(
  (ref) => BoolPrefNotifier(_kHapticKey, defaultValue: true),
);

class BoolPrefNotifier extends StateNotifier<bool> {
  final String key;

  BoolPrefNotifier(this.key, {bool defaultValue = true}) : super(defaultValue) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(key) ?? state;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, state);
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, state);
  }
}

/// Haptic feedback types with different intensities per action type
enum HapticType {
  /// Navigate between tabs, scroll selection
  selection,
  /// Tap buttons, open sheets, toggle
  light,
  /// Confirm action, add item, FAB press
  medium,
  /// Delete, destructive action
  heavy,
}

/// Sound types mapped to different UI actions
enum SoundType {
  /// Tab change, navigation
  nav,
  /// Button tap, toggle, open sheet
  tap,
  /// Confirm save, add, success
  success,
}

/// Perform haptic feedback respecting user preference.
/// Use from widgets that have a WidgetRef.
void appHaptic(WidgetRef ref, {HapticType type = HapticType.light}) {
  if (!ref.read(hapticEnabledProvider)) return;
  _doHaptic(type);
}

/// Play a UI sound respecting user preference.
void appSound(WidgetRef ref, {SoundType type = SoundType.tap}) {
  if (!ref.read(soundEnabledProvider)) return;
  _playSound(type);
}

// ── Shared audio player (reused, con ReleaseMode.stop para sonidos cortos de UI) ──
final AudioPlayer _audioPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

void _playSound(SoundType type) async {
  try {
    final String asset;
    switch (type) {
      case SoundType.nav:
        asset = 'sounds/nav.wav';
      case SoundType.tap:
        asset = 'sounds/tap.wav';
      case SoundType.success:
        asset = 'sounds/success.wav';
    }
    // Parar primero asegura reproducción inmediata en Android
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource(asset), volume: 0.45);
  } catch (_) {
    // Silencioso — el sonido es decorativo, no debe crashear la app
  }
}

/// Internal haptic executor
void _doHaptic(HapticType type) {
  switch (type) {
    case HapticType.light:
      HapticFeedback.lightImpact();
    case HapticType.medium:
      HapticFeedback.mediumImpact();
    case HapticType.heavy:
      HapticFeedback.heavyImpact();
    case HapticType.selection:
      HapticFeedback.selectionClick();
  }
}

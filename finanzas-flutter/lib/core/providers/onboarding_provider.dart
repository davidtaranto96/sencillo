import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingKey = 'onboarding_v1_complete';

final onboardingProvider =
    ChangeNotifierProvider<OnboardingController>((ref) {
  return OnboardingController();
});

/// Tracks whether the user has completed the onboarding flow.
/// Loads from SharedPreferences asynchronously; exposes [isLoaded] so
/// the app can show a dark splash while waiting.
class OnboardingController extends ChangeNotifier {
  bool _isComplete = false;
  bool _isLoaded = false;

  bool get isComplete => _isComplete;
  bool get isLoaded => _isLoaded;

  OnboardingController() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isComplete = prefs.getBool(_kOnboardingKey) ?? false;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> complete() async {
    _isComplete = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingKey, true);
  }

  Future<void> reset() async {
    _isComplete = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOnboardingKey);
  }
}

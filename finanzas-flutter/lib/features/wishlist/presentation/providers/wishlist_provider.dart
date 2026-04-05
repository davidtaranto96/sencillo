import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/wishlist_service.dart';
import '../../domain/models/wishlist_item.dart';

/// Real wishlist stream from DB (active items only)
final activeWishlistProvider = StreamProvider<List<WishlistItem>>((ref) {
  return ref.watch(wishlistServiceProvider).watchActive();
});

/// All wishlist items (including purchased)
final allWishlistProvider = StreamProvider<List<WishlistItem>>((ref) {
  return ref.watch(wishlistServiceProvider).watchAll();
});

/// Hourly rate from real salary (monthlySalary / 160)
final hourlyRateProvider = Provider<double?>((ref) {
  final profile = ref.watch(userProfileStreamProvider).valueOrNull;
  if (profile?.monthlySalary != null && profile!.monthlySalary! > 0) {
    return profile.monthlySalary! / 160;
  }
  return null;
});

/// Global reminder days setting (persisted in SharedPreferences)
final globalReminderDaysProvider =
    StateNotifierProvider<ReminderDaysNotifier, int>((ref) {
  return ReminderDaysNotifier();
});

class ReminderDaysNotifier extends StateNotifier<int> {
  ReminderDaysNotifier() : super(15) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('wishlist_reminder_days');
    if (saved != null && mounted) {
      state = saved;
    }
  }

  Future<void> setDays(int days) async {
    state = days.clamp(5, 90);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('wishlist_reminder_days', state);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAccountOrder = 'account_order';

class AccountOrderNotifier extends StateNotifier<List<String>> {
  AccountOrderNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final order = prefs.getStringList(_kAccountOrder);
    if (order != null) state = order;
  }

  Future<void> setOrder(List<String> ids) async {
    state = ids;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kAccountOrder, ids);
  }
}

final accountOrderProvider =
    StateNotifierProvider<AccountOrderNotifier, List<String>>(
        (ref) => AccountOrderNotifier());

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All available tab IDs in default order (matches branch indices for 0-4)
const kAllTabs = [
  'home',
  'transactions',
  'budget',
  'goals',
  'more',
  'monthly_overview',
  'people',
  'wishlist',
  'reports',
  'accounts',
  'savings',
];

const kDefaultTabs = ['home', 'transactions', 'budget', 'goals', 'more'];
const kAlwaysVisibleTabs = {'home', 'more'};
const kMaxVisibleTabs = 6;

const kTabInfo = <String, ({String label, IconData icon})>{
  'home': (label: 'Inicio', icon: Icons.home_rounded),
  'transactions': (label: 'Movimientos', icon: Icons.swap_horiz_rounded),
  'budget': (label: 'Presupuesto', icon: Icons.donut_large_rounded),
  'goals': (label: 'Metas', icon: Icons.flag_rounded),
  'more': (label: 'Más', icon: Icons.grid_view_rounded),
  'monthly_overview': (label: 'Mes', icon: Icons.calendar_month_rounded),
  'people': (label: 'Amigos', icon: Icons.people_rounded),
  'wishlist': (label: 'Antojos', icon: Icons.shopping_cart_rounded),
  'reports': (label: 'Análisis', icon: Icons.bar_chart_rounded),
  'accounts': (label: 'Cuentas', icon: Icons.account_balance_rounded),
  'savings': (label: 'Ahorros', icon: Icons.savings_rounded),
};

final tabConfigProvider =
    StateNotifierProvider<TabConfigNotifier, List<String>>((ref) {
  return TabConfigNotifier();
});

class TabConfigNotifier extends StateNotifier<List<String>> {
  TabConfigNotifier() : super(List.from(kDefaultTabs)) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('nav_tabs');
    if (saved != null && saved.isNotEmpty) {
      final valid = saved.where((t) => kAllTabs.contains(t)).toList();
      for (final req in kAlwaysVisibleTabs) {
        if (!valid.contains(req)) valid.add(req);
      }
      if (valid.length >= 2 && valid.length <= kMaxVisibleTabs) {
        state = valid;
      }
    }
  }

  bool isEnabled(String tabId) => state.contains(tabId);

  Future<void> toggleTab(String tabId) async {
    if (kAlwaysVisibleTabs.contains(tabId)) return;
    final current = List<String>.from(state);
    if (current.contains(tabId)) {
      if (current.length <= 3) return;
      current.remove(tabId);
    } else {
      if (current.length >= kMaxVisibleTabs) return;
      final moreIdx = current.indexOf('more');
      if (moreIdx >= 0 && moreIdx == current.length - 1) {
        current.insert(moreIdx, tabId);
      } else {
        current.add(tabId);
      }
    }
    state = current;
    await _save(current);
  }

  /// Replaces the full ordered list of enabled tabs.
  Future<void> setOrder(List<String> orderedTabs) async {
    final valid = orderedTabs.where((t) => kAllTabs.contains(t)).toList();
    for (final req in kAlwaysVisibleTabs) {
      if (!valid.contains(req)) valid.add(req);
    }
    if (valid.length > kMaxVisibleTabs) {
      state = valid.sublist(0, kMaxVisibleTabs);
    } else {
      state = valid;
    }
    await _save(state);
  }

  Future<void> _save(List<String> tabs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('nav_tabs', tabs);
  }

  Future<void> reset() async {
    state = List.from(kDefaultTabs);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nav_tabs');
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Budget distribution percentages (must sum to 100).
class BudgetDistribution {
  final int needsPct;
  final int wantsPct;
  final int savingsPct;

  const BudgetDistribution({
    this.needsPct = 50,
    this.wantsPct = 30,
    this.savingsPct = 20,
  });

  BudgetDistribution copyWith({int? needsPct, int? wantsPct, int? savingsPct}) {
    return BudgetDistribution(
      needsPct: needsPct ?? this.needsPct,
      wantsPct: wantsPct ?? this.wantsPct,
      savingsPct: savingsPct ?? this.savingsPct,
    );
  }
}

/// Category → bucket mapping
enum SpendingBucket { needs, wants }

const Map<String, SpendingBucket> categoryBucketMap = {
  // Necesidades
  'food': SpendingBucket.needs,
  'cat_alim': SpendingBucket.needs,
  'transport': SpendingBucket.needs,
  'cat_transp': SpendingBucket.needs,
  'health': SpendingBucket.needs,
  'cat_salud': SpendingBucket.needs,
  'home': SpendingBucket.needs,
  'services': SpendingBucket.needs,
  'education': SpendingBucket.needs,
  // Gustos
  'entertainment': SpendingBucket.wants,
  'cat_entret': SpendingBucket.wants,
  'shopping': SpendingBucket.wants,
  'other_expense': SpendingBucket.wants,
};

class DistributionNotifier extends StateNotifier<BudgetDistribution> {
  DistributionNotifier() : super(const BudgetDistribution()) {
    _load();
  }

  static const _kNeeds = 'dist_needs_pct';
  static const _kWants = 'dist_wants_pct';
  static const _kSavings = 'dist_savings_pct';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final n = prefs.getInt(_kNeeds);
    if (n != null) {
      state = BudgetDistribution(
        needsPct: n,
        wantsPct: prefs.getInt(_kWants) ?? 30,
        savingsPct: prefs.getInt(_kSavings) ?? 20,
      );
    }
  }

  Future<void> update({required int needs, required int wants, required int savings}) async {
    state = BudgetDistribution(needsPct: needs, wantsPct: wants, savingsPct: savings);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNeeds, needs);
    await prefs.setInt(_kWants, wants);
    await prefs.setInt(_kSavings, savings);
  }
}

final distributionProvider =
    StateNotifierProvider<DistributionNotifier, BudgetDistribution>(
        (ref) => DistributionNotifier());

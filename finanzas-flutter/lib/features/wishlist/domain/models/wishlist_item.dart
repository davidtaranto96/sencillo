import 'package:equatable/equatable.dart';

class WishlistItem extends Equatable {
  final String id;
  final String title;
  final double estimatedCost;
  final String? note;
  final String? url;
  final int installments;
  final bool hasPromo;
  final DateTime createdAt;
  final bool isPurchased;
  final DateTime? purchasedAt;
  final String? purchaseMethod; // 'account', 'cash', 'regalo'
  final String? purchaseAccountId;
  final String? linkedBudgetId;
  final int? reminderDays; // per-item override; null = use global
  final DateTime? reminderSnoozedUntil;
  final bool reminderDismissed;

  const WishlistItem({
    required this.id,
    required this.title,
    required this.estimatedCost,
    this.note,
    this.url,
    this.installments = 1,
    this.hasPromo = false,
    required this.createdAt,
    this.isPurchased = false,
    this.purchasedAt,
    this.purchaseMethod,
    this.purchaseAccountId,
    this.linkedBudgetId,
    this.reminderDays,
    this.reminderSnoozedUntil,
    this.reminderDismissed = false,
  });

  WishlistItem copyWith({
    String? id,
    String? title,
    double? estimatedCost,
    String? note,
    String? url,
    int? installments,
    bool? hasPromo,
    DateTime? createdAt,
    bool? isPurchased,
    DateTime? purchasedAt,
    String? purchaseMethod,
    String? purchaseAccountId,
    String? linkedBudgetId,
    int? reminderDays,
    DateTime? reminderSnoozedUntil,
    bool? reminderDismissed,
  }) {
    return WishlistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      note: note ?? this.note,
      url: url ?? this.url,
      installments: installments ?? this.installments,
      hasPromo: hasPromo ?? this.hasPromo,
      createdAt: createdAt ?? this.createdAt,
      isPurchased: isPurchased ?? this.isPurchased,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      purchaseMethod: purchaseMethod ?? this.purchaseMethod,
      purchaseAccountId: purchaseAccountId ?? this.purchaseAccountId,
      linkedBudgetId: linkedBudgetId ?? this.linkedBudgetId,
      reminderDays: reminderDays ?? this.reminderDays,
      reminderSnoozedUntil: reminderSnoozedUntil ?? this.reminderSnoozedUntil,
      reminderDismissed: reminderDismissed ?? this.reminderDismissed,
    );
  }

  @override
  List<Object?> get props => [
        id, title, estimatedCost, note, url, installments, hasPromo,
        createdAt, isPurchased, purchasedAt, purchaseMethod,
        purchaseAccountId, linkedBudgetId, reminderDays,
        reminderSnoozedUntil, reminderDismissed,
      ];
}

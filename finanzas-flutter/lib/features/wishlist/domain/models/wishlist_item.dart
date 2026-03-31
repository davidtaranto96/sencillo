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

  const WishlistItem({
    required this.id,
    required this.title,
    required this.estimatedCost,
    this.note,
    this.url,
    this.installments = 1,
    this.hasPromo = false,
    required this.createdAt,
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
    );
  }

  @override
  List<Object?> get props => [id, title, estimatedCost, note, url, installments, hasPromo, createdAt];
}

import 'package:equatable/equatable.dart';

class WishlistItem extends Equatable {
  final String id;
  final String title;
  final double estimatedCost;
  final String? note;
  final String? url;
  final DateTime createdAt;

  const WishlistItem({
    required this.id,
    required this.title,
    required this.estimatedCost,
    this.note,
    this.url,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, title, estimatedCost, note, url, createdAt];
}

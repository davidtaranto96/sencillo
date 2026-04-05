import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/logic/wishlist_service.dart';
import '../../domain/models/wishlist_item.dart';
import '../providers/wishlist_provider.dart';

class AddWishlistBottomSheet extends ConsumerStatefulWidget {
  final WishlistItem? itemToEdit;

  const AddWishlistBottomSheet({super.key, this.itemToEdit});

  static Future<void> show(BuildContext context, {WishlistItem? itemToEdit}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddWishlistBottomSheet(itemToEdit: itemToEdit),
    );
  }

  @override
  ConsumerState<AddWishlistBottomSheet> createState() =>
      _AddWishlistBottomSheetState();
}

class _AddWishlistBottomSheetState
    extends ConsumerState<AddWishlistBottomSheet> {
  final _titleController = TextEditingController();
  final _costController = TextEditingController();
  final _noteController = TextEditingController();
  final _urlController = TextEditingController();
  int _installments = 1;
  bool _hasPromo = false;
  int? _reminderDays;
  bool _showExtras = false;

  bool get _isEditing => widget.itemToEdit != null;

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    if (item != null) {
      _titleController.text = item.title;
      _costController.text = item.estimatedCost.toInt().toString();
      _noteController.text = item.note ?? '';
      _urlController.text = item.url ?? '';
      _installments = item.installments;
      _hasPromo = item.hasPromo;
      _reminderDays = item.reminderDays;
      _showExtras = item.url?.isNotEmpty == true ||
          item.note?.isNotEmpty == true ||
          item.hasPromo ||
          item.reminderDays != null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _costController.dispose();
    _noteController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final globalDays = ref.watch(globalReminderDaysProvider);
    final effectiveDays = _reminderDays ?? globalDays;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 20),
      decoration: const BoxDecoration(
        color: Color(0xFF18181F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.add_shopping_cart_rounded,
                    color: AppTheme.colorWarning, size: 20),
                const SizedBox(width: 8),
                Text(
                  _isEditing
                      ? 'Editar Compra'
                      : 'Nueva Compra Inteligente',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title + Cost in a compact layout
            _CompactField(
              controller: _titleController,
              hint: 'Ej. PlayStation 5 Pro',
              label: '¿Qué querés comprar?',
            ),
            const SizedBox(height: 10),
            _CompactField(
              controller: _costController,
              hint: 'Ej. 1.200.000',
              label: 'Valor estimado',
              prefixText: '\$ ',
              keyboardType: TextInputType.number,
              formatters: [ThousandsSeparatorFormatter()],
            ),
            const SizedBox(height: 14),

            // Installments — compact row
            Text('¿Cómo lo pagarías?',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                _MiniChip('Contado', _installments == 1,
                    () => setState(() => _installments = 1)),
                const SizedBox(width: 6),
                _MiniChip('3 cuotas', _installments == 3,
                    () => setState(() => _installments = 3)),
                const SizedBox(width: 6),
                _MiniChip('6 cuotas', _installments == 6,
                    () => setState(() => _installments = 6)),
                const SizedBox(width: 6),
                _MiniChip('12 cuotas', _installments == 12,
                    () => setState(() => _installments = 12)),
              ],
            ),

            const SizedBox(height: 12),

            // Expandable extras section
            GestureDetector(
              onTap: () => setState(() => _showExtras = !_showExtras),
              child: Row(
                children: [
                  Icon(
                    _showExtras
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.white38,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Más opciones',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_hasPromo)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.colorIncome.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Promo',
                          style: TextStyle(
                              color: AppTheme.colorIncome, fontSize: 10)),
                    ),
                ],
              ),
            ),

            if (_showExtras) ...[
              const SizedBox(height: 10),
              // URL
              _CompactField(
                controller: _urlController,
                hint: 'https://mercadolibre.com.ar/...',
                label: 'Link del producto',
                icon: Icons.link_rounded,
              ),
              const SizedBox(height: 8),
              // Note
              _CompactField(
                controller: _noteController,
                hint: 'Notas...',
                label: 'Nota',
                icon: Icons.note_rounded,
              ),
              const SizedBox(height: 8),

              // Promo + Reminder in a row
              Row(
                children: [
                  // Promo toggle
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _hasPromo = !_hasPromo),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: _hasPromo
                              ? AppTheme.colorIncome.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _hasPromo
                                ? AppTheme.colorIncome.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_offer_rounded,
                                size: 14,
                                color: _hasPromo
                                    ? AppTheme.colorIncome
                                    : Colors.white30),
                            const SizedBox(width: 6),
                            Text(
                              'Promo',
                              style: TextStyle(
                                color: _hasPromo
                                    ? AppTheme.colorIncome
                                    : Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Reminder badge
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active_rounded,
                              color: Colors.white30, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Recordar: $effectiveDays d',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 14,
                              icon: const Icon(Icons.remove_rounded,
                                  color: Colors.white38),
                              onPressed: effectiveDays > 5
                                  ? () => setState(() =>
                                      _reminderDays = (effectiveDays - 5)
                                          .clamp(5, 90))
                                  : null,
                            ),
                          ),
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 14,
                              icon: const Icon(Icons.add_rounded,
                                  color: Colors.white38),
                              onPressed: effectiveDays < 90
                                  ? () => setState(() =>
                                      _reminderDays = (effectiveDays + 5)
                                          .clamp(5, 90))
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.colorWarning,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _isEditing ? 'Guardar Cambios' : 'Agregar a Wishlist',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),

            // Delete button (edit mode only)
            if (_isEditing) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Eliminar',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.colorExpense,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _onDelete,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    final cost = parseFormattedAmount(_costController.text);
    if (_titleController.text.isEmpty || cost <= 0) return;

    final ws = ref.read(wishlistServiceProvider);

    try {
      if (_isEditing) {
        await ws.updateItem(
          widget.itemToEdit!.id,
          title: _titleController.text,
          estimatedCost: cost,
          note: _noteController.text.isEmpty ? null : _noteController.text,
          url: _urlController.text.isEmpty ? null : _urlController.text,
          installments: _installments,
          hasPromo: _hasPromo,
          reminderDays: _reminderDays,
        );
      } else {
        await ws.addItem(
          title: _titleController.text,
          estimatedCost: cost,
          note: _noteController.text.isEmpty ? null : _noteController.text,
          url: _urlController.text.isEmpty ? null : _urlController.text,
          installments: _installments,
          hasPromo: _hasPromo,
          reminderDays: _reminderDays,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _isEditing ? 'Compra actualizada' : 'Agregado a Wishlist'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _onDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2A),
        title: const Text('Eliminar', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Eliminar "${widget.itemToEdit!.title}" de tu lista?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.colorExpense),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(wishlistServiceProvider).deleteItem(widget.itemToEdit!.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eliminado de la lista')),
        );
      }
    }
  }
}

// ─── Compact text field ────────────────────────────────────
class _CompactField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String label;
  final String? prefixText;
  final TextInputType? keyboardType;
  final List<dynamic>? formatters;
  final IconData? icon;

  const _CompactField({
    required this.controller,
    required this.hint,
    required this.label,
    this.prefixText,
    this.keyboardType,
    this.formatters,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters?.cast(),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        labelText: label,
        labelStyle:
            const TextStyle(color: AppTheme.colorWarning, fontSize: 13),
        prefixText: prefixText,
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.white24, size: 18)
            : null,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.colorWarning),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
    );
  }
}

// ─── Mini installment chip ────────────────────────────────
class _MiniChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MiniChip(this.label, this.isSelected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.colorWarning.withValues(alpha: 0.15)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? AppTheme.colorWarning
                  : Colors.white.withValues(alpha: 0.12),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppTheme.colorWarning : Colors.white38,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
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
  ConsumerState<AddWishlistBottomSheet> createState() => _AddWishlistBottomSheetState();
}

class _AddWishlistBottomSheetState extends ConsumerState<AddWishlistBottomSheet> {
  final _titleController = TextEditingController();
  final _costController = TextEditingController();
  final _noteController = TextEditingController();
  final _urlController = TextEditingController();
  int _installments = 1;
  bool _hasPromo = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.itemToEdit?.title ?? '';
    _costController.text = widget.itemToEdit != null ? widget.itemToEdit!.estimatedCost.toInt().toString() : '';
    _noteController.text = widget.itemToEdit?.note ?? '';
    _urlController.text = widget.itemToEdit?.url ?? '';
    _installments = widget.itemToEdit?.installments ?? 1;
    _hasPromo = widget.itemToEdit?.hasPromo ?? false;
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

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding + 32),
      decoration: const BoxDecoration(
        color: Color(0xFF18181F),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.add_shopping_cart_rounded, color: AppTheme.colorWarning),
              const SizedBox(width: 8),
              Text(
                'Nueva Compra Inteligente',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ej. PlayStation 5 Pro',
              hintStyle: const TextStyle(color: Colors.white38),
              labelText: '¿Qué querés comprar?',
              labelStyle: const TextStyle(color: AppTheme.colorWarning),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.colorWarning),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _costController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ej. 1200000',
              prefixText: '\$ ',
              hintStyle: const TextStyle(color: Colors.white38),
              labelText: 'Valor estimado',
              labelStyle: const TextStyle(color: AppTheme.colorWarning),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.colorWarning),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('¿Cómo lo pagarías?', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              _InstallmentChip(
                label: 'Contado',
                isSelected: _installments == 1,
                onTap: () => setState(() => _installments = 1),
              ),
              const SizedBox(width: 8),
              _InstallmentChip(
                label: '3 Cuotas',
                isSelected: _installments == 3,
                onTap: () => setState(() => _installments = 3),
              ),
              const SizedBox(width: 8),
              _InstallmentChip(
                label: '6 Cuotas',
                isSelected: _installments == 6,
                onTap: () => setState(() => _installments = 6),
              ),
              const SizedBox(width: 8),
              _InstallmentChip(
                label: '12 Cuotas',
                isSelected: _installments == 12,
                onTap: () => setState(() => _installments = 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ej. https://mercadolibre.com.ar/item',
              hintStyle: const TextStyle(color: Colors.white38),
              labelText: 'Link del producto (Opcional)',
              labelStyle: const TextStyle(color: AppTheme.colorWarning),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.colorWarning),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _noteController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Notas...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppTheme.colorWarning),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Tiene promo/descuento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            value: _hasPromo,
            onChanged: (val) => setState(() => _hasPromo = val),
            activeThumbColor: AppTheme.colorWarning,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () {
                final cost = double.tryParse(_costController.text) ?? 0.0;
                if (_titleController.text.isEmpty || cost <= 0) return;

                if (widget.itemToEdit != null) {
                  ref.read(mockWishlistProvider.notifier).updateItem(
                    widget.itemToEdit!.copyWith(
                      title: _titleController.text,
                      estimatedCost: cost,
                      note: _noteController.text,
                      url: _urlController.text,
                      installments: _installments,
                      hasPromo: _hasPromo,
                    ),
                  );
                } else {
                  final newItem = WishlistItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: _titleController.text,
                    estimatedCost: cost,
                    createdAt: DateTime.now(),
                    note: _noteController.text,
                    url: _urlController.text,
                    installments: _installments,
                    hasPromo: _hasPromo,
                  );
                  ref.read(mockWishlistProvider.notifier).add(newItem);
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(widget.itemToEdit != null ? 'Compra actualizada' : 'Agregado a Wishlist')),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.colorWarning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(widget.itemToEdit != null ? 'Guardar Cambios' : 'Agregar a Wishlist', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallmentChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _InstallmentChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.colorWarning.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.colorWarning : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.colorWarning : Colors.white54,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

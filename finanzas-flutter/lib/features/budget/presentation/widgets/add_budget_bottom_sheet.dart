import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/budget.dart';

class AddBudgetBottomSheet extends StatefulWidget {
  final Budget? budgetToEdit;

  const AddBudgetBottomSheet({super.key, this.budgetToEdit});

  static Future<void> show(BuildContext context, {Budget? budgetToEdit}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddBudgetBottomSheet(budgetToEdit: budgetToEdit),
    );
  }

  @override
  State<AddBudgetBottomSheet> createState() => _AddBudgetBottomSheetState();
}

class _AddBudgetBottomSheetState extends State<AddBudgetBottomSheet> {
  late final TextEditingController _categoryController;
  late final TextEditingController _limitController;
  bool _isFixed = false;

  @override
  void initState() {
    super.initState();
    _categoryController = TextEditingController(text: widget.budgetToEdit?.categoryName ?? '');
    _limitController = TextEditingController(
        text: widget.budgetToEdit != null ? widget.budgetToEdit!.limitAmount.toInt().toString() : '');
    _isFixed = widget.budgetToEdit?.isFixed ?? false;
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.budgetToEdit != null;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding + 32),
      decoration: const BoxDecoration(
        color: Color(0xFF18181F),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(isEditing ? Icons.edit_rounded : Icons.pie_chart_rounded, color: AppTheme.colorTransfer),
              const SizedBox(width: 8),
              Text(
                isEditing ? 'Editar Presupuesto' : 'Añadir Presupuesto',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _categoryController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ej. Supermercado',
              hintStyle: const TextStyle(color: Colors.white38),
              labelText: 'Categoría',
              labelStyle: const TextStyle(color: AppTheme.colorTransfer),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.colorTransfer),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _limitController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ej. 80000',
              prefixText: '\$ ',
              hintStyle: const TextStyle(color: Colors.white38),
              labelText: 'Monto Límite',
              labelStyle: const TextStyle(color: AppTheme.colorTransfer),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.colorTransfer),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Gasto Fijo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            subtitle: const Text('Para alquiler, servicios, seguros, etc.', style: TextStyle(color: Colors.white54, fontSize: 13)),
            value: _isFixed,
            onChanged: (val) => setState(() => _isFixed = val),
            activeColor: AppTheme.colorTransfer,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEditing ? 'Presupuesto actualizado' : 'Presupuesto creado')),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.colorTransfer,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(isEditing ? 'Guardar Cambios' : 'Generar Presupuesto', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

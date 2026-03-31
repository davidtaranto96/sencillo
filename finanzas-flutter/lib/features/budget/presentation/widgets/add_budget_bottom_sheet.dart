import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/budget.dart';
import '../../../../core/utils/format_utils.dart'; // Just in case, though not strictly needed here


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
  IconData _selectedIcon = Icons.pie_chart_rounded;

  final List<IconData> _availableIcons = [
    Icons.pie_chart_rounded,
    Icons.shopping_cart_rounded,
    Icons.restaurant_rounded,
    Icons.directions_car_rounded,
    Icons.home_rounded,
    Icons.tv_rounded,
    Icons.fitness_center_rounded,
    Icons.health_and_safety_rounded,
    Icons.school_rounded,
    Icons.phone_iphone_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _categoryController = TextEditingController(text: widget.budgetToEdit?.categoryName ?? '');
    _limitController = TextEditingController(
        text: widget.budgetToEdit != null ? widget.budgetToEdit!.limitAmount.toInt().toString() : '');
    _isFixed = widget.budgetToEdit?.isFixed ?? false;
    _selectedIcon = widget.budgetToEdit?.icon ?? Icons.pie_chart_rounded;
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

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF18181F),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.colorTransfer.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_selectedIcon, color: AppTheme.colorTransfer),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Editar Presupuesto' : 'Añadir Presupuesto',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // --- Icon Picker ---
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableIcons.length,
                  itemBuilder: (context, index) {
                    final icon = _availableIcons[index];
                    final isSelected = icon == _selectedIcon;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = icon),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.colorTransfer.withValues(alpha: 0.2)
                              : Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.colorTransfer : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? AppTheme.colorTransfer : Colors.white38,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _categoryController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ej. Supermercado',
                  labelText: 'Categoría',
                  labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _limitController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  labelText: 'Monto Límite',
                  labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text(
                  'Gasto Fijo / Suscripción',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  'Ej. Alquiler, Netflix, Internet',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                value: _isFixed,
                onChanged: (val) => setState(() => _isFixed = val),
                activeThumbColor: AppTheme.colorTransfer,
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
                      SnackBar(
                        content: Text(isEditing ? 'Presupuesto actualizado' : 'Presupuesto creado'),
                      ),
                    );
                  },
                  child: Text(isEditing ? 'Guardar Cambios' : 'Crear Presupuesto'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

  }
}

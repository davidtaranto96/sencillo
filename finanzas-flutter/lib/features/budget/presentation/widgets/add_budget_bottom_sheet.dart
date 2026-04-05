import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/logic/budget_service.dart';
import '../../domain/models/budget.dart';

/// Predefined spending categories that match transaction categoryIds
/// used by the AI parser and manual input.
class SpendingCategory {
  final String id;
  final String name;
  final IconData icon;
  final int colorValue;
  final List<String> keywords;

  const SpendingCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
    this.keywords = const [],
  });
}

const _predefinedCategories = [
  SpendingCategory(
    id: 'food',
    name: 'Alimentación',
    icon: Icons.restaurant_rounded,
    colorValue: 0xFFFF9800,
    keywords: ['comida', 'super', 'almuerzo', 'cena', 'restaurant', 'delivery', 'rappi'],
  ),
  SpendingCategory(
    id: 'transport',
    name: 'Transporte',
    icon: Icons.directions_car_rounded,
    colorValue: 0xFF2196F3,
    keywords: ['nafta', 'uber', 'taxi', 'subte', 'colectivo', 'sube', 'peaje'],
  ),
  SpendingCategory(
    id: 'health',
    name: 'Salud',
    icon: Icons.health_and_safety_rounded,
    colorValue: 0xFFE91E63,
    keywords: ['médico', 'medico', 'psicólog', 'psicologo', 'farmacia', 'dentista', 'salud', 'obra social'],
  ),
  SpendingCategory(
    id: 'entertainment',
    name: 'Entretenimiento',
    icon: Icons.tv_rounded,
    colorValue: 0xFF9C27B0,
    keywords: ['netflix', 'spotify', 'cine', 'juego', 'disney', 'steam', 'teatro'],
  ),
  SpendingCategory(
    id: 'shopping',
    name: 'Compras',
    icon: Icons.shopping_cart_rounded,
    colorValue: 0xFFFF5722,
    keywords: ['ropa', 'zapatilla', 'tienda', 'compré', 'zara', 'nike'],
  ),
  SpendingCategory(
    id: 'home',
    name: 'Hogar',
    icon: Icons.home_rounded,
    colorValue: 0xFF795548,
    keywords: ['alquiler', 'expensas', 'luz', 'gas', 'agua'],
  ),
  SpendingCategory(
    id: 'services',
    name: 'Servicios',
    icon: Icons.phone_iphone_rounded,
    colorValue: 0xFF607D8B,
    keywords: ['internet', 'celular', 'gym', 'gimnasio', 'suscripción', 'plan'],
  ),
  SpendingCategory(
    id: 'education',
    name: 'Educación',
    icon: Icons.school_rounded,
    colorValue: 0xFF3F51B5,
    keywords: ['curso', 'libro', 'universidad', 'colegio', 'udemy'],
  ),
  SpendingCategory(
    id: 'other_expense',
    name: 'Otros',
    icon: Icons.pie_chart_rounded,
    colorValue: 0xFF6C63FF,
    keywords: [],
  ),
];

/// Intenta auto-detectar la categoría según lo que escriba el usuario.
SpendingCategory? _detectCategory(String text) {
  if (text.length < 3) return null;
  final lower = text.toLowerCase();
  for (final cat in _predefinedCategories) {
    for (final kw in cat.keywords) {
      if (lower.contains(kw)) return cat;
    }
  }
  return null;
}

class AddBudgetBottomSheet extends ConsumerStatefulWidget {
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
  ConsumerState<AddBudgetBottomSheet> createState() =>
      _AddBudgetBottomSheetState();
}

class _AddBudgetBottomSheetState extends ConsumerState<AddBudgetBottomSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _limitController;
  bool _isFixed = false;
  SpendingCategory? _selectedCategory;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.budgetToEdit;
    _nameController = TextEditingController(text: b?.categoryName ?? '');
    _limitController = TextEditingController(
        text: b != null ? b.limitAmount.toInt().toString() : '');
    _isFixed = b?.isFixed ?? false;

    if (b != null) {
      _selectedCategory = _predefinedCategories
          .where((c) => c.id == b.categoryId)
          .firstOrNull;
    }

    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (_selectedCategory != null) return; // no pisar selección manual
    final detected = _detectCategory(_nameController.text);
    if (detected != null) {
      setState(() => _selectedCategory = detected);
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountText = _limitController.text.trim();
    if (amountText.isEmpty) return;
    final amount = parseFormattedAmount(amountText);
    if (amount <= 0) return;

    final customName = _nameController.text.trim();
    if (_selectedCategory == null && customName.isEmpty) return;

    setState(() => _saving = true);
    final service = ref.read(budgetServiceProvider);
    final isEditing = widget.budgetToEdit != null;

    try {
      if (isEditing) {
        await service.updateBudget(
          widget.budgetToEdit!.id,
          widget.budgetToEdit!.categoryId,
          categoryName: customName.isNotEmpty ? customName : _selectedCategory?.name,
          limitAmount: amount,
          isFixed: _isFixed,
          colorValue: _selectedCategory?.colorValue,
          iconKey: _selectedCategory != null
              ? _iconKeyFromData(_selectedCategory!.icon)
              : null,
        );
      } else if (_selectedCategory != null) {
        await service.addBudgetForCategory(
          categoryId: _selectedCategory!.id,
          categoryName: customName.isNotEmpty ? customName : _selectedCategory!.name,
          limitAmount: amount,
          isFixed: _isFixed,
          colorValue: _selectedCategory!.colorValue,
          iconKey: _iconKeyFromData(_selectedCategory!.icon),
        );
      } else {
        await service.addBudget(
          categoryName: customName,
          limitAmount: amount,
          isFixed: _isFixed,
          colorValue: 0xFF6C63FF,
          iconKey: 'pie_chart',
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  static final _iconToKey = {
    Icons.restaurant_rounded: 'restaurant',
    Icons.directions_car_rounded: 'car',
    Icons.health_and_safety_rounded: 'health',
    Icons.tv_rounded: 'tv',
    Icons.shopping_cart_rounded: 'shopping_cart',
    Icons.home_rounded: 'home',
    Icons.phone_iphone_rounded: 'phone',
    Icons.school_rounded: 'education',
    Icons.pie_chart_rounded: 'pie_chart',
  };

  String _iconKeyFromData(IconData icon) => _iconToKey[icon] ?? 'pie_chart';

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.budgetToEdit != null;
    final accentColor = _selectedCategory != null
        ? Color(_selectedCategory!.colorValue)
        : AppTheme.colorTransfer;

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
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _selectedCategory?.icon ?? Icons.pie_chart_rounded,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Editar Presupuesto' : 'Nuevo Presupuesto',
                          style: GoogleFonts.inter(
                            fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEditing
                              ? 'Ajustá categoría o límite'
                              : 'Controlá cuánto gastás por categoría',
                          style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Categoría (scroll horizontal) ──
              Text('Categoría', style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: Colors.white54, letterSpacing: 0.5,
              )),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _predefinedCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _predefinedCategories[index];
                    final isSelected = _selectedCategory?.id == cat.id;
                    final color = Color(cat.colorValue);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (isSelected) {
                          _selectedCategory = null;
                        } else {
                          _selectedCategory = cat;
                          if (_nameController.text.isEmpty) {
                            _nameController.text = cat.name;
                          }
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.2)
                              : Colors.white.withAlpha(8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? color : Colors.white.withAlpha(15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 16,
                                color: isSelected ? color : Colors.white38),
                            const SizedBox(width: 6),
                            Text(cat.name, style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500,
                              color: isSelected ? color : Colors.white54,
                            )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // ── Nombre ──
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Ej. Psicóloga, Netflix, Alquiler',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                  labelText: 'Nombre',
                  labelStyle: TextStyle(color: accentColor),
                  prefixIcon: Icon(
                    _selectedCategory?.icon ?? Icons.label_outline_rounded,
                    color: accentColor.withValues(alpha: 0.6), size: 20,
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 14),

              // ── Monto ──
              TextField(
                controller: _limitController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorFormatter()],
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  labelText: 'Monto Límite',
                  labelStyle: TextStyle(color: accentColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 10),
              // Quick limit chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final amount in [10000.0, 30000.0, 50000.0, 100000.0, 200000.0, 500000.0])
                    GestureDetector(
                      onTap: () {
                        _limitController.text = formatInitialAmount(amount);
                        _limitController.selection = TextSelection.collapsed(
                            offset: _limitController.text.length);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accentColor.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          formatAmount(amount, compact: true),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accentColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Tipo: fijo/variable ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(10)),
                ),
                child: SwitchListTile(
                  title: Text(
                    _isFixed ? 'Gasto Fijo' : 'Gasto Variable',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  subtitle: Text(
                    _isFixed
                        ? 'Se repite todos los meses (alquiler, suscripciones...)'
                        : 'Varía mes a mes (supermercado, salidas...)',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  value: _isFixed,
                  onChanged: (val) => setState(() => _isFixed = val),
                  activeThumbColor: accentColor,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 28),

              // ── Botón ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          isEditing ? 'Guardar Cambios' : 'Crear Presupuesto',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

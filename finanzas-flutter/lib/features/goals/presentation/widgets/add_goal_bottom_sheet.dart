import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/logic/goal_service.dart';
import '../../domain/models/goal.dart';

class AddGoalBottomSheet extends ConsumerStatefulWidget {
  final Goal? goalToEdit;

  const AddGoalBottomSheet({super.key, this.goalToEdit});

  static Future<void> show(BuildContext context, {Goal? goalToEdit}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddGoalBottomSheet(goalToEdit: goalToEdit),
    );
  }

  @override
  ConsumerState<AddGoalBottomSheet> createState() => _AddGoalBottomSheetState();
}

class _AddGoalBottomSheetState extends ConsumerState<AddGoalBottomSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _savedController;
  DateTime? _deadline;
  String _selectedIconKey = 'flag';
  Color _selectedColor = AppTheme.colorTransfer;
  bool _saving = false;

  static const List<String> _iconKeys = [
    'flag', 'travel', 'home', 'car', 'laptop',
    'game', 'shop', 'food', 'fitness', 'savings',
  ];

  final List<Color> _availableColors = [
    AppTheme.colorTransfer,
    Colors.orangeAccent,
    Colors.pinkAccent,
    Colors.purpleAccent,
    Colors.cyanAccent,
    Colors.greenAccent,
    Colors.amberAccent,
  ];

  @override
  void initState() {
    super.initState();
    final g = widget.goalToEdit;
    _nameController = TextEditingController(text: g?.name ?? '');
    _targetController = TextEditingController(
        text: g != null ? formatInitialAmount(g.targetAmount) : '');
    _savedController = TextEditingController(
        text: g != null && g.savedAmount > 0 ? formatInitialAmount(g.savedAmount) : '');
    _deadline = g?.deadline;
    _selectedIconKey = g?.iconName ?? 'flag';
    _selectedColor = g != null ? Color(g.colorValue) : AppTheme.colorTransfer;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _savedController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.colorTransfer,
              onPrimary: Colors.white,
              surface: const Color(0xFF1E1E2C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final amountText = _targetController.text.trim();
    if (name.isEmpty || amountText.isEmpty) return;
    final amount = parseFormattedAmount(amountText);
    if (amount <= 0) return;

    setState(() => _saving = true);
    final service = ref.read(goalServiceProvider);
    final isEditing = widget.goalToEdit != null;

    final savedText = _savedController.text.trim();
    final savedAmount = savedText.isNotEmpty ? parseFormattedAmount(savedText) : null;

    try {
      if (isEditing) {
        await service.updateGoal(
          widget.goalToEdit!.id,
          name: name,
          targetAmount: amount,
          currentAmount: savedAmount,
          colorValue: _selectedColor.toARGB32(),
          iconName: _selectedIconKey,
          deadline: _deadline,
          clearDeadline: _deadline == null,
        );
      } else {
        await service.addGoal(
          name: name,
          targetAmount: amount,
          colorValue: _selectedColor.toARGB32(),
          iconName: _selectedIconKey,
          deadline: _deadline,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.goalToEdit != null;
    final currentIcon = Goal.iconMap[_selectedIconKey] ?? Icons.flag_rounded;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding + 24),
      decoration: const BoxDecoration(
        color: Color(0xFF18181F),
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(currentIcon, color: _selectedColor),
              ),
              const SizedBox(width: 12),
              Text(
                isEditing ? 'Editar Objetivo' : 'Nuevo Objetivo',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Íconos
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _iconKeys.length,
              itemBuilder: (context, index) {
                final key = _iconKeys[index];
                final iconData = Goal.iconMap[key]!;
                final isSelected = key == _selectedIconKey;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIconKey = key),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedColor.withValues(alpha: 0.2)
                          : Colors.white.withAlpha(10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSelected
                              ? _selectedColor
                              : Colors.transparent),
                    ),
                    child: Icon(iconData,
                        color: isSelected ? _selectedColor : Colors.white38,
                        size: 20),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Colores
          SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableColors.length,
              itemBuilder: (context, index) {
                final color = _availableColors[index];
                final isSelected = color.toARGB32() == _selectedColor.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ej. Viaje a Japón',
              labelText: 'Nombre del Objetivo',
              labelStyle: const TextStyle(color: AppTheme.colorTransfer),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsSeparatorFormatter()],
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixText: '\$ ',
              labelText: 'Monto a Alcanzar',
              labelStyle: const TextStyle(color: AppTheme.colorTransfer),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),

          // Campo de monto ahorrado (solo en edición)
          if (isEditing)
            TextField(
              controller: _savedController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorFormatter()],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixText: '\$ ',
                labelText: 'Monto Ahorrado',
                labelStyle: TextStyle(color: AppTheme.colorIncome.withValues(alpha: 0.8)),
                helperText: 'Podés corregir el monto ahorrado actual',
                helperStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppTheme.colorIncome.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.colorIncome, width: 2),
                ),
              ),
            ),
          if (isEditing) const SizedBox(height: 16),

          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppTheme.colorTransfer.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded,
                      color: AppTheme.colorTransfer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fecha Límite',
                            style: TextStyle(
                                color: AppTheme.colorTransfer, fontSize: 12)),
                        Text(
                          _deadline != null
                              ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}'
                              : 'Tocar para seleccionar',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  if (_deadline != null)
                    GestureDetector(
                      onTap: () => setState(() => _deadline = null),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: Colors.white38),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(isEditing ? 'Guardar Cambios' : 'Crear Objetivo'),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

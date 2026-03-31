import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/goal.dart';

class AddGoalBottomSheet extends StatefulWidget {
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
  State<AddGoalBottomSheet> createState() => _AddGoalBottomSheetState();
}

class _AddGoalBottomSheetState extends State<AddGoalBottomSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  DateTime? _deadline;
  IconData _selectedIcon = Icons.flag_rounded;
  Color _selectedColor = AppTheme.colorTransfer;

  final List<IconData> _availableIcons = [
    Icons.flag_rounded,
    Icons.flight_takeoff_rounded,
    Icons.home_rounded,
    Icons.directions_car_rounded,
    Icons.laptop_mac_rounded,
    Icons.videogame_asset_rounded,
    Icons.shopping_bag_rounded,
    Icons.restaurant_rounded,
    Icons.fitness_center_rounded,
    Icons.savings_rounded,
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
        text: g != null ? g.targetAmount.toInt().toString() : '');
    _deadline = g?.deadline;
    _selectedIcon = g?.icon ?? Icons.flag_rounded;
    _selectedColor = g?.color ?? AppTheme.colorTransfer;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
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
    if (picked != null) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.goalToEdit != null;

    final hasDeadline = _deadline != null;
    final monthsLeft = hasDeadline ? _deadline!.difference(DateTime.now()).inDays ~/ 30 : 0;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding + 100),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_selectedIcon, color: _selectedColor),
              ),
              const SizedBox(width: 12),
              Text(
                isEditing ? 'Editar Objetivo' : 'Nuevo Objetivo',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // --- Iconos y Colores ---
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableIcons.length,
              itemBuilder: (context, index) {
                final icon = _availableIcons[index];
                final isSelected = icon == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? _selectedColor.withValues(alpha: 0.2) : Colors.white.withAlpha(10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? _selectedColor : Colors.transparent),
                    ),
                    child: Icon(icon, color: isSelected ? _selectedColor : Colors.white38, size: 20),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableColors.length,
              itemBuilder: (context, index) {
                final color = _availableColors[index];
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixText: '\$ ',
              labelText: 'Monto a Alcanzar',
              labelStyle: const TextStyle(color: AppTheme.colorTransfer),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.colorTransfer.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: AppTheme.colorTransfer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fecha Límite', style: TextStyle(color: AppTheme.colorTransfer, fontSize: 12)),
                        Text(
                          hasDeadline 
                            ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}' 
                            : 'Tocar para seleccionar',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
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
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEditing ? 'Objetivo guardado' : 'Objetivo creado')),
                );
              },
              child: Text(isEditing ? 'Guardar Cambios' : 'Crear Objetivo'),
            ),
          ),
        ],
      ),
    );
  }
}

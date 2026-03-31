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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goalToEdit?.name ?? '');
    _targetController = TextEditingController(
        text: widget.goalToEdit != null ? widget.goalToEdit!.targetAmount.toInt().toString() : '');
    _deadline = widget.goalToEdit?.deadline;
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
              Icon(isEditing ? Icons.edit_rounded : Icons.flag_rounded, color: AppTheme.colorTransfer),
              const SizedBox(width: 8),
              Text(
                isEditing ? 'Editar Objetivo' : 'Nuevo Objetivo',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ej. Viaje a Japón',
              hintStyle: const TextStyle(color: Colors.white38),
              labelText: 'Nombre del Objetivo',
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
            controller: _targetController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ej. 2500000',
              prefixText: '\$ ',
              hintStyle: const TextStyle(color: Colors.white38),
              labelText: 'Monto a Alcanzar',
              labelStyle: const TextStyle(color: AppTheme.colorTransfer),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.colorTransfer),
              ),
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
                        const SizedBox(height: 2),
                        Text(
                          hasDeadline 
                            ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}' 
                            : 'Tocar para seleccionar',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  if (hasDeadline && monthsLeft > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.colorTransfer.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('En $monthsLeft meses', style: TextStyle(color: AppTheme.colorTransfer, fontSize: 12, fontWeight: FontWeight.w600)),
                    )
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
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.colorTransfer,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(isEditing ? 'Guardar Cambios' : 'Crear Objetivo', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

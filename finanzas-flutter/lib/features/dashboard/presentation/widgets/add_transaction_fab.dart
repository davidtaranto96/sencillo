import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../transactions/presentation/widgets/add_transaction_bottom_sheet.dart';

class AddTransactionFab extends StatelessWidget {
  const AddTransactionFab({super.key});

  @override
  Widget build(BuildContext context) {
    // Al usar endFloat con ShellRoute extendBody: true, 
    // el FAB puede quedar bajo la navbar. Forzamos un padding fijo.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 85,
      ),
      child: FloatingActionButton(
        onPressed: () => AddTransactionBottomSheet.show(context),
        backgroundColor: AppTheme.colorTransfer,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.auto_awesome_rounded, size: 28),
      ),
    );
  }
}

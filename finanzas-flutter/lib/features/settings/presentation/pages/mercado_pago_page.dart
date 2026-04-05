import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/mercado_pago_provider.dart';
import '../../../../core/services/mercado_pago_service.dart';
import '../../../../core/database/database_providers.dart';

class MercadoPagoPage extends ConsumerStatefulWidget {
  const MercadoPagoPage({super.key});

  @override
  ConsumerState<MercadoPagoPage> createState() => _MercadoPagoPageState();
}

class _MercadoPagoPageState extends ConsumerState<MercadoPagoPage> {
  final _tokenController = TextEditingController();
  bool _isConnecting = false;
  bool _showToken = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(mpConnectedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mercado Pago',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (isConnected.valueOrNull == true)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => refreshMercadoPago(ref),
              tooltip: 'Actualizar',
            ),
        ],
      ),
      body: isConnected.when(
        data: (connected) =>
            connected ? _buildDashboard() : _buildConnectForm(),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildConnectForm(),
      ),
    );
  }

  // ─── Formulario de conexión ────────────────────────────────────────────────

  Widget _buildConnectForm() {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF009EE3), Color(0xFF00B1EA)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 48),
              const SizedBox(height: 12),
              Text(
                'Conectá tu Mercado Pago',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Visualizá tu saldo y movimientos en tiempo real dentro de Sencillo',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Instrucciones
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cómo obtener tu Access Token:',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 12),
              _StepItem(number: '1', text: 'Entrá a developers.mercadopago.com.ar'),
              _StepItem(number: '2', text: 'Andá a Tu aplicación → Credenciales de producción'),
              _StepItem(number: '3', text: 'Copiá el Access Token'),
              _StepItem(number: '4', text: 'Pegalo acá abajo'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.colorWarning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_rounded,
                        color: AppTheme.colorWarning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tu token se guarda solo en tu celular. No se comparte con nadie.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.colorWarning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Input de token
        TextField(
          controller: _tokenController,
          obscureText: !_showToken,
          style: GoogleFonts.jetBrainsMono(fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Access Token',
            hintText: 'APP_USR-...',
            prefixIcon: const Icon(Icons.key_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                  _showToken ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showToken = !_showToken),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Botón conectar
        FilledButton.icon(
          onPressed: _isConnecting ? null : _connect,
          icon: _isConnecting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.link_rounded),
          label: Text(
            _isConnecting ? 'Conectando...' : 'Conectar Mercado Pago',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF009EE3),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _connect() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pegá tu Access Token')),
      );
      return;
    }

    setState(() => _isConnecting = true);
    try {
      final profile = await connectMercadoPago(token);
      ref.invalidate(mpConnectedProvider);
      ref.invalidate(mpProfileProvider);
      ref.invalidate(mpBalanceProvider);
      ref.invalidate(mpMovementsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Conectado como ${profile.displayName}!'),
            backgroundColor: const Color(0xFF5ECFB1),
          ),
        );
        // Ofrecer importar movimientos
        _showImportDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Token inválido o error: $e'),
            backgroundColor: AppTheme.colorExpense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  /// Dialog post-conexión para importar movimientos
  Future<void> _showImportDialog() async {
    if (!mounted) return;
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.sync_rounded, color: Color(0xFF009EE3), size: 24),
            const SizedBox(width: 10),
            Text('Importar movimientos',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17)),
          ],
        ),
        content: Text(
          '¿Querés importar tus movimientos recientes de Mercado Pago como transacciones en Sencillo?\n\n'
          'Se categorizarán automáticamente con IA y se sincronizará tu saldo.',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Después',
                style: GoogleFonts.inter(color: Colors.white54)),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text('Importar',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF009EE3),
            ),
          ),
        ],
      ),
    );

    if (shouldImport == true && mounted) {
      _runSync();
    }
  }

  /// Ejecuta la sincronización con feedback visual
  Future<void> _runSync() async {
    final result = await syncMercadoPago(ref);
    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.imported > 0
                ? '${result.imported} movimientos importados'
                : 'Todo sincronizado, no hay movimientos nuevos',
          ),
          backgroundColor:
              result.imported > 0 ? const Color(0xFF5ECFB1) : null,
        ),
      );
      // Refresh movimientos y balance del dashboard
      refreshMercadoPago(ref);
    }
  }

  // ─── Dashboard principal ───────────────────────────────────────────────────

  Widget _buildDashboard() {
    final profile = ref.watch(mpProfileProvider);
    final balance = ref.watch(mpBalanceProvider);
    final movements = ref.watch(mpMovementsProvider);
    final syncState = ref.watch(mpSyncStateProvider);
    final syncProgress = ref.watch(mpSyncProgressProvider);

    return RefreshIndicator(
      onRefresh: () async => refreshMercadoPago(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // Profile card
          profile.when(
            data: (p) => p != null ? _ProfileCard(profile: p) : const SizedBox(),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),

          const SizedBox(height: 16),

          // Balance card
          balance.when(
            data: (b) => b != null
                ? _BalanceCard(balance: b)
                : const _BalanceUnavailableCard(),
            loading: () => const _LoadingCard(),
            error: (_, __) => const _BalanceUnavailableCard(),
          ),

          const SizedBox(height: 16),

          // Sync control card
          _SyncControlCard(
            syncState: syncState,
            syncProgress: syncProgress,
            onSync: _runSync,
          ),

          const SizedBox(height: 16),

          // Insights de lo que ya está importado
          const _MpInsightsCard(),

          const SizedBox(height: 20),

          // Últimos movimientos header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Últimos movimientos',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (syncState != MpSyncState.syncing)
                TextButton.icon(
                  onPressed: _runSync,
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: Text('Sincronizar',
                      style: GoogleFonts.inter(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF009EE3),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Movimientos list
          movements.when(
            data: (list) => list.isEmpty
                ? const _EmptyCard(message: 'No hay movimientos recientes')
                : _MovementsList(movements: list.take(20).toList()),
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(error: e.toString()),
          ),

          const SizedBox(height: 24),

          // Borrar importaciones
          OutlinedButton.icon(
            onPressed: _clearImports,
            icon: Icon(Icons.delete_sweep_rounded,
                color: Colors.orange.withValues(alpha: 0.8)),
            label: Text(
              'Borrar importaciones anteriores',
              style: GoogleFonts.inter(
                  color: Colors.orange.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.orange.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),

          const SizedBox(height: 12),

          // Desconectar
          OutlinedButton.icon(
            onPressed: _disconnect,
            icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent),
            label: Text(
              'Desconectar Mercado Pago',
              style: GoogleFonts.inter(
                  color: Colors.redAccent, fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _clearImports() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_sweep_rounded,
                color: Colors.orange.withValues(alpha: 0.8), size: 22),
            const SizedBox(width: 8),
            const Text('Borrar importaciones',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ),
        content: const Text(
          'Se eliminarán todas las transacciones importadas de Mercado Pago.\n\n'
          'Tus movimientos manuales NO se tocan. '
          'Después podés volver a sincronizar.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final deleted = await clearMpImports(ref);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$deleted transacciones importadas eliminadas'),
        backgroundColor: Colors.orange,
      ),
    );

    refreshMercadoPago(ref);
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Desconectar?',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'Se eliminará el token guardado. Podés volver a conectarte cuando quieras.\n\nLas transacciones ya importadas se mantendrán.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await disconnectMercadoPago();
    ref.invalidate(mpConnectedProvider);
    ref.invalidate(mpProfileProvider);
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _StepItem extends StatelessWidget {
  final String number;
  final String text;
  const _StepItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFF009EE3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final MpUserProfile profile;
  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF009EE3), Color(0xFF00B1EA)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (profile.email != null)
                  Text(
                    profile.email!,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Conectado',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final MpBalance balance;
  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo disponible',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fmt.format(balance.availableBalance),
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppTheme.colorIncome,
            ),
          ),
          if (balance.unavailableAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(
                  'En proceso: ${fmt.format(balance.unavailableAmount)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Sync Control Card ──────────────────────────────────────────────────────

class _SyncControlCard extends ConsumerWidget {
  final MpSyncState syncState;
  final String syncProgress;
  final VoidCallback onSync;

  const _SyncControlCard({
    required this.syncState,
    required this.syncProgress,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoSyncAsync = ref.watch(mpAutoSyncEnabledProvider);
    final lastSyncAsync = ref.watch(mpLastSyncProvider);
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF009EE3).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sync_rounded,
                    color: Color(0xFF009EE3), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sincronización',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              // Estado indicador
              _SyncStatusBadge(state: syncState),
            ],
          ),

          const SizedBox(height: 14),

          // Auto-sync toggle
          autoSyncAsync.when(
            data: (enabled) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sincronización automática',
                    style: GoogleFonts.inter(fontSize: 13)),
                Switch.adaptive(
                  value: enabled,
                  onChanged: (v) async {
                    await setMpAutoSync(v);
                    ref.invalidate(mpAutoSyncEnabledProvider);
                  },
                  activeTrackColor: const Color(0xFF009EE3),
                  activeThumbColor: Colors.white,
                ),
              ],
            ),
            loading: () => const SizedBox(height: 32),
            error: (_, __) => const SizedBox(),
          ),

          // Última sincronización
          lastSyncAsync.when(
            data: (lastSync) {
              if (lastSync == null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Nunca sincronizado',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                );
              }
              final diff = DateTime.now().difference(lastSync);
              String timeAgo;
              if (diff.inMinutes < 1) {
                timeAgo = 'Hace un momento';
              } else if (diff.inMinutes < 60) {
                timeAgo = 'Hace ${diff.inMinutes} min';
              } else if (diff.inHours < 24) {
                timeAgo = 'Hace ${diff.inHours}h';
              } else {
                timeAgo = DateFormat('dd/MM HH:mm').format(lastSync);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 13, color: cs.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      'Última sync: $timeAgo',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox(height: 20),
            error: (_, __) => const SizedBox(),
          ),

          // Progress durante sync
          if (syncState == MpSyncState.syncing) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                backgroundColor: Color(0xFF2A2A3C),
                valueColor: AlwaysStoppedAnimation(Color(0xFF009EE3)),
                minHeight: 3,
              ),
            ),
            if (syncProgress.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                syncProgress,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF009EE3),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],

          // Error message
          if (syncState == MpSyncState.error && syncProgress.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.colorExpense.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                syncProgress,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppTheme.colorExpense),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Botón sincronizar
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: syncState == MpSyncState.syncing ? null : onSync,
              icon: syncState == MpSyncState.syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(
                syncState == MpSyncState.syncing
                    ? 'Sincronizando...'
                    : 'Sincronizar ahora',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF009EE3),
                disabledBackgroundColor:
                    const Color(0xFF009EE3).withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusBadge extends StatelessWidget {
  final MpSyncState state;
  const _SyncStatusBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final (Color color, String label, IconData icon) = switch (state) {
      MpSyncState.idle => (Colors.white38, 'Listo', Icons.check_circle_outline),
      MpSyncState.syncing => (const Color(0xFF009EE3), 'Sincronizando', Icons.sync_rounded),
      MpSyncState.success => (AppTheme.colorIncome, 'Sincronizado', Icons.check_circle_rounded),
      MpSyncState.error => (AppTheme.colorExpense, 'Error', Icons.error_outline_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Insights de importaciones ────────────────────────────────────────────────

class _MpInsightsCard extends ConsumerWidget {
  const _MpInsightsCard();

  static const _categoryLabels = <String, String>{
    'food': 'Comida',
    'transport': 'Transporte',
    'health': 'Salud',
    'entertainment': 'Entretenimiento',
    'shopping': 'Compras',
    'home': 'Hogar',
    'education': 'Educación',
    'services': 'Servicios',
    'salary': 'Sueldo',
    'freelance': 'Freelance',
    'other_expense': 'Otros gastos',
    'other_income': 'Otros ingresos',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(mpInsightsProvider);

    return insightsAsync.when(
      data: (insights) {
        if (insights == null || insights.totalImported == 0) {
          return const SizedBox.shrink();
        }
        final fmt = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
        final cs = Theme.of(context).colorScheme;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_rounded,
                      color: Color(0xFF009EE3), size: 18),
                  const SizedBox(width: 8),
                  Text('Resumen importado',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const Spacer(),
                  Text('${insights.totalImported} movs',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.5))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InsightChip(
                      label: 'Ingresos',
                      value: fmt.format(insights.totalIncomes),
                      color: AppTheme.colorIncome,
                      icon: Icons.arrow_downward_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InsightChip(
                      label: 'Egresos',
                      value: fmt.format(insights.totalExpenses),
                      color: AppTheme.colorExpense,
                      icon: Icons.arrow_upward_rounded,
                    ),
                  ),
                ],
              ),
              if (insights.expensesByCategory.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Mayor gasto: ${_categoryLabels[insights.topCategory] ?? insights.topCategory}  •  ${fmt.format(insights.expensesByCategory[insights.topCategory] ?? 0)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _InsightChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _InsightChip(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: color.withValues(alpha: 0.8))),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Movements List with sync badges + flip ───────────────────────────────────

class _MovementsList extends ConsumerWidget {
  final List<MpMovement> movements;
  const _MovementsList({required this.movements});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncedIdsAsync = ref.watch(mpSyncedIdsProvider);
    final syncedIds = syncedIdsAsync.valueOrNull ?? {};

    return Column(
      children: movements
          .map((m) => _MovementTile(
                movement: m,
                isSynced: syncedIds.contains(m.id),
              ))
          .toList(),
    );
  }
}

class _MovementTile extends ConsumerStatefulWidget {
  final MpMovement movement;
  final bool isSynced;
  const _MovementTile({required this.movement, this.isSynced = false});

  @override
  ConsumerState<_MovementTile> createState() => _MovementTileState();
}

class _MovementTileState extends ConsumerState<_MovementTile> {
  bool _flipping = false;

  Future<void> _flip(String txId, String currentType) async {
    setState(() => _flipping = true);
    await flipMpTransactionType(ref, txId, currentType);
    if (mounted) setState(() => _flipping = false);
    ref.invalidate(mpInsightsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
    final isIncome = widget.movement.amount > 0;
    final color = isIncome ? AppTheme.colorIncome : AppTheme.colorExpense;
    final icon = isIncome
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
    final dateFmt = DateFormat('dd/MM HH:mm');

    // Buscar la transacción importada en DB para poder cambiarle el tipo
    final allTxsAsync = ref.watch(transactionsStreamProvider);
    final mpId = widget.movement.id;

    // Encontrar la transacción importada correspondiente
    String? dbTxId;
    String? dbTxType;
    allTxsAsync.whenData((txs) {
      for (final tx in txs) {
        if (tx.note?.contains('mp_sync:$mpId') == true) {
          dbTxId = tx.id;
          dbTxType = tx.type.name;
          break;
        }
      }
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.movement.description ?? 'Movimiento',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isSynced)
                      Icon(Icons.check_circle_rounded,
                          size: 13,
                          color: AppTheme.colorIncome.withValues(alpha: 0.7)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  dateFmt.format(widget.movement.date),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : ''}${fmt.format(widget.movement.amount)}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: color,
                ),
              ),
              // Botón flip solo si la transacción está importada en DB
              if (widget.isSynced && dbTxId != null)
                GestureDetector(
                  onTap: _flipping
                      ? null
                      : () => _flip(dbTxId!, dbTxType ?? (isIncome ? 'income' : 'expense')),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _flipping
                        ? const SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swap_vert_rounded,
                                  size: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.4)),
                              Text(
                                isIncome ? ' → gasto' : ' → ingreso',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceUnavailableCard extends StatelessWidget {
  const _BalanceUnavailableCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'El saldo no está disponible con este tipo de token. '
              'Tus movimientos se sincronizan normalmente.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(message,
            style: GoogleFonts.inter(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5))),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  const _ErrorCard({required this.error});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.colorExpense.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('Error: $error',
          style: GoogleFonts.inter(color: AppTheme.colorExpense, fontSize: 13)),
    );
  }
}

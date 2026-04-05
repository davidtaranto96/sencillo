import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_theme.dart';

class CurrencyRatesCard extends ConsumerWidget {
  const CurrencyRatesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratesAsync = ref.watch(currencyRatesProvider);

    return ratesAsync.when(
      loading: () => const _ShimmerCard(),
      error: (_, __) => const SizedBox.shrink(), // falla silenciosamente
      data: (rates) {
        if (rates.isEmpty) return const SizedBox.shrink();
        return _RatesCard(rates: rates);
      },
    );
  }
}

/// Auto-refresh cada 15 minutos — se usa en HomePage
final currencyAutoRefreshProvider = Provider.autoDispose<void>((ref) {
  // Refrescar cada 15 minutos
  final timer = Stream.periodic(const Duration(minutes: 15));
  final sub = timer.listen((_) {
    refreshCurrencyRatesFromRef(ref);
  });
  ref.onDispose(() => sub.cancel());
});

// ─────────────────────────────────────────────
// Card principal con tasas
// ─────────────────────────────────────────────
class _RatesCard extends ConsumerStatefulWidget {
  final List<CurrencyRate> rates;
  const _RatesCard({required this.rates});

  @override
  ConsumerState<_RatesCard> createState() => _RatesCardState();
}

class _RatesCardState extends ConsumerState<_RatesCard> {
  bool _showBuy = false;
  bool _showConverter = false;
  final _arsCtrl = TextEditingController();
  final _usdCtrl = TextEditingController();
  bool _editingArs = true; // which field is the source

  @override
  void dispose() {
    _arsCtrl.dispose();
    _usdCtrl.dispose();
    super.dispose();
  }

  CurrencyRate get _blue => widget.rates.firstWhere(
        (r) => r.casa == 'blue',
        orElse: () => widget.rates.first,
      );

  void _onArsChanged(String val) {
    if (!_editingArs) return;
    final ars = double.tryParse(val.replaceAll(',', '.'));
    if (ars == null) {
      _usdCtrl.text = '';
      return;
    }
    final rate = _showBuy ? _blue.compra : _blue.venta;
    if (rate <= 0) return;
    _usdCtrl.text = (ars / rate).toStringAsFixed(2);
  }

  void _onUsdChanged(String val) {
    if (_editingArs) return;
    final usd = double.tryParse(val.replaceAll(',', '.'));
    if (usd == null) {
      _arsCtrl.text = '';
      return;
    }
    final rate = _showBuy ? _blue.compra : _blue.venta;
    _arsCtrl.text = (usd * rate).toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final blue = _blue;
    final updated = _formatTime(blue.updatedAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💵', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(
                        'Cotizaciones',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF9B96FF),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Refresh button
                GestureDetector(
                  onTap: () {
                    refreshCurrencyRates(ref);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: Colors.white38,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Buy/Sell toggle
                GestureDetector(
                  onTap: () => setState(() => _showBuy = !_showBuy),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _showBuy ? 'Comprás' : 'Vendés',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Blue hero ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _BlueHero(rate: blue, showBuy: _showBuy),
          ),

          // ── Scroll horizontal de otras tasas ──
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              itemCount: widget.rates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final r = widget.rates[i];
                return _RateChip(rate: r, showBuy: _showBuy);
              },
            ),
          ),

          // ── Conversor toggle ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: GestureDetector(
              onTap: () => setState(() => _showConverter = !_showConverter),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showConverter
                        ? Icons.expand_less_rounded
                        : Icons.currency_exchange_rounded,
                    size: 14,
                    color: Colors.white38,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _showConverter ? 'Ocultar conversor' : 'Convertir ARS ↔ USD',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),

          // ── Conversor expandible ──
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _showConverter
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: _ConverterSection(
                      arsCtrl: _arsCtrl,
                      usdCtrl: _usdCtrl,
                      editingArs: _editingArs,
                      onArsChanged: _onArsChanged,
                      onUsdChanged: _onUsdChanged,
                      onArsFocus: () => setState(() => _editingArs = true),
                      onUsdFocus: () => setState(() => _editingArs = false),
                      rate: _showBuy ? blue.compra : blue.venta,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ── Footer: última actualización ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Text(
              'Actualizado $updated · dolarapi.com',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    return 'hace ${diff.inDays}d';
  }
}

// ─────────────────────────────────────────────
// Dólar Blue hero (grande)
// ─────────────────────────────────────────────
class _BlueHero extends StatelessWidget {
  final CurrencyRate rate;
  final bool showBuy;

  const _BlueHero({required this.rate, required this.showBuy});

  @override
  Widget build(BuildContext context) {
    final price = showBuy ? rate.compra : rate.venta;
    final spread = rate.venta - rate.compra;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C63FF).withValues(alpha: 0.18),
            const Color(0xFF4ECDC4).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dólar Blue',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${price.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _PriceTag(label: 'Comprás', value: rate.compra, active: showBuy),
              const SizedBox(height: 4),
              _PriceTag(label: 'Vendés', value: rate.venta, active: !showBuy),
              const SizedBox(height: 4),
              Text(
                'Spread \$${spread.toStringAsFixed(0)}',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white24),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final String label;
  final double value;
  final bool active;

  const _PriceTag({required this.label, required this.value, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: active ? Colors.white60 : Colors.white24,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '\$${value.toStringAsFixed(0)}',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : Colors.white30,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Chip de cotización individual
// ─────────────────────────────────────────────
class _RateChip extends StatelessWidget {
  final CurrencyRate rate;
  final bool showBuy;

  const _RateChip({required this.rate, required this.showBuy});

  Color get _color {
    switch (rate.casa) {
      case 'blue':
        return const Color(0xFF6C63FF);
      case 'oficial':
        return AppTheme.colorIncome;
      case 'tarjeta':
        return AppTheme.colorWarning;
      case 'mep':
        return AppTheme.colorTransfer;
      case 'ccl':
        return const Color(0xFFFF8C69);
      default:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = showBuy ? rate.compra : rate.venta;
    final color = _color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rate.label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '\$${price.toStringAsFixed(0)}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Conversor ARS ↔ USD
// ─────────────────────────────────────────────
class _ConverterSection extends StatelessWidget {
  final TextEditingController arsCtrl;
  final TextEditingController usdCtrl;
  final bool editingArs;
  final ValueChanged<String> onArsChanged;
  final ValueChanged<String> onUsdChanged;
  final VoidCallback onArsFocus;
  final VoidCallback onUsdFocus;
  final double rate;

  const _ConverterSection({
    required this.arsCtrl,
    required this.usdCtrl,
    required this.editingArs,
    required this.onArsChanged,
    required this.onUsdChanged,
    required this.onArsFocus,
    required this.onUsdFocus,
    required this.rate,
  });

  InputDecoration _decoration(String hint, String prefix) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      prefixStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.white54,
      ),
      hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: const Color(0xFF6C63FF).withValues(alpha: 0.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Focus(
                  onFocusChange: (hasFocus) { if (hasFocus) onArsFocus(); },
                  child: TextField(
                    controller: arsCtrl,
                    onChanged: onArsChanged,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                    decoration: _decoration('0', '\$ '),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  size: 20,
                  color: Colors.white24,
                ),
              ),
              Expanded(
                child: Focus(
                  onFocusChange: (hasFocus) { if (hasFocus) onUsdFocus(); },
                  child: TextField(
                    controller: usdCtrl,
                    onChanged: onUsdChanged,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                    decoration: _decoration('0.00', 'USD '),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '1 USD = \$${rate.toStringAsFixed(0)} ARS',
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white24),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shimmer mientras carga
// ─────────────────────────────────────────────
class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value, 0),
              colors: [
                Colors.white.withValues(alpha: 0.03),
                Colors.white.withValues(alpha: 0.07),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
        );
      },
    );
  }
}

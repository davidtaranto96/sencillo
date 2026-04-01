import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(path: '/home', label: 'Home', icon: Icons.home_rounded),
    _TabItem(path: '/transactions', label: 'Movimientos', icon: Icons.swap_horiz_rounded),
    _TabItem(path: '/budget', label: 'Presupuesto', icon: Icons.donut_large_rounded),
    _TabItem(path: '/goals', label: 'Objetivos', icon: Icons.flag_rounded),
    _TabItem(path: '/more', label: 'Más', icon: Icons.grid_view_rounded),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final idx = _tabs.indexWhere((t) => location.startsWith(t.path));
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: child,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomPadding + 12,
        ),
        child: _FloatingNavBar(
          currentIndex: currentIndex,
          tabs: _tabs,
          onTap: (i) {
            // Close ALL open modals, bottom sheets, dialogs before switching tab
            Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
            context.go(_tabs[i].path);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Navbar flotante — copia exacta del estilo AstroPay
// ─────────────────────────────────────────────────────
class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_TabItem> tabs;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40), // cápsula muy redondeada
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFF18181F).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.07),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: tabs.asMap().entries.map((e) {
              return Expanded(
                child: _NavItem(
                  tab: e.value,
                  selected: e.key == currentIndex,
                  onTap: () => onTap(e.key),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Item: blob circular grande al presionar (AstroPay style)
// ─────────────────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final _TabItem tab;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.forward();
  void _onTapUp(_) {
    _controller.reverse();
    widget.onTap();
  }
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selected;

    // Colores: blanco puro = seleccionado, gris = inactivo (igual que AstroPay)
    final iconColor = isSelected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.38);
    final labelColor = isSelected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.38);
    final labelWeight = isSelected ? FontWeight.w700 : FontWeight.w400;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Blob circular gris al presionar
            AnimatedBuilder(
              animation: _scale,
              builder: (context, child) => Transform.scale(
                scale: _scale.value,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12 * _scale.value),
                  ),
                ),
              ),
            ),
            // Contenido (icono + label)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.tab.icon, size: 22, color: iconColor),
                const SizedBox(height: 4),
                Text(
                  widget.tab.label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: labelWeight,
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem {
  final String path;
  final String label;
  final IconData icon;
  const _TabItem({
    required this.path,
    required this.label,
    required this.icon,
  });
}

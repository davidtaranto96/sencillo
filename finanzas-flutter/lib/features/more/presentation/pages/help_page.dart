import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


/// Shows the help & tutorial bottom sheet (or full-screen modal on smaller phones).
void showHelpSheet(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      pageBuilder: (_, __, ___) => const _HelpModal(),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// Modal root
// ─────────────────────────────────────────────
class _HelpModal extends StatefulWidget {
  const _HelpModal();

  @override
  State<_HelpModal> createState() => _HelpModalState();
}

class _HelpModalState extends State<_HelpModal> {
  int _activeSection = 0;

  static const _sections = [
    _Section(
      emoji: '🏠',
      title: 'Inicio',
      color: Color(0xFF4ECDC4),
      items: [
        _Item('Saldo total', 'La pantalla de Inicio muestra tu balance general, las alertas de presupuesto activas y los últimos movimientos del día.'),
        _Item('Alertas de presupuesto', 'Cuando superás el 80% de un presupuesto aparece un aviso en rojo. Tocalo para ver el detalle.'),
        _Item('Resumen rápido', 'El chip de porcentaje junto a cada gasto indica qué parte de tu presupuesto mensual representa ese movimiento.'),
      ],
    ),
    _Section(
      emoji: '✨',
      title: 'IA',
      color: Color(0xFF6C63FF),
      items: [
        _Item('Botón inteligente', 'El botón flotante (✦) en la esquina inferior derecha abre el asistente de IA. Podés dictar o escribir en lenguaje natural.'),
        _Item('Gastos', '"Gasté 2500 en supermercado con débito" → detecta monto, categoría y cuenta automáticamente.'),
        _Item('Gastos compartidos', '"Dividí con Lucía el almuerzo de 3600" → crea el gasto y registra que Lucía te debe su parte.'),
        _Item('Préstamos y deudas', '"Le presté 5000 a Carlos" o "Le pagué a Martín lo que le debía" → gestiona deudas automáticamente.'),
        _Item('Ahorros y metas', '"Guardé 10000 para las vacaciones" → aporta directamente a tu objetivo de ahorro.'),
        _Item('Navegar', '"Ir a reportes" o "Abrir personas" → te lleva a la sección sin tocar nada más.'),
        _Item('Consultas', '"¿Cuánto tengo?" o "¿Cómo va mi presupuesto de comida?" → responde con tus datos reales.'),
        _Item('Crear contactos', '"Agregar a Pedro como contacto" → crea la persona para registrar deudas futuras.'),
        _Item('Voz', 'Mantené presionado el micrófono para dictar. La IA procesa automáticamente al terminar de hablar.'),
      ],
    ),
    _Section(
      emoji: '💸',
      title: 'Movimientos',
      color: Color(0xFFFF6B6B),
      items: [
        _Item('Agregar manual', 'Usá el botón + del menú inferior para abrir el formulario completo. Podés elegir categoría, cuenta, fecha y notas.'),
        _Item('Gasto compartido', 'Al registrar un gasto podés activar "Dividir" para indicar cuánto puso cada persona. La app calcula quién debe qué.'),
        _Item('Filtros', 'En la lista de movimientos podés filtrar por mes, categoría o cuenta para encontrar cualquier transacción.'),
        _Item('Editar / eliminar', 'Deslizá un movimiento hacia la izquierda para ver las opciones de editar o eliminar.'),
      ],
    ),
    _Section(
      emoji: '🎯',
      title: 'Presupuestos',
      color: Color(0xFFFFD93D),
      items: [
        _Item('Crear presupuesto', 'Asignale un límite mensual a cualquier categoría (comida, transporte, ocio, etc.) desde la sección Presupuestos.'),
        _Item('Seguimiento', 'La barra de progreso se actualiza en tiempo real cada vez que cargás un gasto en esa categoría.'),
        _Item('Alertas', 'Cuando llegás al 80% del límite la app te avisa. Al 100% el indicador se pone rojo.'),
        _Item('Seguro gastar', 'El número "Seguro gastar" en la sección Más es lo que podés gastar hoy sin superar ningún presupuesto activo.'),
      ],
    ),
    _Section(
      emoji: '💰',
      title: 'Metas',
      color: Color(0xFF4ECDC4),
      items: [
        _Item('Crear meta', 'En la sección Ahorros/Metas creás un objetivo con nombre, monto y fecha límite opcional.'),
        _Item('Aportar', 'Cada vez que aportás a una meta el saldo avanza. Podés aportar desde el botón IA o directamente desde la meta.'),
        _Item('Múltiples metas', 'Podés tener varias metas activas al mismo tiempo: vacaciones, auto, fondo de emergencia, etc.'),
      ],
    ),
    _Section(
      emoji: '👥',
      title: 'Amigos',
      color: Color(0xFFFF8C69),
      items: [
        _Item('Deudas y préstamos', 'La sección Amigos muestra el balance neto con cada contacto: positivo = te deben, negativo = les debés.'),
        _Item('Historial', 'Tocá un amigo para ver todos los movimientos compartidos y el detalle de cada transacción.'),
        _Item('Saldar deuda', 'Desde el perfil del amigo podés registrar un pago parcial o total para actualizar el balance.'),
        _Item('Agregar amigo', 'Usá el botón + en Amigos o dictale a la IA "Agregar a [nombre] como contacto".'),
      ],
    ),
    _Section(
      emoji: '📊',
      title: 'Análisis',
      color: Color(0xFF9B59B6),
      items: [
        _Item('Gráfico de gastos', 'El gráfico de dona muestra cómo se distribuyen tus gastos por categoría en el período seleccionado.'),
        _Item('Comparativa mensual', 'El reporte de análisis compara ingresos vs gastos mes a mes para identificar tendencias.'),
        _Item('Exportar', 'Desde Análisis podés exportar tus datos a CSV para analizarlos en otra herramienta.'),
      ],
    ),
    _Section(
      emoji: '⚙️',
      title: 'Trucos',
      color: Color(0xFF1ABC9C),
      items: [
        _Item('Pestañas personalizables', 'En Más → Personalizar navegación elegís qué 4 secciones aparecen en el menú inferior.'),
        _Item('Cuentas múltiples', 'Podés tener efectivo, cuentas bancarias y tarjetas de crédito por separado. El "Dinero disponible" solo cuenta el efectivo y bancos.'),
        _Item('Tarjetas de crédito', 'Al registrar un gasto con tarjeta podés elegir entre "compra" (suma al saldo de la tarjeta) o "pago del resumen".'),
        _Item('Transferencias internas', 'Cuando movés plata entre tus propias cuentas usá "Transferencia interna" para que no afecte el balance total.'),
        _Item('API Key de IA', 'Si configurás tu propia API key de Claude en Ajustes, la IA funciona con mayor precisión y más contexto.'),
        _Item('Tutorial de bienvenida', 'Podés volver a ver el tutorial inicial desde Más → Ajustes generales → Restablecer tutorial.'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: GestureDetector(
            onTap: () {}, // absorb taps inside
            child: Container(
              width: size.width,
              height: size.height * 0.92,
              margin: EdgeInsets.only(top: size.height * 0.08),
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Handle + header
                  _buildHeader(context),
                  // Section tabs
                  _buildTabs(),
                  // Content
                  Expanded(
                    child: _buildContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6C63FF).withValues(alpha: 0.3),
                      const Color(0xFF4ECDC4).withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Text('📖', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ayuda y Tutorial',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Todo lo que podés hacer con la app',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              // Close button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white54, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = _sections[i];
          final active = i == _activeSection;
          return GestureDetector(
            onTap: () => setState(() => _activeSection = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? s.color.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? s.color.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    s.title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? s.color : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    final section = _sections[_activeSection];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: ListView.builder(
        key: ValueKey(_activeSection),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        itemCount: section.items.length + 1, // +1 for section header
        itemBuilder: (context, i) {
          if (i == 0) {
            // Section hero
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: section.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: section.color.withValues(alpha: 0.25)),
                    ),
                    child: Center(
                      child: Text(section.emoji,
                          style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    section.title,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }
          final item = section.items[i - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _HelpItemCard(item: item, accentColor: section.color),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Help item card
// ─────────────────────────────────────────────
class _HelpItemCard extends StatelessWidget {
  final _Item item;
  final Color accentColor;

  const _HelpItemCard({required this.item, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.55),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────
class _Section {
  final String emoji;
  final String title;
  final Color color;
  final List<_Item> items;

  const _Section({
    required this.emoji,
    required this.title,
    required this.color,
    required this.items,
  });
}

class _Item {
  final String title;
  final String description;

  const _Item(this.title, this.description);
}

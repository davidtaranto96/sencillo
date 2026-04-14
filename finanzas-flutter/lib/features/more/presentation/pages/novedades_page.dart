import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

class NovedadesPage extends StatelessWidget {
  const NovedadesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Novedades',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // ── Header versión actual ──
          _CurrentVersionBanner(),
          const SizedBox(height: 20),

          // v1.8.0 — actual
          _VersionCard(
            version: 'v1.8.0',
            date: '14 Abr 2026',
            isCurrent: true,
            items: const [
              // Widgets Android
              _ChangeItem(icon: Icons.widgets_rounded, text: 'Widgets rediseñados: Gastos con chips Hoy/Semana/Mes, Cotizaciones con Blue+Oficial+Tarjeta, Crypto y Acciones con prev/next entre favoritos, Agregar con círculo branded', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.aspect_ratio_rounded, text: 'Widgets adaptivos: el widget Gastos se reorganiza según el tamaño (chips completos o vista compacta)', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.preview_rounded, text: 'Previews reales en el selector de widgets de Android (no más íconos genéricos)', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.link_rounded, text: 'Fix: taps en widgets ya no producen "Page Not Found" — ruteo consolidado con deep links sencillo://', type: _ChangeType.fix),

              // Reliability login/backup
              _ChangeItem(icon: Icons.shield_rounded, text: 'Backup: validación de integridad SQLite + rename atómico (ningún backup corrupto puede sobreescribir tus datos)', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.warning_amber_rounded, text: 'Aviso de conflicto si tenés datos locales nuevos y la nube tiene un backup viejo (podés elegir cuál conservar)', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.block_rounded, text: 'No se puede cancelar la restauración con back físico — protege el DB durante la descarga', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.error_outline_rounded, text: 'Errores reales al conectar Google (no más falso "¡Conectado!" cuando falla)', type: _ChangeType.fix),

              // Onboarding y tour
              _ChangeItem(icon: Icons.celebration_rounded, text: 'Confetti al finalizar el wizard de bienvenida', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.schedule_rounded, text: 'Elegí la hora exacta del recordatorio diario desde el wizard', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.lightbulb_rounded, text: 'Tour ampliado con atajos y gestos ocultos (long-press FAB para voz, swipe ← para borrar, doble tap para duplicar)', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.school_rounded, text: 'Guías por pantalla nuevas: detalle de tx, cuentas, ajustes, recurrentes, notificaciones, personas', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.tips_and_updates_rounded, text: 'Banner de tip del día en el Home — 21 consejos rotativos sobre trucos y gestos', type: _ChangeType.feature),

              // Cargar gasto inteligente
              _ChangeItem(icon: Icons.undo_rounded, text: 'Botón "Deshacer" de 8 segundos después de cargar un gasto', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.account_balance_wallet_rounded, text: 'Alerta naranja al cruzar el 80% del presupuesto de una categoría', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.emoji_emotions_rounded, text: 'Emoji al inicio del texto ya asigna categoría (🍕→comida, 🚗→transporte, etc.)', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.access_time_rounded, text: 'Sugerencia de categoría por hora/día: almuerzo laboral, salida de fin de semana, servicios el día 1', type: _ChangeType.improvement),
            ],
          ),

          // v1.7.0
          _VersionCard(
            version: 'v1.7.0',
            date: '13 Abr 2026',
            isCurrent: false,
            items: const [
              _ChangeItem(icon: Icons.widgets_rounded, text: 'Widget de pantalla de inicio: agregá gastos con voz o manual sin abrir la app', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.notifications_active_rounded, text: 'Detección de transferencias: detecta pagos de Mercado Pago, bancos y billeteras automáticamente', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.checklist_rounded, text: 'Check-in diario mejorado: el recordatorio ahora muestra cuánto gastaste hoy y botones de acción directa', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.school_rounded, text: 'Onboarding renovado: tutorial más conciso y claro en 6 pasos', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.phone_android_rounded, text: 'Soporte para tablets: la app se adapta mejor a pantallas grandes', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.link_off_rounded, text: 'Mercado Pago: se removió el input de API key manual (próximamente conexión automática)', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.cleaning_services_rounded, text: 'Fix: warnings de código limpiados (imports, null assertions)', type: _ChangeType.fix),
            ],
          ),

          // v1.6.1
          _VersionCard(
            version: 'v1.6.1',
            date: '9 Abr 2026',
            isCurrent: false,
            items: const [
              _ChangeItem(icon: Icons.mic_rounded, text: 'Asistente de voz con IA: preguntale a Sencillo sobre tus finanzas (activalo en Ajustes > IA)', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.edit_rounded, text: 'Editor de cuentas unificado: ahora podés cambiar tipo, icono, color y todos los campos desde cualquier lugar', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.credit_card_rounded, text: 'Selector de tipo de cuenta: cambiá entre Efectivo, Debito, Credito, Ahorro e Inversion', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.shopping_cart_rounded, text: 'Fix: overflow del boton Comprar en Compras Inteligentes resuelto', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.build_rounded, text: 'Fix: error de compilacion Kotlin JVM target para plugins de Android', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.storefront_rounded, text: 'Branding Mercado Pago: la cuenta vinculada se detecta por nombre ademas de por ID', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.visibility_off_rounded, text: 'Fix: pantalla negra al volver a la app desde segundo plano', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.history_rounded, text: 'Historial de precios manual en Compras Inteligentes: registra precios y ve la evolucion', type: _ChangeType.feature),
            ],
          ),

          // v1.6.0
          _VersionCard(
            version: 'v1.6.0',
            date: '7 Abr 2026',
            isCurrent: false,
            items: const [
              _ChangeItem(icon: Icons.bug_report_rounded, text: 'Fix crítico: eliminar gasto compartido ahora revierte correctamente el saldo de la persona', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.sync_problem_rounded, text: 'Fix: eliminar transferencia ahora revierte el saldo de ambas cuentas (origen y destino)', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.trending_up_rounded, text: 'Fix: editar el monto de un movimiento ahora recalcula el saldo de la cuenta correctamente', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.flag_rounded, text: 'Fix: eliminar un ahorro vinculado a un objetivo ahora revierte la contribución al objetivo', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.refresh_rounded, text: 'Smart refresh: deslizá hacia abajo en cualquier pantalla para limpiar datos inconsistentes y actualizar todo', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.health_and_safety_rounded, text: 'Nuevo servicio de integridad de datos: detecta y corrige deudas huérfanas y balances desincronizados automáticamente', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.group_rounded, text: 'Fix: recálculo de totales de grupos al detectar inconsistencias en el refresh', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.lock_rounded, text: 'Operaciones críticas ahora son atómicas: si algo falla a mitad, se revierte todo (sin datos a medias)', type: _ChangeType.improvement),
            ],
          ),

          // v1.5.8
          _VersionCard(
            version: 'v1.5.8',
            date: '7 Abr 2026',
            isCurrent: false,
            items: const [
              _ChangeItem(icon: Icons.check_circle_rounded, text: 'Animación de éxito al registrar movimientos: checkmark verde animado', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.touch_app_rounded, text: 'Double-tap en FAB: duplica el último movimiento al instante', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.linear_scale_rounded, text: 'Indicador de navegación deslizante: sigue el swipe entre tabs', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.swipe_rounded, text: 'Swipe bidireccional en movimientos: derecha para editar, izquierda para eliminar', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.warning_amber_rounded, text: 'Alertas de presupuesto: notificación push + in-app cuando excedés un presupuesto', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.table_chart_rounded, text: 'Exportar CSV: descargá tus movimientos en planilla desde Análisis', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.calendar_view_week_rounded, text: 'Análisis semanal: nuevo filtro "Semana" en reportes', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.notifications_active_rounded, text: 'Recordatorio diario y resumen semanal: notificaciones configurables desde Ajustes', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.repeat_rounded, text: 'Gastos recurrentes: suscripciones, alquileres y cuotas se registran automáticamente', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.currency_exchange_rounded, text: 'Multi-moneda: cuentas en USD/EUR se convierten al balance total usando cotización preferida', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.link_rounded, text: 'Vincular Mercado Pago a cuenta existente: elegí dónde importar movimientos', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.science_rounded, text: 'Tests unitarios: 25 tests para servicios core (transacciones, presupuestos, recurrentes, moneda)', type: _ChangeType.improvement),
            ],
          ),

          // v1.5.7
          _VersionCard(
            version: 'v1.5.7',
            date: '7 Abr 2026',
            isCurrent: false,
            items: const [
              _ChangeItem(icon: Icons.currency_bitcoin_rounded, text: 'Widget de criptomonedas en Home: precios en tiempo real de Bitcoin, Ethereum, Solana y más', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.show_chart_rounded, text: 'Widget de acciones en Home: Merval, CEDEARs y acciones argentinas con variación diaria', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.dashboard_customize_rounded, text: 'Personalizar Home: reordená y ocultá widgets desde el botón ⊞ o desde Ajustes', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.touch_app_rounded, text: 'Long-press en la barra de navegación: abre personalización de tabs con efecto bounce', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.tune_rounded, text: 'Nuevos selectores en Ajustes: elegí qué cryptos, acciones y widgets ver en Home', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.sync_rounded, text: 'Fix: sincronización Mercado Pago arreglada (error de tipo String/int)', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.vpn_key_rounded, text: 'Fix: mejor mensaje de error al conectar token de Mercado Pago (401/403)', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.price_check_rounded, text: 'Fix: check de precio MeLi mejorado con mejor detección de URL y mensajes claros', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.view_module_rounded, text: 'Fix: selector de cotizaciones ya no se desborda con muchas opciones', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.auto_awesome_rounded, text: 'Polish: bottom sheet de movimientos con tipografía más grande, mejor spacing y controles más amplios', type: _ChangeType.improvement),
            ],
          ),

          // v1.5.6
          _VersionCard(
            version: 'v1.5.6',
            date: '7 Abr 2026',
            isCurrent: false,
            items: const [
              _ChangeItem(icon: Icons.smart_toy_rounded, text: 'Fix: la IA ahora usa el título real del gasto en vez de mostrar "Gasto" genérico', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.account_balance_wallet_rounded, text: 'Recomendación inteligente de cuenta: muestra saldo disponible y límite de tarjeta al elegir cuenta', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.wallet_rounded, text: 'Nueva opción "Cuenta por defecto" en Ajustes → Finanzas', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.currency_exchange_rounded, text: 'Cotizaciones personalizables: elegí qué dólares ver desde Ajustes', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.trending_down_rounded, text: 'Seguimiento de precios en Antojos: registrá precios y recibí aviso cuando bajan', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.store_rounded, text: 'Auto-check de precios MercadoLibre: si el item tiene URL de MeLi, se consulta el precio actual automáticamente', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.add_rounded, text: 'Fix: botón FAB ahora aparece al abrir Antojos desde el menú Más', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.calendar_today_rounded, text: 'Nuevo widget "Gastos" en Home: mirá cuánto gastaste hoy, esta semana o este mes con desglose por categorías', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.cloud_download_rounded, text: 'Fix: al loguearte con Google, se restaura automáticamente tu último backup sin preguntar', type: _ChangeType.fix),
            ],
          ),

          // v1.5.5
          _VersionCard(
            version: 'v1.5.5',
            date: '6 Abr 2026',
            isCurrent: false,
            items: const [
              _ChangeItem(icon: Icons.people_alt_rounded, text: '"Personas" ahora se llama Amigos, "Objetivos" → Metas, "Wishlist" → Antojos, "Reportes" → Análisis', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.notifications_rounded, text: 'Badge rojo en la nav bar cuando hay solicitudes de amistad pendientes o alertas sin leer', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.vibration_rounded, text: 'Fix: vibración (haptic) ahora funciona correctamente en Android', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.volume_up_rounded, text: 'Fix: efectos de sonido de la app ahora se reproducen correctamente en Android', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.speed_rounded, text: 'Optimización: la app reconstruye menos partes de la UI innecesariamente, mejorando la fluidez', type: _ChangeType.improvement),
            ],
          ),

          // v1.5.4
          _VersionCard(
            version: 'v1.5.4',
            date: '6 Abr 2026',
            isCurrent: false,
            items: const [
              _ChangeItem(icon: Icons.auto_awesome_rounded, text: 'IA mejorada: ahora entendé comandos de amigos, gastos compartidos, deudas y navegación a personas', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.qr_code_scanner_rounded, text: 'Comando "Agregar amigo por QR" desde la IA abre directo el escáner', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.mark_email_read_rounded, text: 'Comando "Ver solicitudes" desde la IA abre la pantalla de solicitudes de amistad', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.account_balance_wallet_rounded, text: 'Comando "Cuánto le debo a Juan" responde con el balance exacto y navega a Amigos', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.psychology_rounded, text: 'Predicciones inteligentes: si escribís un nombre de persona se sugieren acciones relevantes con ella', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.lightbulb_rounded, text: 'Más ejemplos rápidos: Saldar deuda, Ver solicitudes, Mis amigos, entre otros', type: _ChangeType.improvement),
            ],
          ),

          // v1.5.3
          _VersionCard(
            version: 'v1.5.3',
            date: '5 Abr 2026',
            isCurrent: false,
            items: const [
              _ChangeItem(icon: Icons.person_rounded, text: 'Ventana de persona rediseñada: hero card con gradiente y balance grande y legible', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.bolt_rounded, text: 'Acciones rápidas siempre visibles: Nuevo gasto, Liquidar y Deuda anterior sin importar el saldo', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.bar_chart_rounded, text: 'Nueva tarjeta de estadísticas: total gastado juntos, cantidad de gastos compartidos y último movimiento', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.group_rounded, text: 'Desglose de deudas por grupo directo en la ventana de persona', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.label_rounded, text: 'Historial mejorado: badges de tipo (Compartido, Préstamo, Liquidado, Cobrado) en cada movimiento', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.handshake_rounded, text: 'Liquidar con saldo 0 muestra mensaje "Al día" en vez de fallar silenciosamente', type: _ChangeType.improvement),
            ],
          ),

          // v1.5.2
          _VersionCard(
            version: 'v1.5.2',
            date: '5 Abr 2026',
            isCurrent: false,
            items: const [
              _ChangeItem(icon: Icons.bug_report_rounded, text: 'Fix: vincular amigo ya no falla si no tenés personas en tu lista', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.keyboard_rounded, text: 'Nuevo: ingreso manual de código de amigo como alternativa al QR', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.send_rounded, text: 'Nueva pestaña "Enviadas" en Solicitudes para ver qué solicitudes mandaste', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.cancel_rounded, text: 'Podés cancelar solicitudes enviadas desde la misma pantalla', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.error_outline_rounded, text: 'Mensajes de error más claros al vincular amigos (sin conexión, usuario no encontrado, etc.)', type: _ChangeType.improvement),
            ],
          ),

          // v1.5.1
          _VersionCard(
            version: 'v1.5.1',
            date: '5 Abr 2026',
            isCurrent: false,
            items: const [
              _ChangeItem(icon: Icons.view_list_rounded, text: 'Pantalla de movimientos rediseñada: más clara, fácil de leer y de navegar', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.bar_chart_rounded, text: 'Nuevo resumen con columnas Ingresos / Gastos / Balance bien separadas y coloreadas', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.calendar_month_rounded, text: 'Filtro de meses mejorado: nombres completos y selección por pastilla', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.tune_rounded, text: 'Filtros por tipo (Todos / Ingresos / Gastos / Compartidos) como control segmentado', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.label_rounded, text: 'Categoría visible como badge de color en cada transacción', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.access_time_rounded, text: 'Hora del movimiento visible en cada transacción', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.today_rounded, text: 'Encabezados de día simplificados: solo la fecha, sin balance diario confuso', type: _ChangeType.improvement),
            ],
          ),

          // v1.5.0
          _VersionCard(
            version: 'v1.5.0',
            date: '5 Abr 2026',
            isCurrent: false,
            items: const [
              _ChangeItem(icon: Icons.account_balance_wallet_rounded, text: 'Integración con Mercado Pago: conectá tu cuenta con Access Token', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.sync_rounded, text: 'Sincronización automática: movimientos de MP se importan como transacciones reales', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.auto_awesome_rounded, text: 'Categorización con IA: tus movimientos se categorizan automáticamente con Claude', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.dashboard_rounded, text: 'Widget de Mercado Pago en el Home: saldo y últimos movimientos', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.account_balance_rounded, text: 'Cuenta Mercado Pago integrada: saldo sincronizado con reportes y presupuestos', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.schedule_rounded, text: 'Auto-sync al abrir la app con cooldown de 15 min', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.check_circle_rounded, text: 'Protección contra duplicados: doble capa con IDs y notas', type: _ChangeType.improvement),
            ],
          ),

          // v1.4.1
          _VersionCard(
            version: 'v1.4.1',
            date: '5 Abr 2026',
            items: const [
              _ChangeItem(icon: Icons.sync_rounded, text: 'Gastos compartidos ahora se sincronizan con amigos vinculados por Firestore', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.person_add_rounded, text: 'Aceptar solicitud de amistad crea la persona automáticamente si no existe', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.handshake_rounded, text: 'Liquidar deuda notifica al amigo vinculado en tiempo real', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.photo_rounded, text: 'Perfil de amigo vinculado muestra foto de Google y badge "Vinculado"', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.badge_rounded, text: 'Gastos entrantes usan el nombre real del sender en vez de "Amigo"', type: _ChangeType.fix),
            ],
          ),

          // v1.4.0
          _VersionCard(
            version: 'v1.4.0',
            date: '5 Abr 2026',
            items: const [
              _ChangeItem(icon: Icons.login_rounded, text: 'Login rediseñado: Google, cuenta local o datos demo', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.school_rounded, text: 'Onboarding mejorado: 10 slides, sin modal, directo al login', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.cloud_sync_rounded, text: 'Conectar Google desde Configuración si empezaste sin cuenta', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.cloud_download_rounded, text: 'Auto-restauración de backup al iniciar sesión con Google', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.notifications_active_rounded, text: 'Notificaciones push: vencimientos y recordatorios de deudas', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.volume_up_rounded, text: 'Sonidos y háptica controlados por switch en toda la app', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.edit_rounded, text: 'App renombrada a Sencillo en todo el proyecto y GitHub', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.delete_forever_rounded, text: '"Borrar datos" ahora cierra sesión y vuelve al login', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.replay_rounded, text: 'Botón "Ver tutorial" disponible desde la pantalla de login', type: _ChangeType.feature),
            ],
          ),

          // v1.3.6

          // v1.3.5 (merged into v1.3.6)

          // v1.3.4
          _VersionCard(
            version: 'v1.3.4',
            date: '5 Abr 2026',
            items: const [
              _ChangeItem(icon: Icons.credit_card_rounded, text: 'Fix: lista de cuentas ahora muestra gastos del período igual que el detalle', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.calculate_rounded, text: 'Disponible de tarjetas calculado por ciclo de facturación, no balance total', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.vibration_rounded, text: 'Háptica controlada por switch en Configuración en toda la app', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.auto_awesome_rounded, text: 'Login: ícono integrado sin bordes, partículas sutiles, ripple al tocar', type: _ChangeType.improvement),
            ],
          ),

          // v1.3.3
          _VersionCard(
            version: 'v1.3.3',
            date: '5 Abr 2026',
            items: const [
              _ChangeItem(icon: Icons.sync_alt_rounded, text: 'Fix: cambiar cuenta de un movimiento actualiza saldo en ambas cuentas', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.edit_rounded, text: 'Fix: editar una cuenta (nombre, saldo, etc.) ahora se refleja al instante', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.animation_rounded, text: 'FAB se transforma entre todas las pestañas del navbar, sin solapamiento', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.image_rounded, text: 'Ícono del login se integra sin bordes con el fondo', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.credit_card_rounded, text: '"Gastos del período" ahora muestra solo el ciclo de facturación actual', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.touch_app_rounded, text: 'Login: efecto ripple interactivo al tocar la pantalla', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.auto_awesome_rounded, text: 'Login: 18 partículas flotantes con brillo y órbitas variadas', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.vibration_rounded, text: 'Configuración: switch para activar/desactivar háptica y sonidos', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.qr_code_rounded, text: 'QR card: nombre completo visible, botones en fila separada', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.text_fields_rounded, text: 'App renombrada a "Sencillo" con tipografía Quicksand', type: _ChangeType.improvement),
            ],
          ),

          // v1.3.2
          _VersionCard(
            version: 'v1.3.2',
            date: '5 Abr 2026',
            items: const [
              _ChangeItem(icon: Icons.edit_rounded, text: 'Fix: editar gastos compartidos ahora guarda cuenta, categoría y fecha', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.layers_clear_rounded, text: 'Fix: FAB ya no se solapa en cuentas cuando está fijada en el navbar', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.login_rounded, text: 'Login rediseñado: logo más grande, fuente Poppins, botón con gradiente', type: _ChangeType.improvement),
            ],
          ),

          // v1.3.1
          _VersionCard(
            version: 'v1.3.1',
            date: '5 Abr 2026',
            items: const [
              _ChangeItem(icon: Icons.credit_card_rounded, text: 'Fix: tarjetas de crédito ya no muestran valores negativos', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.expand_more_rounded, text: 'Cuotas pendientes: widget colapsable con resumen compacto', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.auto_awesome_rounded, text: 'Splash animado con ícono de la app, efectos de brillo y partículas', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.sync_rounded, text: 'Overlay de sincronización rediseñado, más limpio', type: _ChangeType.improvement),
            ],
          ),

          // v1.3.0
          _VersionCard(
            version: 'v1.3.0',
            date: '5 Abr 2026',
            items: const [
              _ChangeItem(icon: Icons.person_rounded, text: 'Mi Perfil: card con avatar, nombre y código en Más', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.qr_code_rounded, text: 'QR colapsable: botones Mostrar QR y Escanear', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.edit_rounded, text: 'Fix: editar movimiento ahora guarda todos los cambios correctamente', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.refresh_rounded, text: 'Fix: refresh del dólar muestra timestamp correcto', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.animation_rounded, text: 'Fix: FAB ya no se oculta al cambiar de pestaña, transición suave', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.qr_code_scanner_rounded, text: 'Personas: opción "Escanear QR de amigo" en el menú +', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.info_outline_rounded, text: 'Versión de la app visible en el menú Más', type: _ChangeType.improvement),
            ],
          ),

          // v1.2.0
          _VersionCard(
            version: 'v1.2.0',
            date: '5 Abr 2026',
            items: const [
              _ChangeItem(icon: Icons.refresh_rounded, text: 'Cotización del dólar: botón refresh manual + auto-refresh cada 15 min', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.rocket_launch_rounded, text: 'Pantalla de Novedades con historial de versiones', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.volunteer_activism_rounded, text: 'Sección de donaciones: Cafecito, Mercado Pago, GitHub', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.play_circle_outline, text: 'Botón "Restablecer tutorial" en Configuración', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.auto_awesome_rounded, text: 'Onboarding: opción de cargar datos de ejemplo', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.animation_rounded, text: 'FAB: transición suave con AnimatedSwitcher entre tabs', type: _ChangeType.improvement),
            ],
          ),

          // v1.1.0
          _VersionCard(
            version: 'v1.1.0',
            date: '3 Abr 2026',
            items: const [
              _ChangeItem(icon: Icons.people_rounded, text: 'Sistema de amigos con QR y gastos compartidos', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.cloud_rounded, text: 'Backup y restauración en la nube (Firebase Storage)', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.notifications_active_rounded, text: 'Alertas inteligentes: presupuesto, metas, deudas', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.qr_code_rounded, text: 'Mi QR: compartí tu perfil y agregá amigos', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.currency_exchange_rounded, text: 'Widget de cotizaciones con conversor ARS ↔ USD', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.tab_rounded, text: 'Personalización del navbar: elegí y reordená pestañas', type: _ChangeType.improvement),
            ],
          ),

          // v1.0.2
          _VersionCard(
            version: 'v1.0.2',
            date: '2 Abr 2026',
            items: const [
              _ChangeItem(icon: Icons.credit_card_rounded, text: 'Tarjetas de crédito: cierre, vencimiento, resumen pendiente', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.shopping_cart_rounded, text: 'Lista de deseos con recordatorio configurable', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.bar_chart_rounded, text: 'Reportes: gráficos por categoría y tendencias', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.calendar_month_rounded, text: 'Resumen y cierre de mes con wizard', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.bug_report_rounded, text: 'Fix: formato de montos con separador de miles', type: _ChangeType.fix),
              _ChangeItem(icon: Icons.undo_rounded, text: 'Fix: deshacer pagos y edición de transacciones', type: _ChangeType.fix),
            ],
          ),

          // v1.0.1
          _VersionCard(
            version: 'v1.0.1',
            date: '1 Abr 2026',
            items: const [
              _ChangeItem(icon: Icons.savings_rounded, text: 'Metas de ahorro con barra de progreso', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.person_rounded, text: 'Perfil: nombre, sueldo y día de cobro', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.auto_awesome_rounded, text: 'Parser IA de transacciones por texto natural', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.mic_rounded, text: 'Entrada por voz para registrar movimientos', type: _ChangeType.feature),
            ],
          ),

          // v1.0.0
          _VersionCard(
            version: 'v1.0.0',
            date: '30 Mar 2026',
            items: const [
              _ChangeItem(icon: Icons.rocket_launch_rounded, text: 'Lanzamiento inicial de SENCILLO', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.account_balance_wallet_rounded, text: 'Dashboard con balance total y cuentas', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.swap_horiz_rounded, text: 'CRUD de transacciones con categorías', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.donut_large_rounded, text: 'Presupuesto por categoría con alertas', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.login_rounded, text: 'Google Sign-In con Firebase Auth', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.school_rounded, text: 'Onboarding con slides de bienvenida', type: _ChangeType.feature),
            ],
          ),

          const SizedBox(height: 24),

          // Roadmap
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.colorTransfer.withValues(alpha: 0.12),
                  AppTheme.colorTransfer.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.colorTransfer.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.map_rounded, color: AppTheme.colorTransfer, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Próximamente',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _RoadmapItem(text: 'Wishlist compartida: que tus amigos vean qué regalarte', icon: Icons.card_giftcard_rounded),
                _RoadmapItem(text: 'Ahorro compartido: metas grupales con amigos', icon: Icons.group_work_rounded),
                _RoadmapItem(text: 'Exportar reportes a PDF', icon: Icons.picture_as_pdf_rounded),
                _RoadmapItem(text: 'Widgets de pantalla de inicio', icon: Icons.widgets_rounded),
                _RoadmapItem(text: 'Sincronización multi-dispositivo', icon: Icons.sync_rounded),
                _RoadmapItem(text: 'Modo claro / tema personalizable', icon: Icons.palette_rounded),
                _RoadmapItem(text: 'Gastos recurrentes automáticos', icon: Icons.repeat_rounded),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Version Card
// ─────────────────────────────────────────────
class _VersionCard extends StatelessWidget {
  final String version;
  final String date;
  final bool isCurrent;
  final List<_ChangeItem> items;

  const _VersionCard({
    required this.version,
    required this.date,
    this.isCurrent = false,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppTheme.colorTransfer.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent
              ? AppTheme.colorTransfer.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppTheme.colorTransfer.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  version,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isCurrent ? AppTheme.colorTransfer : Colors.white54,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                date,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
              ),
              const Spacer(),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.colorIncome.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ACTUAL',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.colorIncome,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: item.type.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(item.icon, size: 13, color: item.type.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          item.text,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

enum _ChangeType {
  feature,
  improvement,
  fix;

  Color get color {
    switch (this) {
      case _ChangeType.feature:
        return AppTheme.colorTransfer;
      case _ChangeType.improvement:
        return AppTheme.colorIncome;
      case _ChangeType.fix:
        return AppTheme.colorWarning;
    }
  }
}

class _ChangeItem {
  final IconData icon;
  final String text;
  final _ChangeType type;

  const _ChangeItem({required this.icon, required this.text, required this.type});
}

class _RoadmapItem extends StatelessWidget {
  final String text;
  final IconData icon;

  const _RoadmapItem({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.colorTransfer.withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Banner de versión actual
// ─────────────────────────────────────────────────────────
class _CurrentVersionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.colorTransfer.withValues(alpha: 0.12),
            AppTheme.colorIncome.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.colorTransfer.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          // Icono animado
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.colorTransfer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.rocket_launch_rounded, color: AppTheme.colorTransfer, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Sencillo',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.colorTransfer.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.colorTransfer.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        'v1.8.0',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.colorTransfer,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Version actual · 13 de Abril 2026',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Badge "Al día"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.colorIncome.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.colorIncome),
                const SizedBox(width: 4),
                Text(
                  'Al día',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.colorIncome),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Tutoría visual por pantalla. Cada entrada es un script de 2-5 cards.
// La clave es el `pageId` (ej. 'transactions'), el valor es la lista de cards.

class CoachCard {
  final String emoji;
  final String title;
  final String body;
  final String? tip;
  const CoachCard({
    required this.emoji,
    required this.title,
    required this.body,
    this.tip,
  });
}

const Map<String, List<CoachCard>> kPageCoaches = {
  'home_fab_ia': [
    CoachCard(
      emoji: '👇',
      title: 'Tu primer gasto, en 5 segundos',
      body:
          'Tocá el botón violeta abajo y escribí lo que gastaste. La IA detecta categoría, monto y cuenta sola.',
      tip: 'Probá: "café 3500" o "uber al centro 4200".',
    ),
    CoachCard(
      emoji: '🎤',
      title: 'También por voz',
      body:
          'Mantené apretado el botón para dictar el gasto. Al soltar se procesa solo.',
    ),
    CoachCard(
      emoji: '🔁',
      title: 'Doble tap = duplicar',
      body:
          'Si gastás en lo mismo seguido (ej: dos cafés en el día), doble tap al botón duplica el último.',
    ),
  ],
  'transactions': [
    CoachCard(
      emoji: '📋',
      title: 'Movimientos',
      body:
          'Acá ves todos tus gastos e ingresos. Podés filtrarlos por día, semana o mes con los chips de arriba.',
    ),
    CoachCard(
      emoji: '👆',
      title: 'Editar o borrar',
      body:
          'Deslizá un movimiento hacia la izquierda para borrarlo, o tocálo para ver detalle y editarlo.',
    ),
    CoachCard(
      emoji: '🔍',
      title: 'Buscar',
      body:
          'Tocá el ícono de lupa (FAB) para buscar un movimiento por título o monto.',
    ),
  ],
  'addTransaction': [
    CoachCard(
      emoji: '✨',
      title: 'Cargar un movimiento',
      body:
          'Escribí en lenguaje natural y la IA entiende solita. Mirá los ejemplos ↓',
    ),
    CoachCard(
      emoji: '💸',
      title: 'Ejemplo: gasto simple',
      body: '"Gasté 3.500 en el super"',
      tip: 'La IA detecta monto y categoría (Comida).',
    ),
    CoachCard(
      emoji: '👥',
      title: 'Ejemplo: compartir con un amigo',
      body: '"Dividí 12.000 de pizza con Juan"',
      tip:
          'Crea el gasto y registra que Juan te debe la mitad. Si Juan no existe, lo agrega solo.',
    ),
    CoachCard(
      emoji: '💰',
      title: 'Ejemplo: cobrar',
      body: '"Juan me pagó 6.000"',
      tip: 'Registra ingreso y cierra la deuda pendiente con Juan.',
    ),
    CoachCard(
      emoji: '🎤',
      title: 'Por voz',
      body:
          'Tocá el micrófono, dictá el movimiento y al terminar de hablar se procesa solo.',
    ),
  ],
  'budget': [
    CoachCard(
      emoji: '📊',
      title: 'Presupuestos',
      body:
          'Definí un tope mensual por categoría (ej: Comida \$80.000). Te vamos mostrando en barra cuánto usaste.',
    ),
    CoachCard(
      emoji: '🚨',
      title: 'Alertas automáticas',
      body:
          'Cuando llegás al 80% o te pasás, la app te avisa para que ajustes.',
    ),
    CoachCard(
      emoji: '➕',
      title: 'Agregar uno',
      body:
          'Tocá el botón + (FAB) para crear un presupuesto nuevo. Podés copiarlo del mes anterior.',
    ),
  ],
  'goals': [
    CoachCard(
      emoji: '🎯',
      title: 'Metas de ahorro',
      body:
          'Creá objetivos concretos: vacaciones, moto, casa. Definís monto y fecha, y te mostramos el progreso.',
    ),
    CoachCard(
      emoji: '💰',
      title: 'Aportar',
      body:
          'Tocá una meta y usá "Aportar" para sumar plata. Se descuenta de la cuenta que elijas.',
    ),
    CoachCard(
      emoji: '⏱️',
      title: 'Ritmo sugerido',
      body:
          'Calculamos cuánto tenés que ahorrar por mes para llegar a tiempo, según tu fecha objetivo.',
    ),
  ],
  'monthly_overview': [
    CoachCard(
      emoji: '📆',
      title: 'Resumen del mes',
      body:
          'Todo lo del mes actual en una sola pantalla: gastos por categoría, ingresos, balance, metas.',
    ),
    CoachCard(
      emoji: '📑',
      title: 'Escanear resumen',
      body:
          'Podés subir el PDF del resumen de tu tarjeta y la app extrae todos los movimientos automáticamente.',
    ),
    CoachCard(
      emoji: '🔄',
      title: 'Cambiar de mes',
      body:
          'Deslizá o tocá el selector de mes arriba para ver meses anteriores y comparar.',
    ),
  ],
  'wishlist': [
    CoachCard(
      emoji: '🛒',
      title: 'Antojos',
      body:
          'Anotá cosas que querés comprar pero no son urgentes. Te ayuda a no gastar de impulso.',
    ),
    CoachCard(
      emoji: '💭',
      title: 'Pensarlo mejor',
      body:
          'Ponele precio y fecha tentativa. Si después de unos días seguís queriéndolo, comprálo con conciencia.',
    ),
    CoachCard(
      emoji: '🎁',
      title: 'Compartir con amigos',
      body:
          'Tu lista es visible para tus contactos de la app (próximamente). Ideal para cumples.',
    ),
  ],
  'reports': [
    CoachCard(
      emoji: '📈',
      title: 'Análisis',
      body:
          'Gráficos de tendencia mensual, gastos por categoría, comparativas de meses. Todo lo que te muestra patrones.',
    ),
    CoachCard(
      emoji: '💡',
      title: 'Insights',
      body:
          'La app detecta cosas tipo "gastaste 30% más en delivery este mes" para que tomes decisiones.',
    ),
  ],
  'accounts': [
    CoachCard(
      emoji: '💳',
      title: 'Cuentas',
      body:
          'Todas tus cuentas en un lugar: efectivo, débito, crédito, billeteras digitales (MP, Ualá, etc.).',
    ),
    CoachCard(
      emoji: '📅',
      title: 'Tarjetas de crédito',
      body:
          'Agregá día de cierre y vencimiento. Te recordamos antes para que no se te pase.',
    ),
    CoachCard(
      emoji: '🔗',
      title: 'Vincular Mercado Pago',
      body:
          'Podés conectar tu cuenta de MP y se sincronizan los movimientos automáticamente.',
    ),
  ],
  'savings': [
    CoachCard(
      emoji: '🐷',
      title: 'Ahorros',
      body:
          'Guardá plata en cuentas separadas (no se mezcla con tu día a día). Ideal para plazo fijo, dólares, cripto.',
    ),
    CoachCard(
      emoji: '💵',
      title: 'Mover entre cuentas',
      body:
          'Usá "Transferir" para mover plata de tu cuenta principal al ahorro — queda registrado y no cuenta como gasto.',
    ),
  ],
  'more': [
    CoachCard(
      emoji: '📂',
      title: 'Menú Más',
      body:
          'Acá están todas las herramientas extra: personas (amigos), antojos, análisis, ajustes, novedades, etc.',
    ),
    CoachCard(
      emoji: '⚙️',
      title: 'Personalización',
      body:
          'En Ajustes podés configurar tu perfil, cuentas, presupuestos, categorías, idioma, notificaciones.',
    ),
    CoachCard(
      emoji: '🔔',
      title: 'Notificaciones',
      body:
          'Activá recordatorios diarios, alertas de cierre de tarjeta, y recordatorios de deudas con amigos.',
    ),
  ],
  'people': [
    CoachCard(
      emoji: '👥',
      title: 'Personas',
      body:
          'Tu lista de contactos de la app. Llevá cuenta de lo que te deben y lo que debés.',
    ),
    CoachCard(
      emoji: '➕',
      title: 'Agregar un amigo',
      body:
          'Tocá el + y elegí "Agregar persona" (solo nombre) o "Vincular amigo" (si también usa Sencillo).',
    ),
    CoachCard(
      emoji: '🤝',
      title: 'Deudas compartidas',
      body:
          'Cuando dividís un gasto con alguien, aparece su saldo acá. Tocá "Saldar" cuando te pague.',
    ),
  ],
  'transaction_detail': [
    CoachCard(
      emoji: '📝',
      title: 'Detalle del movimiento',
      body:
          'Acá ves y editás todo: título, monto, categoría, cuenta, fecha y nota.',
    ),
    CoachCard(
      emoji: '📋',
      title: 'Duplicar',
      body:
          'Tocá "Duplicar" para repetir este movimiento con fecha de hoy — ideal para gastos recurrentes.',
    ),
    CoachCard(
      emoji: '🗑️',
      title: 'Borrar',
      body:
          'Tocá el ícono de tacho para borrarlo. Podés deshacer desde el SnackBar que aparece abajo.',
    ),
  ],
  'account_detail': [
    CoachCard(
      emoji: '💳',
      title: 'Detalle de cuenta',
      body:
          'Ves el saldo actual, el historial de movimientos y los datos de la cuenta.',
    ),
    CoachCard(
      emoji: '✏️',
      title: 'Editar',
      body:
          'Tocá el lápiz para cambiar nombre, tipo, color, día de cierre o vencimiento (si es tarjeta).',
    ),
    CoachCard(
      emoji: '📦',
      title: 'Archivar',
      body:
          'Si ya no usás esta cuenta, podés archivarla. No se borra; queda oculta pero el historial se mantiene.',
    ),
  ],
  'settings': [
    CoachCard(
      emoji: '⚙️',
      title: 'Ajustes',
      body:
          'Configurá tu perfil, moneda, IA, backup, notificaciones y categorías desde acá.',
    ),
    CoachCard(
      emoji: '☁️',
      title: 'Backup en la nube',
      body:
          'Si conectás Google, tus datos se guardan en la nube y los recuperás al logear en otro dispositivo.',
    ),
    CoachCard(
      emoji: '🎨',
      title: 'Personalización',
      body:
          'Podés ocultar tabs, repetir el tour, resetear las guías por pantalla y más.',
    ),
  ],
  'recurring': [
    CoachCard(
      emoji: '🔁',
      title: 'Movimientos recurrentes',
      body:
          'Acá definís gastos/ingresos que se repiten todos los meses (sueldo, alquiler, Netflix).',
    ),
    CoachCard(
      emoji: '📅',
      title: 'Se cargan solos',
      body:
          'El día configurado, el movimiento aparece automáticamente. Te avisamos con una notificación.',
    ),
    CoachCard(
      emoji: '⏸️',
      title: 'Pausar',
      body:
          'Si dejás de pagar algo (ej: cancelaste Spotify), tocá el toggle para pausarlo sin borrarlo.',
    ),
  ],
  'notifications': [
    CoachCard(
      emoji: '🔔',
      title: 'Notificaciones',
      body:
          'Configurá qué te recordamos: cargar gastos diarios, resumen semanal, cierres de tarjeta.',
    ),
    CoachCard(
      emoji: '⏰',
      title: 'A qué hora',
      body:
          'Elegí la hora del recordatorio diario. Por defecto, 21:00 — antes de dormir.',
    ),
    CoachCard(
      emoji: '🚨',
      title: 'Alertas de presupuesto',
      body:
          'Te avisamos cuando llegás al 80% o te pasaste del tope de alguna categoría.',
    ),
  ],
  'person_detail': [
    CoachCard(
      emoji: '👤',
      title: 'Detalle de persona',
      body:
          'Ves el saldo neto (si te debe o le debés) y todo el historial compartido con esa persona.',
    ),
    CoachCard(
      emoji: '✅',
      title: 'Saldar deuda',
      body:
          'Cuando recibís o das la plata, tocá "Saldar". La deuda se cierra y queda registrada.',
    ),
    CoachCard(
      emoji: '➗',
      title: 'Dividir un gasto',
      body:
          'Desde acá podés crear un gasto compartido directo con esta persona.',
    ),
  ],
  'budget_detail': [
    CoachCard(
      emoji: '📊',
      title: 'Detalle de presupuesto',
      body:
          'Ves cuánto llevás gastado del tope, y los movimientos que cuentan para este presupuesto.',
    ),
    CoachCard(
      emoji: '🎯',
      title: 'Editar tope',
      body:
          'Tocá el monto para cambiar el límite. Podés ajustarlo mes a mes según tu ritmo.',
    ),
    CoachCard(
      emoji: '📋',
      title: 'Copiar del mes anterior',
      body:
          'Cuando arranca el mes, podés duplicar los presupuestos del mes pasado con un toque.',
    ),
  ],
};

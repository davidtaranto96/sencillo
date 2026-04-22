import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../database/app_database.dart';
import '../database/database_providers.dart' show databaseProvider;
import '../providers/feedback_provider.dart';

// ── Notification IDs ──
const _kCardDueChannel = 'card_due_dates';
const _kDebtReminderChannel = 'debt_reminders';
const _kGeneralChannel = 'general';
const _kDailyReminderChannel = 'daily_reminder';
const _kBudgetExceededChannel = 'budget_exceeded';
const _kWeeklySummaryChannel = 'weekly_summary';

// Notification ID ranges
const _kCardDueBaseId = 1000;
const _kDebtReminderBaseId = 2000;
const _kDailyReminderId = 3000;
const _kWeeklySummaryId = 3001;
const _kBudgetExceededBaseId = 4000;

// Notification action IDs
const kActionAddExpense = 'add_expense';
const kActionDismiss = 'dismiss';

// Prefs keys
const _kNotifCardDueEnabled = 'notif_card_due_enabled';
const _kNotifDebtRemindEnabled = 'notif_debt_remind_enabled';
const _kNotifCardDueDaysBefore = 'notif_card_due_days_before';
const _kNotifDebtRemindDays = 'notif_debt_remind_days';
const _kNotifDailyReminderEnabled = 'notif_daily_reminder_enabled';
const _kNotifDailyReminderHour = 'notif_daily_reminder_hour';
const _kNotifDailyReminderMinute = 'notif_daily_reminder_minute';
const _kNotifWeeklySummaryEnabled = 'notif_weekly_summary_enabled';

/// Global plugin instance
final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

/// Provider for the notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final db = ref.watch(databaseProvider);
  return NotificationService(db);
});

/// Settings providers
final notifCardDueEnabledProvider =
    StateNotifierProvider<BoolPrefNotifier, bool>(
  (ref) => BoolPrefNotifier(_kNotifCardDueEnabled, defaultValue: true),
);

final notifDebtRemindEnabledProvider =
    StateNotifierProvider<BoolPrefNotifier, bool>(
  (ref) => BoolPrefNotifier(_kNotifDebtRemindEnabled, defaultValue: true),
);

final notifCardDueDaysBeforeProvider =
    StateNotifierProvider<IntPrefNotifier, int>(
  (ref) => IntPrefNotifier(_kNotifCardDueDaysBefore, defaultValue: 3),
);

final notifDebtRemindDaysProvider =
    StateNotifierProvider<IntPrefNotifier, int>(
  (ref) => IntPrefNotifier(_kNotifDebtRemindDays, defaultValue: 7),
);

final notifDailyReminderEnabledProvider =
    StateNotifierProvider<BoolPrefNotifier, bool>(
  (ref) => BoolPrefNotifier(_kNotifDailyReminderEnabled, defaultValue: false),
);

final notifDailyReminderHourProvider =
    StateNotifierProvider<IntPrefNotifier, int>(
  (ref) => IntPrefNotifier(_kNotifDailyReminderHour, defaultValue: 21),
);

final notifDailyReminderMinuteProvider =
    StateNotifierProvider<IntPrefNotifier, int>(
  (ref) => IntPrefNotifier(_kNotifDailyReminderMinute, defaultValue: 0),
);

final notifWeeklySummaryEnabledProvider =
    StateNotifierProvider<BoolPrefNotifier, bool>(
  (ref) => BoolPrefNotifier(_kNotifWeeklySummaryEnabled, defaultValue: false),
);

/// Int-backed pref notifier
class IntPrefNotifier extends StateNotifier<int> {
  final String key;
  IntPrefNotifier(this.key, {int defaultValue = 0}) : super(defaultValue) {
    _load();
  }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(key) ?? state;
  }
  Future<void> set(int value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, state);
  }
}

/// In-app notification model (for the notification center)
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'card_due', 'debt_remind', 'general'
  final DateTime createdAt;
  final bool read;
  final String? relatedId; // accountId or personId

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.read = false,
    this.relatedId,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        createdAt: createdAt,
        read: read ?? this.read,
        relatedId: relatedId,
      );
}

/// In-app notification center state
final notificationCenterProvider =
    StateNotifierProvider<NotificationCenterNotifier, List<AppNotification>>(
  (ref) => NotificationCenterNotifier(),
);

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationCenterProvider);
  return notifications.where((n) => !n.read).length;
});

class NotificationCenterNotifier extends StateNotifier<List<AppNotification>> {
  NotificationCenterNotifier() : super([]) {
    _loadDismissed();
  }

  /// IDs descartados por el usuario — sobreviven reinicios de app.
  /// Si un ID está acá, _checkInAppAlerts no puede volver a crearlo.
  final Set<String> _dismissedIds = {};

  Future<void> _loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('dismissed_notification_ids') ?? [];
    _dismissedIds.addAll(list);
  }

  Future<void> _saveDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'dismissed_notification_ids', _dismissedIds.toList());
  }

  void add(AppNotification notification) {
    // No re-crear notificaciones que el usuario ya descartó
    if (_dismissedIds.contains(notification.id)) return;
    // Dedup: no agregar si ya existe con el mismo ID
    if (state.any((n) => n.id == notification.id)) return;

    state = [notification, ...state];
    // Keep max 50 notifications
    if (state.length > 50) {
      state = state.sublist(0, 50);
    }
  }

  void markAsRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(read: true) else n,
    ];
  }

  void markAllAsRead() {
    state = [for (final n in state) n.copyWith(read: true)];
  }

  void remove(String id) {
    _dismissedIds.add(id);
    _saveDismissed();
    state = state.where((n) => n.id != id).toList();
  }

  void clear() {
    // Marcar todas las IDs actuales como descartadas
    for (final n in state) {
      _dismissedIds.add(n.id);
    }
    _saveDismissed();
    state = [];
  }

  /// Limpia las IDs descartadas que ya tienen más de 30 días
  /// (para que las notificaciones del mes siguiente sí aparezcan).
  void pruneOldDismissals() {
    // Los IDs de alertas incluyen el mes (ej: card_due_xxx_4) o día.
    // Prunear por tamaño — si hay más de 200, sacar los más viejos.
    if (_dismissedIds.length > 200) {
      final sorted = _dismissedIds.toList()..sort();
      _dismissedIds.clear();
      _dismissedIds.addAll(sorted.skip(sorted.length - 100));
      _saveDismissed();
    }
  }
}

class NotificationService {
  final AppDatabase _db;

  NotificationService(this._db);

  /// Initialize the notification plugin
  /// Callback invoked when a notification action button is tapped.
  /// Set by the app shell to navigate to the appropriate screen.
  static void Function(String actionId)? onActionTapped;

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final actionId = response.actionId;
        if (actionId != null && actionId.isNotEmpty) {
          onActionTapped?.call(actionId);
        } else {
          // Tapped the notification body → default to add expense
          onActionTapped?.call(kActionAddExpense);
        }
      },
    );

    // Create notification channels on Android
    if (Platform.isAndroid) {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _kCardDueChannel,
            'Vencimientos de tarjetas',
            description: 'Recordatorios de fechas de cierre y vencimiento',
            importance: Importance.high,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _kDebtReminderChannel,
            'Recordatorios de deudas',
            description: 'Recordatorios de deudas pendientes con amigos',
            importance: Importance.defaultImportance,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _kGeneralChannel,
            'General',
            description: 'Notificaciones generales de Sencillo',
            importance: Importance.defaultImportance,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _kDailyReminderChannel,
            'Recordatorio diario',
            description: 'Recordatorio para registrar gastos del día',
            importance: Importance.defaultImportance,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'expense_detection',
            'Gastos detectados',
            description: 'Sugerencias de gasto desde notificaciones bancarias',
            importance: Importance.high,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _kBudgetExceededChannel,
            'Presupuesto excedido',
            description: 'Alertas cuando se supera un presupuesto',
            importance: Importance.high,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _kWeeklySummaryChannel,
            'Resumen semanal',
            description: 'Resumen de gastos de la semana',
            importance: Importance.defaultImportance,
          ),
        );
      }
    }
  }

  /// Request notification permissions (Android 13+, iOS)
  static Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  /// Schedule card due date reminders based on closing days
  Future<void> scheduleCardDueReminders({
    required int daysBefore,
  }) async {
    // Cancel existing card reminders
    await cancelCardDueReminders();

    final accounts = await _db.select(_db.accountsTable).get();
    final creditCards = accounts.where(
      (a) => a.type == 'credit' && a.closingDay != null,
    );

    int idx = 0;
    for (final card in creditCards) {
      final closingDay = card.closingDay!;
      final now = DateTime.now();

      // Calculate next closing date
      DateTime nextClosing;
      if (now.day <= closingDay) {
        nextClosing = DateTime(now.year, now.month, closingDay);
      } else {
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear = now.month == 12 ? now.year + 1 : now.year;
        nextClosing = DateTime(nextYear, nextMonth, closingDay);
      }

      // Schedule reminder X days before closing
      final reminderDate = nextClosing.subtract(Duration(days: daysBefore));
      if (reminderDate.isAfter(now)) {
        final scheduledDate = tz.TZDateTime.from(
          DateTime(reminderDate.year, reminderDate.month, reminderDate.day, 10, 0),
          tz.local,
        );

        await _plugin.zonedSchedule(
          _kCardDueBaseId + idx,
          '💳 Vencimiento próximo',
          '${card.name} cierra en $daysBefore días (día $closingDay)',
          scheduledDate,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _kCardDueChannel,
              'Vencimientos de tarjetas',
              icon: '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
              color: const Color(0xFF6C63FF),
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );
      }
      idx++;
    }
  }

  /// Schedule debt reminders for people who owe money
  Future<void> scheduleDebtReminders({
    required int everyDays,
  }) async {
    // Cancel existing debt reminders
    await cancelDebtReminders();

    final persons = await _db.select(_db.personsTable).get();
    final withDebt = persons.where((p) => p.totalBalance.abs() > 0);

    int idx = 0;
    for (final person in withDebt) {
      final now = DateTime.now();
      final reminderDate = now.add(Duration(days: everyDays));
      final scheduledDate = tz.TZDateTime.from(
        DateTime(reminderDate.year, reminderDate.month, reminderDate.day, 11, 0),
        tz.local,
      );

      final owesMe = person.totalBalance > 0;
      final amount = person.totalBalance.abs();
      final amountStr = '\$${amount.toStringAsFixed(0)}';

      await _plugin.zonedSchedule(
        _kDebtReminderBaseId + idx,
        owesMe ? '🔔 Te deben plata' : '🔔 Deuda pendiente',
        owesMe
            ? '${person.name} te debe $amountStr'
            : 'Le debés $amountStr a ${person.name}',
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kDebtReminderChannel,
            'Recordatorios de deudas',
            icon: '@mipmap/ic_launcher',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            color: const Color(0xFF6C63FF),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      idx++;
    }
  }

  /// Show an immediate notification (for in-app events)
  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String channel = _kGeneralChannel,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channel == _kCardDueChannel
              ? 'Vencimientos de tarjetas'
              : channel == _kDebtReminderChannel
                  ? 'Recordatorios de deudas'
                  : 'General',
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF6C63FF),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Schedule daily expense reminder at configured time with dynamic content.
  /// Calculates today's spending summary and shows it in the notification.
  Future<void> scheduleDailyReminder({required int hour, required int minute}) async {
    await _plugin.cancel(_kDailyReminderId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    // Calculate today's summary for dynamic content
    final summary = await _getDailySummary();

    await _plugin.zonedSchedule(
      _kDailyReminderId,
      summary.title,
      summary.body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kDailyReminderChannel,
          'Recordatorio diario',
          icon: '@mipmap/ic_launcher',
          importance: Importance.defaultImportance,
          color: const Color(0xFF6C63FF),
          actions: const [
            AndroidNotificationAction(
              kActionAddExpense,
              'Agregar gasto',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              kActionDismiss,
              'Todo listo',
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Calculate today's expense summary for the daily reminder notification.
  Future<({String title, String body})> _getDailySummary() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final allExpenses = await (_db.select(_db.transactionsTable)
          ..where((t) => t.type.equals('expense')))
        .get();
    final rows = allExpenses.where((t) =>
        !t.date.isBefore(startOfDay) && t.date.isBefore(endOfDay)).toList();

    if (rows.isEmpty) {
      return (
        title: 'No registraste gastos hoy',
        body: '¿Día sin gastos o te olvidaste de anotar algo?',
      );
    }

    final total = rows.fold(0.0, (sum, t) => sum + t.amount);
    final count = rows.length;
    final formatted = total.toStringAsFixed(total.truncateToDouble() == total ? 0 : 2);

    return (
      title: 'Hoy: \$$formatted en $count gasto${count == 1 ? '' : 's'}',
      body: '¿Te falta anotar algún gasto del día?',
    );
  }

  Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_kDailyReminderId);
  }

  /// Schedule weekly summary notification (Mondays at 9:00)
  Future<void> scheduleWeeklySummary() async {
    await _plugin.cancel(_kWeeklySummaryId);

    final now = tz.TZDateTime.now(tz.local);
    // Find next Monday
    var daysUntilMonday = (DateTime.monday - now.weekday) % 7;
    if (daysUntilMonday == 0) daysUntilMonday = 7;
    final nextMonday = tz.TZDateTime(tz.local, now.year, now.month, now.day + daysUntilMonday, 9, 0);

    await _plugin.zonedSchedule(
      _kWeeklySummaryId,
      '📊 Resumen semanal',
      'Revisá cómo te fue esta semana con tus finanzas',
      nextMonday,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kWeeklySummaryChannel,
          'Resumen semanal',
          icon: '@mipmap/ic_launcher',
          importance: Importance.defaultImportance,
          color: const Color(0xFF6C63FF),
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancelWeeklySummary() async {
    await _plugin.cancel(_kWeeklySummaryId);
  }

  /// Show immediate budget exceeded notification
  static Future<void> showBudgetExceeded({
    required String categoryName,
    required double spent,
    required double limit,
  }) async {
    final spentStr = '\$${spent.toStringAsFixed(0)}';
    final limitStr = '\$${limit.toStringAsFixed(0)}';
    await _plugin.show(
      _kBudgetExceededBaseId + categoryName.hashCode.abs() % 999,
      '⚠️ Presupuesto excedido',
      '$categoryName: $spentStr de $limitStr',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kBudgetExceededChannel,
          'Presupuesto excedido',
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFFFF5252),
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
    );
  }

  Future<void> cancelCardDueReminders() async {
    for (int i = 0; i < 20; i++) {
      await _plugin.cancel(_kCardDueBaseId + i);
    }
  }

  Future<void> cancelDebtReminders() async {
    for (int i = 0; i < 100; i++) {
      await _plugin.cancel(_kDebtReminderBaseId + i);
    }
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Refresh all scheduled notifications based on current settings
  Future<void> refreshAll(WidgetRef ref) async {
    final cardDueEnabled = ref.read(notifCardDueEnabledProvider);
    final debtEnabled = ref.read(notifDebtRemindEnabledProvider);
    final cardDueDays = ref.read(notifCardDueDaysBeforeProvider);
    final debtDays = ref.read(notifDebtRemindDaysProvider);
    final dailyEnabled = ref.read(notifDailyReminderEnabledProvider);
    final dailyHour = ref.read(notifDailyReminderHourProvider);
    final dailyMinute = ref.read(notifDailyReminderMinuteProvider);
    final weeklyEnabled = ref.read(notifWeeklySummaryEnabledProvider);

    if (cardDueEnabled) {
      await scheduleCardDueReminders(daysBefore: cardDueDays);
    } else {
      await cancelCardDueReminders();
    }

    if (debtEnabled) {
      await scheduleDebtReminders(everyDays: debtDays);
    } else {
      await cancelDebtReminders();
    }

    if (dailyEnabled) {
      await scheduleDailyReminder(hour: dailyHour, minute: dailyMinute);
    } else {
      await cancelDailyReminder();
    }

    if (weeklyEnabled) {
      await scheduleWeeklySummary();
    } else {
      await cancelWeeklySummary();
    }
  }
}

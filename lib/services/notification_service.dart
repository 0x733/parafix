import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/monthly_payment.dart';

enum DailyLimitAlertLevel { eightyPercent, exceeded }

class ParafixNotificationService {
  ParafixNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _monthlyNotificationIndexKey =
      'parafix_monthly_notification_index_v1';
  static const _dailyLimitWarningId = 610001;
  static const _dailyLimitExceededId = 610002;
  static const _paymentReminderHour = 9;
  static const _scheduledMonthsAhead = 4;
  static const _dailyLimitDelay = Duration(minutes: 30);

  final FlutterLocalNotificationsPlugin _plugin;
  var _initialized = false;
  var _pluginAvailable = true;

  Future<void> initialize() async {
    if (_initialized || kIsWeb || !_pluginAvailable) {
      return;
    }

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
            defaultPresentAlert: true,
            defaultPresentBanner: true,
            defaultPresentList: true,
            defaultPresentSound: true,
          ),
        ),
      );
      _initialized = true;
    } catch (_) {
      _pluginAvailable = false;
      _initialized = true;
    }
  }

  Future<bool> requestPermissionIfNeeded() async {
    if (kIsWeb) {
      return false;
    }

    await initialize();
    if (!_pluginAvailable) {
      return false;
    }

    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    if (androidGranted != null) {
      return androidGranted;
    }

    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true, badge: false);
    if (iosGranted != null) {
      return iosGranted;
    }

    return true;
  }

  Future<bool> hasPermission() async {
    if (kIsWeb) {
      return false;
    }

    await initialize();
    if (!_pluginAvailable) {
      return false;
    }

    final androidEnabled = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.areNotificationsEnabled();
    if (androidEnabled != null) {
      return androidEnabled;
    }

    final iosOptions = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.checkPermissions();
    if (iosOptions != null) {
      return iosOptions.isEnabled || iosOptions.isProvisionalEnabled;
    }

    return true;
  }

  Future<void> scheduleDailyLimitAlert({
    required DailyLimitAlertLevel level,
    required double total,
    required double limit,
  }) async {
    if (!await requestPermissionIfNeeded()) {
      return;
    }

    final isExceeded = level == DailyLimitAlertLevel.exceeded;
    if (isExceeded) {
      await _plugin.cancel(id: _dailyLimitWarningId);
    }

    final now = DateTime.now();
    final scheduledDate = now.add(_dailyLimitDelay);
    if (!_sameDay(now, scheduledDate)) {
      return;
    }

    await _plugin.zonedSchedule(
      id: isExceeded ? _dailyLimitExceededId : _dailyLimitWarningId,
      title: isExceeded ? 'Günlük limit aşıldı' : 'Günlük limitine yaklaştın',
      body: isExceeded
          ? 'Bugün ${_money(total)} harcadın. Limitin ${_money(limit)}.'
          : 'Bugün ${_money(total)} harcadın. Limitin ${_money(limit)}.',
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: isExceeded ? 'daily-limit-exceeded' : 'daily-limit-warning',
    );
  }

  Future<void> cancelDailyLimitAlerts() async {
    await initialize();
    if (!_pluginAvailable) {
      return;
    }

    await _plugin.cancel(id: _dailyLimitWarningId);
    await _plugin.cancel(id: _dailyLimitExceededId);
  }

  Future<void> scheduleMonthlyPayment(
    MonthlyPayment payment, {
    bool requestPermission = true,
  }) async {
    await initialize();
    if (!_pluginAvailable) {
      return;
    }
    await _cancelStoredMonthlyNotifications(payment.id);

    if (!payment.isActive) {
      return;
    }

    final canNotify = requestPermission
        ? await requestPermissionIfNeeded()
        : await hasPermission();
    if (!canNotify) {
      return;
    }

    final scheduledIds = <int>[];
    final now = DateTime.now();

    for (var offset = 0; offset < _scheduledMonthsAhead; offset += 1) {
      final monthAnchor = DateTime(now.year, now.month + offset);
      final dueDate = _dueDateForMonth(
        payment.billingDay,
        monthAnchor.year,
        monthAnchor.month,
      );
      final dayBefore = dueDate.subtract(const Duration(days: 1));

      final tomorrowId = _notificationId(
        'monthly:${payment.id}:before:${_dateKey(dueDate)}',
      );
      if (await _scheduleIfFuture(
        id: tomorrowId,
        day: dayBefore,
        title: 'Yarın ${payment.title} ödemen var',
        body: '${_money(payment.amount)} • ${payment.category.name}',
        payload: 'monthly:${payment.id}:before',
      )) {
        scheduledIds.add(tomorrowId);
      }

      final todayId = _notificationId(
        'monthly:${payment.id}:today:${_dateKey(dueDate)}',
      );
      if (await _scheduleIfFuture(
        id: todayId,
        day: dueDate,
        title: 'Bugün ${payment.title} ödemen var',
        body: '${_money(payment.amount)} • ${payment.category.name}',
        payload: 'monthly:${payment.id}:today',
      )) {
        scheduledIds.add(todayId);
      }
    }

    await _storeMonthlyNotificationIds(payment.id, scheduledIds);
  }

  Future<void> scheduleMonthlyPayments(
    List<MonthlyPayment> payments, {
    bool requestPermission = true,
  }) async {
    await initialize();
    if (!_pluginAvailable) {
      return;
    }

    for (final payment in payments) {
      await scheduleMonthlyPayment(
        payment,
        requestPermission: requestPermission,
      );
    }
  }

  Future<void> cancelMonthlyPayment(String paymentId) async {
    await initialize();
    if (!_pluginAvailable) {
      return;
    }
    await _cancelStoredMonthlyNotifications(paymentId);
  }

  Future<bool> _scheduleIfFuture({
    required int id,
    required DateTime day,
    required String title,
    required String body,
    required String payload,
  }) async {
    final scheduled = DateTime(
      day.year,
      day.month,
      day.day,
      _paymentReminderHour,
    );
    if (!scheduled.isAfter(DateTime.now())) {
      return false;
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );

    return true;
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'parafix_reminders',
        'Parafix hatırlatmaları',
        channelDescription: 'Günlük limit ve aylık ödeme hatırlatmaları.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
      ),
    );
  }

  Future<void> _cancelStoredMonthlyNotifications(String paymentId) async {
    final preferences = await SharedPreferences.getInstance();
    final index = _decodeMonthlyNotificationIndex(
      preferences.getString(_monthlyNotificationIndexKey),
    );
    final ids = index.remove(paymentId) ?? const <int>[];

    for (final id in ids) {
      await _plugin.cancel(id: id);
    }

    await preferences.setString(
      _monthlyNotificationIndexKey,
      jsonEncode(index),
    );
  }

  Future<void> _storeMonthlyNotificationIds(
    String paymentId,
    List<int> ids,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final index = _decodeMonthlyNotificationIndex(
      preferences.getString(_monthlyNotificationIndexKey),
    );

    if (ids.isEmpty) {
      index.remove(paymentId);
    } else {
      index[paymentId] = ids;
    }

    await preferences.setString(
      _monthlyNotificationIndexKey,
      jsonEncode(index),
    );
  }

  Map<String, List<int>> _decodeMonthlyNotificationIndex(String? raw) {
    if (raw == null || raw.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>).map((item) => item as int).toList(),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  DateTime _dueDateForMonth(int billingDay, int year, int month) {
    final day = billingDay.clamp(1, _daysInMonth(year, month)).toInt();
    return DateTime(year, month, day);
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  int _notificationId(String source) {
    var hash = 0x811c9dc5;
    for (final codeUnit in source.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }

    return hash == 0 ? 1 : hash;
  }

  String _dateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _money(double amount) {
    return '${amount.round()}₺';
  }

  bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

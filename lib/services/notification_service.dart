import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service responsible for managing local notifications.
/// 
/// Handles initialization of notification channels, requesting permissions,
/// and showing progress updates (lock screen) and budget alerts.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Channel ID for ongoing shopping progress notifications.
  static const String channelId = 'shopping_list_progress_v2';
  static const String channelName = 'Monitor de Compras';
  static const String channelDescription = 'Mostra o total gasto e progresso da sua lista atual';

  /// Channel ID for high-importance budget alerts.
  static const String budgetChannelId = 'budget_alerts';
  static const String budgetChannelName = 'Alertas de Orçamento';

  /// Initializes notification plugins and creates necessary Android channels.
  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon'); 

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
    );

    // Progress Channel (Ongoing)
    const AndroidNotificationChannel progressChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.min, // Discrete, no status bar icon on some Android versions
      enableVibration: false,
      playSound: false,
      showBadge: false,
    );

    // Alert Channel (High Importance)
    const AndroidNotificationChannel budgetChannel = AndroidNotificationChannel(
      budgetChannelId,
      budgetChannelName,
      description: 'Notifica quando o orçamento está próximo do limite',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(progressChannel);
    await androidImpl?.createNotificationChannel(budgetChannel);
  }

  /// Triggers a high-priority budget alert notification.
  Future<void> showBudgetAlert(String title, String body) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      budgetChannelId,
      budgetChannelName,
      importance: Importance.max,
      priority: Priority.high,
      color: const Color(0xFFFF5252),
      ledColor: const Color(0xFFFF5252),
      ledOnMs: 1000,
      ledOffMs: 500,
      playSound: true,
      enableVibration: true,
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(1, title, body, details); // ID 1 for Alerts
  }

  /// Requests notification permissions for Android 13+.
  Future<void> requestPermissions() async {
    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  /// Shows or updates an ongoing notification with current shopping progress.
  /// 
  /// [listName] is the title of the active month.
  /// [bought] and [total] are used for item counts.
  /// [totalPrice] displays the current expenditure.
  Future<void> showOrUpdateProgress(String listName, int bought, int total, double totalPrice) async {
    if (total == 0) {
      await cancelProgress();
      return;
    }

    final String priceFormatted = 'R\$ ${totalPrice.toStringAsFixed(2).replaceAll('.', ',')}';
    final String title = '$listName - Total: $priceFormatted';
    final String content = '$bought Itens comprados';

    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.min,
      priority: Priority.min,
      ticker: 'Carrin atualizado',
      ongoing: true, // Remains visible until the app is closed or items are empty
      autoCancel: false,
      onlyAlertOnce: true, 
      showProgress: false, 
      visibility: NotificationVisibility.public, 
      icon: '@mipmap/launcher_icon',
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      0, // ID 0 for Progress
      title,
      content,
      platformChannelSpecifics,
    );
  }

  /// Cancels the ongoing progress notification.
  Future<void> cancelProgress() async {
    await _notificationsPlugin.cancel(0);
  }

  /// Cancels all active notifications.
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}

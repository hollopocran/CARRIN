import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/utils.dart';

/// Service responsible for managing local notifications.
/// 
/// Handles initialization of notification channels, requesting permissions,
/// showing real-time shopping progress with progress bar, and budget limit alerts.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Channel ID for shopping progress notifications.
  static const String channelId = 'shopping_list_progress_v4';
  static const String channelName = 'Monitor de Compras';
  static const String channelDescription = 'Mostra o total gasto e progresso com barra de status';

  /// Channel ID for high-importance budget alerts.
  static const String budgetChannelId = 'budget_alerts_v2';
  static const String budgetChannelName = 'Alertas de Orçamento';

  /// Ícone oficial de carrinho para todas as notificações
  static const String cartNotificationIcon = '@drawable/ic_notification_cart';

  /// Initializes notification plugins and creates necessary Android channels.
  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(cartNotificationIcon); 

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
    );

    // Progress Channel (Discreto, com barra de progresso, sem som repetitivo a cada item)
    const AndroidNotificationChannel progressChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.low, // Discreto, sem som a cada item, exibe na tela de bloqueio e barra
      enableVibration: false,
      playSound: false,
      showBadge: false,
    );

    // Alert Channel (High Importance para estouro de orçamento)
    const AndroidNotificationChannel budgetChannel = AndroidNotificationChannel(
      budgetChannelId,
      budgetChannelName,
      description: 'Notifica quando o orçamento limite for ultrapassado',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(progressChannel);
    await androidImpl?.createNotificationChannel(budgetChannel);
  }

  /// Triggers a high-priority budget alert notification.
  Future<void> showBudgetAlert(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      budgetChannelId,
      budgetChannelName,
      channelDescription: 'Notifica quando o orçamento limite for ultrapassado',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFFFF5252),
      ledColor: Color(0xFFFF5252),
      ledOnMs: 1000,
      ledOffMs: 500,
      playSound: true,
      enableVibration: true,
      autoCancel: true,
      icon: cartNotificationIcon,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);
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

  /// Shows or updates a notification with current shopping progress.
  /// 
  /// Displays a native Android progress bar, item counters, expenditure, and budget metrics.
  /// Uses ongoing: false and autoCancel: true so it is never trapped/persistent on the device.
  Future<void> showOrUpdateProgress(
    String listName, 
    int bought, 
    int total, 
    double totalPrice, {
    double budget = 0.0,
  }) async {
    if (total == 0) {
      await cancelProgress();
      return;
    }

    final String priceFormatted = Utils.formatCurrency(totalPrice);
    final String title = '$listName • $priceFormatted';
    final int percent = total > 0 ? ((bought / total) * 100).toInt() : 0;
    final String content = '$bought de $total itens comprados ($percent%)';

    String? subText;
    String bigText = 'Total no carrinho: $priceFormatted\nItens: $bought de $total comprados ($percent%)';
    if (budget > 0) {
      final double balance = budget - totalPrice;
      if (balance >= 0) {
        subText = 'Resta: ${Utils.formatCurrency(balance)}';
      } else {
        subText = 'Estourou: ${Utils.formatCurrency(-balance)}';
      }
      bigText += '\nOrçamento: ${Utils.formatCurrency(budget)} | Saldo: ${Utils.formatCurrency(balance)}';
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ticker: 'Carrin atualizado',
      ongoing: false, // Não fica presa/travada: usuário pode deslizar para dispensar
      autoCancel: true, // Cancela ao tocar para abrir o app
      onlyAlertOnce: true, 
      showProgress: true,
      maxProgress: total,
      progress: bought,
      subText: subText,
      color: const Color(0xFF10B981), // Destaque na cor verde esmeralda do CARRIN
      styleInformation: BigTextStyleInformation(
        bigText,
        contentTitle: title,
        summaryText: subText ?? '$bought/$total itens',
      ),
      visibility: NotificationVisibility.public, 
      icon: cartNotificationIcon,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
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

  /// Cancels the shopping progress notification.
  Future<void> cancelProgress() async {
    await _notificationsPlugin.cancel(0);
  }

  /// Cancels all active notifications.
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}

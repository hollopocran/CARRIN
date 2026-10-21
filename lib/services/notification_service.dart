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
  static const String channelId = 'shopping_list_progress_v5';
  static const String channelName = 'Monitor de Compras';
  static const String channelDescription = 'Mostra o total gasto e progresso com barra de status';

  /// Channel ID for high-importance budget alerts.
  static const String budgetChannelId = 'budget_alerts_v2';
  static const String budgetChannelName = 'Alertas de Orçamento';

  /// Ícones oficiais para notificações nativas (res/drawable)
  static const String cartNotificationIcon = 'ic_notification_cart';
  static const String appLogoIcon = 'ic_carrin_logo';

  /// Initializes notification plugins and creates necessary Android channels.
  Future<void> init() async {
    try {
      try {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings(cartNotificationIcon); 

        const InitializationSettings initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
        );

        await _notificationsPlugin.initialize(
          initializationSettings,
        );
      } catch (initErr) {
        debugPrint('Fallback de inicialização com @mipmap/launcher_icon: $initErr');
        const AndroidInitializationSettings fallbackInit =
            AndroidInitializationSettings('@mipmap/launcher_icon');
        await _notificationsPlugin.initialize(
          const InitializationSettings(android: fallbackInit),
        );
      }

      // Progress Channel (Prioridade padrão: exibe na barra de status e tela de bloqueio sem som repetitivo)
      const AndroidNotificationChannel progressChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.defaultImportance,
        enableVibration: false,
        playSound: false,
        showBadge: true,
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
    } catch (e) {
      debugPrint('Aviso ao inicializar NotificationService: $e');
    }
  }

  /// Triggers a high-priority budget alert notification.
  Future<void> showBudgetAlert(String title, String body) async {
    try {
      try {
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
          largeIcon: DrawableResourceAndroidBitmap(appLogoIcon),
        );

        const NotificationDetails details = NotificationDetails(android: androidDetails);
        await _notificationsPlugin.show(1, title, body, details); // ID 1 for Alerts
      } catch (inner) {
        debugPrint('Fallback alert com @mipmap/launcher_icon: $inner');
        const AndroidNotificationDetails fallbackDetails = AndroidNotificationDetails(
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
          icon: '@mipmap/launcher_icon',
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        );
        await _notificationsPlugin.show(1, title, body, const NotificationDetails(android: fallbackDetails));
      }
    } catch (e) {
      debugPrint('Erro ao disparar showBudgetAlert: $e');
    }
  }

  /// Requests notification permissions for Android 13+.
  Future<bool> requestPermissions() async {
    try {
      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Erro ao solicitar permissões de notificação: $e');
    }
    return true;
  }

  /// Checks if notifications are enabled on the system level.
  Future<bool> areNotificationsEnabled() async {
    try {
      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        return (await androidPlugin.areNotificationsEnabled()) ?? true;
      }
    } catch (_) {}
    return true;
  }

  /// Shows or updates a notification with current shopping progress.
  /// 
  /// Displays a native Android progress bar, item counters, expenditure, and budget metrics.
  /// Uses ongoing: false so the user can dismiss it if wanted, but autoCancel: false so
  /// tapping the notification to enter the app does not eliminate the active session monitor.
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

    try {
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

      try {
        final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ticker: 'Carrin atualizado',
          ongoing: false, // Deslizável/dispensável
          autoCancel: false, // Não é apagada acidentalmente ao tocar para abrir o app
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
          largeIcon: const DrawableResourceAndroidBitmap(appLogoIcon),
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
      } catch (inner) {
        debugPrint('Fallback progress com @mipmap/launcher_icon: $inner');
        final AndroidNotificationDetails fallbackSpecifics = AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ticker: 'Carrin atualizado',
          ongoing: false,
          autoCancel: false,
          onlyAlertOnce: true, 
          showProgress: true,
          maxProgress: total,
          progress: bought,
          subText: subText,
          color: const Color(0xFF10B981),
          styleInformation: BigTextStyleInformation(
            bigText,
            contentTitle: title,
            summaryText: subText ?? '$bought/$total itens',
          ),
          visibility: NotificationVisibility.public, 
          icon: '@mipmap/launcher_icon',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        );

        await _notificationsPlugin.show(
          0,
          title,
          content,
          NotificationDetails(android: fallbackSpecifics),
        );
      }
    } catch (e) {
      debugPrint('Erro ao disparar showOrUpdateProgress: $e');
    }
  }

  /// Cancels the shopping progress notification.
  Future<void> cancelProgress() async {
    try {
      await _notificationsPlugin.cancel(0);
    } catch (_) {}
  }

  /// Cancels all active notifications.
  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}

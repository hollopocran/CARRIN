import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/item_provider.dart';
import 'theme/app_themes.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';

/// Entry point for the CARRIN application.
/// 
/// Initializes core services (Localizations, Notifications) and sets up
/// the global state providers.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final themeProvider = ThemeProvider();

  // Initialize pt_BR locale for currency and date formatting
  try {
    await initializeDateFormatting('pt_BR', null);
  } catch (e) {
    debugPrint("Erro ao inicializar date formatting: $e");
  }

  // Setup local notification channels
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint("Erro ao inicializar notificações: $e");
  }

  // Initialize Theme synchronously before rendering (sempre garantido)
  try {
    await themeProvider.init();
  } catch (e) {
    debugPrint("Erro ao inicializar tema e tamanho de fonte: $e");
  }

  // Initialize Google Auth
  try {
    await AuthService().init();
  } catch (e) {
    debugPrint("Erro ao inicializar Google Auth: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AuthService()),
        ChangeNotifierProvider(create: (_) => ItemProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: const MyApp(),
    ),
  );
}

/// Root widget of the application.
/// 
/// Manages the app lifecycle to handle notification cleanup and 
/// applies the user's selected theme.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Pede permissão logo após o app carregar a interface
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().requestPermissions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService().cancelAll();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || 
        state == AppLifecycleState.paused || 
        state == AppLifecycleState.hidden) {
      // Fecha a notificação imediatamente assim que o usuário sair do app
      NotificationService().cancelAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'CARRIN',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.getTheme(themeProvider.seedColor, false, colorBlindMode: themeProvider.colorBlindMode),
      darkTheme: AppThemes.getTheme(themeProvider.seedColor, true, colorBlindMode: themeProvider.colorBlindMode),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(themeProvider.fontScale),
          ),
          child: child!,
        );
      },
      home: const SplashScreen(), // Alterado para a SplashScreen animada
    );
  }
}

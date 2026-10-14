import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _currentTheme = AppThemes.getTheme(AppColors.navy, false);
  bool _isDarkMode = false;
  Color _seedColor = AppColors.navy;
  bool _isInitialized = false;
  String _appIcon = '1.png'; // Ícone padrão

  ThemeData get currentTheme => _currentTheme;
  bool get isDarkMode => _isDarkMode;
  Color get seedColor => _seedColor;
  bool get isInitialized => _isInitialized;
  String get appIcon => _appIcon;

  ThemeProvider();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _appIcon = prefs.getString('appIcon') ?? '1.png';
    final colorValue = prefs.getInt('seedColor');
    if (colorValue != null) {
      _seedColor = Color(colorValue);
    }
    _currentTheme = AppThemes.getTheme(_seedColor, _isDarkMode);
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    _currentTheme = AppThemes.getTheme(_seedColor, _isDarkMode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  Future<void> setAppIcon(String iconPath) async {
    _appIcon = iconPath;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appIcon', iconPath);
  }

  Future<void> setTheme(bool isDark) async {
    _isDarkMode = isDark;
    _currentTheme = AppThemes.getTheme(_seedColor, _isDarkMode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    _currentTheme = AppThemes.getTheme(_seedColor, _isDarkMode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seedColor', color.toARGB32());
  }
}

class AppColors {
  static const Color navy = Color(0xFF1A1C2C);
  static const Color green = Color(0xFF2D6A4F);
  static const Color purple = Color(0xFF5A189A);
  static const Color wine = Color(0xFF641220);
  static const Color orange = Color(0xFFE85D04);
  static const Color teal = Color(0xFF006D77);
  static const Color pink = Color(0xFFC9184A);
  static const Color blue = Color(0xFF0077B6);
  static const Color indigo = Color(0xFF3F51B5);
  static const Color amber = Color(0xFFF59E0B);
  static const Color deepOrange = Color(0xFFF97316);
  static const Color lime = Color(0xFF84CC16);

  static const List<Color> selection = [
    navy,
    green,
    purple,
    wine,
    orange,
    teal,
    pink,
    blue,
    indigo,
    amber,
    deepOrange,
    lime,
  ];
}

class AppThemes {
  static const Color primaryNavy = Color(0xFF1A1C2C);

  static ThemeData getTheme(Color seedColor, bool isDark) {
    if (isDark) {
      return _buildDarkTheme(seedColor);
    }
    return _buildLightTheme(seedColor);
  }

  static ThemeData _buildLightTheme(Color seedColor) {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA), // Fundo neutro
      cardColor: Colors.white, // Cards brancos puros
      colorScheme: ColorScheme.light(
        primary: seedColor,
        secondary: seedColor,
        surface: Colors.white,
        onPrimary: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF5F7FA),
        foregroundColor: seedColor,
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent, // Remove qualquer tom esmaecido do scroll
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: seedColor,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData _buildDarkTheme(Color seedColor) {
    // Ajusta o primary para garantir legibilidade no modo escuro
    final primaryColor = HSLColor.fromColor(seedColor).withLightness(0.8).withSaturation(0.7).toColor();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0D0E15), // Fundo escuro puro
      cardColor: const Color(0xFF1A1C2C), // Cor dos cards padrão
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor,
        surface: const Color(0xFF1A1C2C),
        onPrimary: Colors.black,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D0E15),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent, // Remove esmaecimento
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1A1C2C),
        indicatorColor: primaryColor.withOpacity(0.24),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (stateContains(states, WidgetState.selected)) {
            return IconThemeData(color: primaryColor);
          }
          return const IconThemeData(color: Colors.grey);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (stateContains(states, WidgetState.selected)) {
            return TextStyle(color: primaryColor, fontWeight: FontWeight.bold);
          }
          return const TextStyle(color: Colors.grey);
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (stateContains(states, WidgetState.selected)) return primaryColor;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (stateContains(states, WidgetState.selected)) return primaryColor.withOpacity(0.5);
          return null;
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static bool stateContains(Set<WidgetState> states, WidgetState state) => states.contains(state);
}

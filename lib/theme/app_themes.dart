import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NamedColor {
  final String name;
  final Color color;

  const NamedColor(this.name, this.color);
}

class AppColors {
  static const Color navy = Color(0xFF1A1C2C);
  static const Color ocean = Color(0xFF0077B6);
  static const Color green = Color(0xFF2D6A4F);
  static const Color emerald = Color(0xFF10B981);
  static const Color purple = Color(0xFF5A189A);
  static const Color violet = Color(0xFF7C3AED);
  static const Color wine = Color(0xFF641220);
  static const Color crimson = Color(0xFFC9184A);
  static const Color orange = Color(0xFFE85D04);
  static const Color amber = Color(0xFFF59E0B);
  static const Color teal = Color(0xFF006D77);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color indigo = Color(0xFF3F51B5);
  static const Color lime = Color(0xFF84CC16);
  static const Color graphite = Color(0xFF374151);

  static const List<NamedColor> curated = [
    NamedColor('Azul Marinho', navy),
    NamedColor('Azul Oceano', ocean),
    NamedColor('Verde Floresta', green),
    NamedColor('Verde Esmeralda', emerald),
    NamedColor('Roxo Nobre', purple),
    NamedColor('Violeta Elétrico', violet),
    NamedColor('Vinho Tinto', wine),
    NamedColor('Rubi Carmim', crimson),
    NamedColor('Laranja Solar', orange),
    NamedColor('Âmbar Dourado', amber),
    NamedColor('Azul Petróleo', teal),
    NamedColor('Ciano Turquesa', cyan),
    NamedColor('Índigo Clássico', indigo),
    NamedColor('Verde Lima', lime),
    NamedColor('Cinza Grafite', graphite),
  ];

  static List<Color> get selection => curated.map((nc) => nc.color).toList();

  static String getColorName(Color color) {
    for (var nc in curated) {
      if (nc.color.toARGB32() == color.toARGB32()) return nc.name;
    }
    final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    return 'Tom Personalizado (#$hex)';
  }
}

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
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA), // Fundo neutro
      cardColor: Colors.white, // Cards brancos puros
      primaryColor: seedColor,
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
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
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
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D0E15), // Fundo escuro puro
      cardColor: const Color(0xFF1A1C2C), // Cor dos cards padrão
      primaryColor: primaryColor,
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
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1A1C2C),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1A1C2C),
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1A1C2C),
        indicatorColor: primaryColor.withValues(alpha: 0.24),
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
          if (stateContains(states, WidgetState.selected)) return primaryColor.withValues(alpha: 0.5);
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

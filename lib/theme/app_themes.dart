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

enum ColorBlindMode {
  none,
  deuteranopia, // Dificuldade com verde (mais comum)
  protanopia,   // Dificuldade com vermelho
  tritanopia,   // Dificuldade com azul e amarelo
  highContrast, // Alto contraste e contornos reforçados
}

extension ColorBlindModeExtension on ColorBlindMode {
  String get label {
    switch (this) {
      case ColorBlindMode.none:
        return 'Padrão (Desativado)';
      case ColorBlindMode.deuteranopia:
        return 'Deuteranopia (Verde)';
      case ColorBlindMode.protanopia:
        return 'Protanopia (Vermelho)';
      case ColorBlindMode.tritanopia:
        return 'Tritanopia (Azul / Amarelo)';
      case ColorBlindMode.highContrast:
        return 'Alto Contraste';
    }
  }

  String get description {
    switch (this) {
      case ColorBlindMode.none:
        return 'Cores originais e naturais do aplicativo.';
      case ColorBlindMode.deuteranopia:
        return 'Substitui tons de verde por azul royal e laranja de alto contraste.';
      case ColorBlindMode.protanopia:
        return 'Substitui tons de vermelho por azul e âmbar de fácil identificação.';
      case ColorBlindMode.tritanopia:
        return 'Substitui tons de azul/amarelo por ciano e magenta vibrante.';
      case ColorBlindMode.highContrast:
        return 'Bordas fortes, preto/branco reforçado e saturação máxima.';
    }
  }

  Color get primaryAccent {
    switch (this) {
      case ColorBlindMode.none:
        return const Color(0xFF1A1C2C);
      case ColorBlindMode.deuteranopia:
        return const Color(0xFF0072B2);
      case ColorBlindMode.protanopia:
        return const Color(0xFF0072B2);
      case ColorBlindMode.tritanopia:
        return const Color(0xFF009E73);
      case ColorBlindMode.highContrast:
        return const Color(0xFF00E676);
    }
  }
}

class ThemeProvider with ChangeNotifier {
  ThemeData _currentTheme = AppThemes.getTheme(AppColors.navy, false);
  bool _isDarkMode = false;
  Color _seedColor = AppColors.navy;
  bool _isInitialized = false;
  String _appIcon = '1.png'; // Ícone padrão
  double _fontScale = 1.0;
  ColorBlindMode _colorBlindMode = ColorBlindMode.none;

  ThemeData get currentTheme => _currentTheme;
  bool get isDarkMode => _isDarkMode;
  Color get seedColor => _seedColor;
  bool get isInitialized => _isInitialized;
  String get appIcon => _appIcon;
  double get fontScale => _fontScale;
  ColorBlindMode get colorBlindMode => _colorBlindMode;

  String get fontScaleLabel {
    if (_fontScale <= 0.88) return 'Pequeno (85%)';
    if (_fontScale <= 1.05) return 'Padrão (100%)';
    if (_fontScale <= 1.20) return 'Médio (115%)';
    if (_fontScale <= 1.35) return 'Grande (130%)';
    return 'Extra Grande (145%)';
  }

  String get colorBlindModeLabel => _colorBlindMode.label;

  Color get successColor {
    switch (_colorBlindMode) {
      case ColorBlindMode.none:
        return const Color(0xFF2D6A4F);
      case ColorBlindMode.deuteranopia:
      case ColorBlindMode.protanopia:
        return const Color(0xFF0072B2); // Azul royal de alto contraste
      case ColorBlindMode.tritanopia:
        return const Color(0xFF009E73); // Verde azulado
      case ColorBlindMode.highContrast:
        return const Color(0xFF00E676); // Verde neon alto contraste
    }
  }

  Color get dangerColor {
    switch (_colorBlindMode) {
      case ColorBlindMode.none:
        return const Color(0xFFE63946);
      case ColorBlindMode.deuteranopia:
        return const Color(0xFFD55E00); // Laranja vibrante / Vermillion
      case ColorBlindMode.protanopia:
        return const Color(0xFFE69F00); // Âmbar
      case ColorBlindMode.tritanopia:
        return const Color(0xFFCC79A7); // Magenta avermelhado
      case ColorBlindMode.highContrast:
        return const Color(0xFFFF1744); // Vermelho puro intenso
    }
  }

  Color get warningColor => const Color(0xFFF59E0B);

  ThemeProvider();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _appIcon = prefs.getString('appIcon') ?? '1.png';
    _fontScale = prefs.getDouble('fontScale') ?? 1.0;
    final cbIdx = prefs.getInt('colorBlindMode');
    if (cbIdx != null && cbIdx >= 0 && cbIdx < ColorBlindMode.values.length) {
      _colorBlindMode = ColorBlindMode.values[cbIdx];
    }
    final colorValue = prefs.getInt('seedColor');
    if (colorValue != null) {
      _seedColor = Color(colorValue);
    }
    _currentTheme = AppThemes.getTheme(_seedColor, _isDarkMode, colorBlindMode: _colorBlindMode);
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    _currentTheme = AppThemes.getTheme(_seedColor, _isDarkMode, colorBlindMode: _colorBlindMode);
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
    _currentTheme = AppThemes.getTheme(_seedColor, _isDarkMode, colorBlindMode: _colorBlindMode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    _currentTheme = AppThemes.getTheme(_seedColor, _isDarkMode, colorBlindMode: _colorBlindMode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seedColor', color.toARGB32());
  }

  Future<void> setFontScale(double scale) async {
    _fontScale = scale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontScale', scale);
  }

  Future<void> setColorBlindMode(ColorBlindMode mode) async {
    _colorBlindMode = mode;
    _currentTheme = AppThemes.getTheme(_seedColor, _isDarkMode, colorBlindMode: _colorBlindMode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('colorBlindMode', mode.index);
  }
}

class AppThemes {
  static const Color primaryNavy = Color(0xFF1A1C2C);

  static ThemeData getTheme(Color seedColor, bool isDark, {ColorBlindMode colorBlindMode = ColorBlindMode.none}) {
    Color effectiveSeed = seedColor;
    if (colorBlindMode == ColorBlindMode.deuteranopia || colorBlindMode == ColorBlindMode.protanopia) {
      if (seedColor == AppColors.green || seedColor == AppColors.emerald || seedColor == AppColors.crimson || seedColor == AppColors.wine) {
        effectiveSeed = const Color(0xFF0072B2);
      }
    } else if (colorBlindMode == ColorBlindMode.tritanopia) {
      if (seedColor == AppColors.ocean || seedColor == AppColors.cyan || seedColor == AppColors.amber) {
        effectiveSeed = const Color(0xFF009E73);
      }
    }
    if (isDark) {
      return _buildDarkTheme(effectiveSeed, colorBlindMode: colorBlindMode);
    }
    return _buildLightTheme(effectiveSeed, colorBlindMode: colorBlindMode);
  }

  static ThemeData _buildLightTheme(Color seedColor, {ColorBlindMode colorBlindMode = ColorBlindMode.none}) {
    final isHighContrast = colorBlindMode == ColorBlindMode.highContrast;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: isHighContrast ? Colors.white : const Color(0xFFF5F7FA),
      cardColor: Colors.white,
      primaryColor: seedColor,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: isHighContrast ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isHighContrast 
              ? const BorderSide(color: Colors.black, width: 2.0)
              : BorderSide(color: Colors.black.withValues(alpha: 0.06), width: 1.0),
        ),
      ),
      colorScheme: ColorScheme.light(
        primary: seedColor,
        secondary: seedColor,
        surface: Colors.white,
        onPrimary: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isHighContrast ? Colors.white : const Color(0xFFF5F7FA),
        foregroundColor: seedColor,
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: isHighContrast ? const BorderSide(color: Colors.black, width: 2) : BorderSide.none,
        ),
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
          elevation: isHighContrast ? 4 : 0,
          side: isHighContrast ? const BorderSide(color: Colors.black, width: 2) : null,
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

  static ThemeData _buildDarkTheme(Color seedColor, {ColorBlindMode colorBlindMode = ColorBlindMode.none}) {
    final isHighContrast = colorBlindMode == ColorBlindMode.highContrast;
    // Ajusta o primary para garantir legibilidade no modo escuro
    final primaryColor = HSLColor.fromColor(seedColor).withLightness(isHighContrast ? 0.9 : 0.8).withSaturation(isHighContrast ? 0.9 : 0.7).toColor();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: isHighContrast ? Colors.black : const Color(0xFF0D0E15),
      cardColor: isHighContrast ? const Color(0xFF15151E) : const Color(0xFF1A1C2C),
      primaryColor: primaryColor,
      cardTheme: CardThemeData(
        color: isHighContrast ? const Color(0xFF15151E) : const Color(0xFF1A1C2C),
        elevation: isHighContrast ? 6 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isHighContrast 
              ? const BorderSide(color: Colors.white, width: 2.0)
              : BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
        ),
      ),
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

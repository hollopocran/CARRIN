import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NamedColor {
  final String name;
  final Color color;
  final String category;

  const NamedColor(this.name, this.color, [this.category = 'Clássicas']);
}

class AppColors {
  // Clássicas & Neutros
  static const Color navy = Color(0xFF1A1C2C);
  static const Color ocean = Color(0xFF0077B6);
  static const Color teal = Color(0xFF006D77);
  static const Color indigo = Color(0xFF3F51B5);
  static const Color graphite = Color(0xFF374151);
  static const Color slate = Color(0xFF475569);
  static const Color onyx = Color(0xFF111827);

  // Natureza & Frescor
  static const Color green = Color(0xFF2D6A4F);
  static const Color emerald = Color(0xFF10B981);
  static const Color mint = Color(0xFF059669);
  static const Color lime = Color(0xFF84CC16);
  static const Color olive = Color(0xFF4D7C0F);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color sky = Color(0xFF0284C7);

  // Energia & Calor
  static const Color orange = Color(0xFFE85D04);
  static const Color amber = Color(0xFFF59E0B);
  static const Color gold = Color(0xFFEAB308);
  static const Color coral = Color(0xFFF97316);
  static const Color peach = Color(0xFFFB923C);
  static const Color sunset = Color(0xFFFF5722);

  // Nobres & Elegantes
  static const Color hotPink = Color(0xFFFF1493); // Rosa Choque Vibrante
  static const Color barbiePink = Color(0xFFE0218A); // Rosa Barbie / Chiclete
  static const Color wine = Color(0xFF641220);
  static const Color crimson = Color(0xFFC9184A);
  static const Color magenta = Color(0xFFD946EF);
  static const Color rose = Color(0xFFBE185D);
  static const Color terracotta = Color(0xFF9C4221);
  static const Color coffee = Color(0xFF451A03);
  static const Color copper = Color(0xFFB45309);

  // Místicas & Jovens
  static const Color purple = Color(0xFF5A189A);
  static const Color violet = Color(0xFF7C3AED);
  static const Color deepPurple = Color(0xFF4C1D95);
  static const Color lavender = Color(0xFF8B5CF6);
  static const Color neonPurple = Color(0xFFA855F7);

  static const List<NamedColor> curated = [
    // Clássicas
    NamedColor('Azul Marinho', navy, 'Clássicas'),
    NamedColor('Azul Oceano', ocean, 'Clássicas'),
    NamedColor('Azul Petróleo', teal, 'Clássicas'),
    NamedColor('Índigo Clássico', indigo, 'Clássicas'),
    NamedColor('Cinza Grafite', graphite, 'Clássicas'),
    NamedColor('Preto Ônix', onyx, 'Clássicas'),
    NamedColor('Ardósia', slate, 'Clássicas'),

    // Natureza
    NamedColor('Verde Floresta', green, 'Natureza'),
    NamedColor('Verde Esmeralda', emerald, 'Natureza'),
    NamedColor('Verde Menta', mint, 'Natureza'),
    NamedColor('Verde Lima', lime, 'Natureza'),
    NamedColor('Verde Oliva', olive, 'Natureza'),
    NamedColor('Ciano Turquesa', cyan, 'Natureza'),
    NamedColor('Azul Celeste', sky, 'Natureza'),

    // Quentes & Energia
    NamedColor('Laranja Solar', orange, 'Quentes'),
    NamedColor('Âmbar Dourado', amber, 'Quentes'),
    NamedColor('Amarelo Ouro', gold, 'Quentes'),
    NamedColor('Coral Tropical', coral, 'Quentes'),
    NamedColor('Pêssego', peach, 'Quentes'),
    NamedColor('Pôr do Sol', sunset, 'Quentes'),

    // Nobres & Elegantes
    NamedColor('Rosa Choque', hotPink, 'Elegantes'),
    NamedColor('Rosa Barbie', barbiePink, 'Elegantes'),
    NamedColor('Rosa Magenta', magenta, 'Elegantes'),
    NamedColor('Rosa Seco', rose, 'Elegantes'),
    NamedColor('Vinho Tinto', wine, 'Elegantes'),
    NamedColor('Rubi Carmim', crimson, 'Elegantes'),
    NamedColor('Terracota', terracotta, 'Elegantes'),
    NamedColor('Marrom Café', coffee, 'Elegantes'),
    NamedColor('Cobre Nobre', copper, 'Elegantes'),

    // Místicas & Criativas
    NamedColor('Roxo Nobre', purple, 'Criativas'),
    NamedColor('Violeta Elétrico', violet, 'Criativas'),
    NamedColor('Púrpura Profundo', deepPurple, 'Criativas'),
    NamedColor('Lavanda', lavender, 'Criativas'),
    NamedColor('Cyber Neon', neonPurple, 'Criativas'),
  ];

  static List<String> get categories => ['Todas', 'Clássicas', 'Natureza', 'Quentes', 'Elegantes', 'Criativas'];

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

    // A cor primária no tema escuro é FIEL à cor selecionada pelo usuário (o rosa é rosa de verdade!)
    // Apenas se for excessivamente escura (< 0.04 de luminância), elevamos sutilmente para destacar no fundo preto.
    Color primaryColor = seedColor;
    if (seedColor.computeLuminance() < 0.04) {
      primaryColor = HSLColor.fromColor(seedColor).withLightness(0.55).toColor();
    }

    final bool isLightPrimary = primaryColor.computeLuminance() > 0.55;
    final Color onPrimaryColor = isLightPrimary ? Colors.black87 : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: isHighContrast ? Colors.black : const Color(0xFF0F1017),
      cardColor: isHighContrast ? const Color(0xFF161722) : const Color(0xFF181A26),
      primaryColor: primaryColor,
      cardTheme: CardThemeData(
        color: isHighContrast ? const Color(0xFF161722) : const Color(0xFF181A26),
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
        surface: const Color(0xFF181A26),
        onPrimary: onPrimaryColor,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F1017),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent, // Remove esmaecimento
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF181A26),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF181A26),
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF181A26),
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
          foregroundColor: onPrimaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: isHighContrast ? 4 : 0,
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

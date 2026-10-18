import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_themes.dart';

/// Modal interativo em BottomSheet para personalização visual de cores e modo de tema.
/// 
/// Inclui:
/// - Cartão interativo com prévia em tempo real
/// - Alternador de Modo Claro / Escuro
/// - Slider contínuo com espectro do arco-íris (Matiz HSL livre)
/// - Paleta com 15 cores curadas e seus respectivos nomes
/// - Botão para restaurar cor padrão
class ThemeColorPickerSheet extends StatefulWidget {
  final ThemeProvider provider;

  const ThemeColorPickerSheet({super.key, required this.provider});

  static Future<void> show(BuildContext context, ThemeProvider provider) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ThemeColorPickerSheet(provider: provider),
    );
  }

  @override
  State<ThemeColorPickerSheet> createState() => _ThemeColorPickerSheetState();
}

class _ThemeColorPickerSheetState extends State<ThemeColorPickerSheet> {
  late Color _tempColor;
  late bool _tempDarkMode;
  double _currentHue = 220.0;
  String _selectedCategory = 'Todas';

  @override
  void initState() {
    super.initState();
    _tempColor = widget.provider.seedColor;
    _tempDarkMode = widget.provider.isDarkMode;

    final hsl = HSLColor.fromColor(_tempColor);
    _currentHue = hsl.hue;
  }

  void _onHueChanged(double hue) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentHue = hue;
      // Mantém saturação rica e luminosidade balanceada para temas
      _tempColor = HSLColor.fromAHSL(1.0, hue, 0.75, 0.45).toColor();
    });
  }

  void _selectCuratedColor(Color color) {
    HapticFeedback.lightImpact();
    setState(() {
      _tempColor = color;
      final hsl = HSLColor.fromColor(color);
      _currentHue = hsl.hue;
    });
  }

  void _toggleDarkMode(bool isDark) {
    HapticFeedback.lightImpact();
    setState(() {
      _tempDarkMode = isDark;
    });
  }

  void _restoreDefault() {
    HapticFeedback.mediumImpact();
    setState(() {
      _tempColor = AppColors.iconGreen;
      final hsl = HSLColor.fromColor(AppColors.iconGreen);
      _currentHue = hsl.hue;
    });
  }

  void _promptHexColor() {
    final controller = TextEditingController(
      text: _tempColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase(),
    );
    String? errorText;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.colorize_rounded),
                SizedBox(width: 8),
                Text('Cor Hexadecimal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Digite ou cole o código HEX de 6 caracteres (ex: 2563EB ou #E85D04):', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    prefixText: '# ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: () {
                  String clean = controller.text.replaceAll('#', '').trim();
                  if (clean.length == 6) {
                    final val = int.tryParse('FF$clean', radix: 16);
                    if (val != null) {
                      setState(() {
                        _tempColor = Color(val);
                        _currentHue = HSLColor.fromColor(_tempColor).hue;
                      });
                      Navigator.pop(ctx);
                      return;
                    }
                  }
                  setDialogState(() {
                    errorText = 'Código HEX inválido. Use 6 dígitos.';
                  });
                },
                child: const Text('Aplicar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _applyAndSave() async {
    HapticFeedback.mediumImpact();
    if (_tempDarkMode != widget.provider.isDarkMode) {
      await widget.provider.setTheme(_tempDarkMode);
    }
    if (_tempColor != widget.provider.seedColor) {
      await widget.provider.setSeedColor(_tempColor);
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetBg = Theme.of(context).cardColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final hexString = '#${_tempColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    final colorName = AppColors.getColorName(_tempColor);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de arrasto superior
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Cabeçalho
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _tempColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.palette_rounded, color: _tempColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Cores do Tema',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _restoreDefault,
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Restaurar Ícone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.iconGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Prévia Interativa em Tempo Real
              _buildLivePreviewCard(_tempColor, _tempDarkMode),
              const SizedBox(height: 16),

              // Banner com Cores Oficiais do Ícone CARRIN (Verde e Azul)
              _buildOfficialIconThemeBanner(),
              const SizedBox(height: 20),

              // Alternador de Modo: Claro / Escuro
              _buildModeSelector(),
              const SizedBox(height: 24),

              // Seção de Paletas Curadas com Nomes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PALETA DE CORES CURADAS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
                  ),
                  Text(
                    colorName,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildCuratedColorsGrid(),
              const SizedBox(height: 24),

              // Slider Arco-Íris de Matiz Livre
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ESPECTRO LIVRE DE CORES',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
                  ),
                  GestureDetector(
                    onTap: _promptHexColor,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _tempColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _tempColor.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded, size: 12, color: _tempColor),
                          const SizedBox(width: 4),
                          Text(
                            hexString,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _tempColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildRainbowSlider(),
              const SizedBox(height: 24),

              // Botões de Ação
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _applyAndSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _tempColor,
                        foregroundColor: _tempColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Aplicar Cor',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreviewCard(Color primaryColor, bool isDark) {
    final previewBg = isDark ? const Color(0xFF131522) : const Color(0xFFF0F3F8);
    final previewCardBg = isDark ? const Color(0xFF1F2236) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1C2C);
    final textMuted = isDark ? Colors.white60 : Colors.black54;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: previewBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pré-visualização do Aplicativo',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded, size: 12, color: primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      isDark ? 'Modo Escuro' : 'Modo Claro',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mini item simulado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: previewCardBg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shopping_bag_outlined, color: primaryColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Café Torrado 500g', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                      Text('2 un × R\$ 16,90', style: TextStyle(fontSize: 11, color: textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'R\$ 33,80',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Barra de progresso simulada com a cor primária
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 0.68,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialIconThemeBanner() {
    final isGreenSelected = _tempColor.toARGB32() == AppColors.iconGreen.toARGB32();
    final isBlueSelected = _tempColor.toARGB32() == AppColors.iconBlue.toARGB32();
    final isDark = _tempDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2132) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isGreenSelected || isBlueSelected)
              ? (isGreenSelected ? AppColors.iconGreen : AppColors.iconBlue)
              : Colors.grey.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_rounded, size: 16, color: AppColors.iconGreen),
                  SizedBox(width: 6),
                  Text(
                    'Cores Oficiais do Ícone CARRIN',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              if (isGreenSelected || isBlueSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isGreenSelected ? AppColors.iconGreen : AppColors.iconBlue).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Ativo',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isGreenSelected ? AppColors.iconGreen : AppColors.iconBlue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectCuratedColor(AppColors.iconGreen),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isGreenSelected
                          ? AppColors.iconGreen
                          : (isDark ? const Color(0xFF272A3E) : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.iconGreen,
                        width: isGreenSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isGreenSelected
                          ? [
                              BoxShadow(
                                color: AppColors.iconGreen.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.iconGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Verde Ícone',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isGreenSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _selectCuratedColor(AppColors.iconBlue),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isBlueSelected
                          ? AppColors.iconBlue
                          : (isDark ? const Color(0xFF272A3E) : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.iconBlue,
                        width: isBlueSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isBlueSelected
                          ? [
                              BoxShadow(
                                color: AppColors.iconBlue.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.iconBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Azul Ícone',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isBlueSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleDarkMode(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_tempDarkMode ? Theme.of(context).cardColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: !_tempDarkMode ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wb_sunny_rounded,
                      size: 18,
                      color: !_tempDarkMode ? Colors.orange : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Modo Claro',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: !_tempDarkMode ? FontWeight.bold : FontWeight.w500,
                        color: !_tempDarkMode ? null : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleDarkMode(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _tempDarkMode ? Theme.of(context).cardColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _tempDarkMode ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.nightlight_round_rounded,
                      size: 18,
                      color: _tempDarkMode ? Colors.blueAccent : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Modo Escuro',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _tempDarkMode ? FontWeight.bold : FontWeight.w500,
                        color: _tempDarkMode ? null : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRainbowSlider() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF0000), // Vermelho
            Color(0xFFFFFF00), // Amarelo
            Color(0xFF00FF00), // Verde
            Color(0xFF00FFFF), // Ciano
            Color(0xFF0000FF), // Azul
            Color(0xFFFF00FF), // Magenta
            Color(0xFFFF0000), // Retorno ao Vermelho
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 40,
          activeTrackColor: Colors.transparent,
          inactiveTrackColor: Colors.transparent,
          thumbColor: Colors.white,
          thumbShape: _CustomThumbShape(thumbColor: _tempColor),
          overlayShape: SliderComponentShape.noOverlay,
        ),
        child: Slider(
          value: _currentHue,
          min: 0.0,
          max: 360.0,
          onChanged: _onHueChanged,
        ),
      ),
    );
  }

  Widget _buildCuratedColorsGrid() {
    final filtered = _selectedCategory == 'Todas'
        ? AppColors.curated
        : AppColors.curated.where((nc) => nc.category == _selectedCategory).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filtro por categorias com rolagem horizontal
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: AppColors.categories.map((cat) {
              final isCatSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 12),
                child: FilterChip(
                  label: Text(
                    cat, 
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: isCatSelected ? FontWeight.bold : FontWeight.w500,
                      color: isCatSelected ? Colors.white : null,
                    ),
                  ),
                  selected: isCatSelected,
                  selectedColor: Theme.of(context).primaryColor,
                  checkmarkColor: Colors.white,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(
                    color: isCatSelected ? Colors.transparent : Colors.grey.withValues(alpha: 0.2),
                  ),
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = cat);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: filtered.map((namedColor) {
            final isSelected = _tempColor.toARGB32() == namedColor.color.toARGB32();
            return GestureDetector(
              onTap: () => _selectCuratedColor(namedColor.color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? namedColor.color.withValues(alpha: 0.16)
                      : Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? namedColor.color : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: namedColor.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: namedColor.color.withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      namedColor.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? namedColor.color : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CustomThumbShape extends SliderComponentShape {
  final Color thumbColor;

  const _CustomThumbShape({required this.thumbColor});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(28, 28);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Sombra do marcador
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center + const Offset(0, 2), 16, shadowPaint);

    // Borda branca externa
    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 16, outerPaint);

    // Círculo interno colorido com a cor selecionada
    final innerPaint = Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 12, innerPaint);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_themes.dart';

/// Modal interativo em BottomSheet para personalização visual de cores e modo de tema.
/// 
/// Agrupamento inteligente, ultra-compacto e ergonômico por coleções:
/// - 🌟 Ícone CARRIN (Verde Esmeralda e Azul Royal Oficiais)
/// - 🌿 Natureza & Frescor (7 tons)
/// - 💼 Clássicas & Neutros (7 tons)
/// - ☀️ Quentes & Energia (6 tons)
/// - 💎 Elegantes & Nobres (9 tons)
/// - 🔮 Criativas & Místicas (5 tons)
/// - 🌈 Livre (Espectro contínuo HSL e código HEX manual)
/// - 🎨 Todas (Grade geral compacta de 36 cores)
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
  String _selectedCategory = 'Ícone';

  // Categorias com ícones amigáveis para navegação visual imediata
  static const List<Map<String, String>> _categories = [
    {'id': 'Ícone', 'label': 'Ícone', 'icon': '🌟'},
    {'id': 'Natureza', 'label': 'Natureza', 'icon': '🌿'},
    {'id': 'Clássicas', 'label': 'Clássicas', 'icon': '💼'},
    {'id': 'Quentes', 'label': 'Quentes', 'icon': '☀️'},
    {'id': 'Elegantes', 'label': 'Elegantes', 'icon': '💎'},
    {'id': 'Criativas', 'label': 'Criativas', 'icon': '🔮'},
    {'id': 'Livre', 'label': 'Livre', 'icon': '🌈'},
    {'id': 'Todas', 'label': 'Todas', 'icon': '🎨'},
  ];

  @override
  void initState() {
    super.initState();
    _tempColor = widget.provider.seedColor;
    _tempDarkMode = widget.provider.isDarkMode;

    final hsl = HSLColor.fromColor(_tempColor);
    _currentHue = hsl.hue;

    // Detecta automaticamente a categoria da cor ativa para abrir diretamente nela
    String matchedCat = 'Ícone';
    for (var nc in AppColors.curated) {
      if (nc.color.toARGB32() == _tempColor.toARGB32()) {
        matchedCat = nc.category;
        break;
      }
    }
    _selectedCategory = matchedCat;
  }

  void _onHueChanged(double hue) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentHue = hue;
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
      _selectedCategory = 'Ícone';
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
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 1. Cabeçalho Compacto: Título + Alternador Claro/Escuro + Restaurar
              _buildCompactHeader(),
              const SizedBox(height: 12),

              // 2. Faixa Compacta de Pré-visualização da Cor Ativa (Apenas 48px de altura)
              _buildCompactPreviewStrip(colorName, hexString),
              const SizedBox(height: 14),

              // 3. Seletor Horizontal de Grupos de Temas (Scroll suave em chips elegantes)
              _buildCategorySelector(),
              const SizedBox(height: 14),

              // 4. Área de Paletas Agrupadas (Ultra-compacta e ergonômica)
              _buildGroupedContent(),
              const SizedBox(height: 18),

              // 5. Botões de Ação
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  // Cabeçalho compacto com Título, Modo Claro/Escuro em pílula e Restaurar Ícone
  Widget _buildCompactHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _tempColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.palette_rounded, color: _tempColor, size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'Cores do Tema',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Row(
          children: [
            // Alternador Claro / Escuro em pílula compacta
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _toggleDarkMode(false),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: !_tempDarkMode ? Theme.of(context).cardColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: !_tempDarkMode
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wb_sunny_rounded, size: 14, color: !_tempDarkMode ? Colors.orange : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Claro',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: !_tempDarkMode ? FontWeight.bold : FontWeight.w500,
                              color: !_tempDarkMode ? null : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _toggleDarkMode(true),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _tempDarkMode ? Theme.of(context).cardColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _tempDarkMode
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.nightlight_round_rounded, size: 14, color: _tempDarkMode ? Colors.blueAccent : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Escuro',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _tempDarkMode ? FontWeight.bold : FontWeight.w500,
                              color: _tempDarkMode ? null : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.restart_alt, size: 20),
              tooltip: 'Restaurar cores do ícone',
              color: AppColors.iconGreen,
              visualDensity: VisualDensity.compact,
              onPressed: _restoreDefault,
            ),
          ],
        ),
      ],
    );
  }

  // Barra de prévia compacta (48px) com informações da cor selecionada
  Widget _buildCompactPreviewStrip(String colorName, String hexString) {
    final isDark = _tempDarkMode;
    final cardBg = isDark ? const Color(0xFF1E2132) : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _tempColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _tempColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _tempColor.withValues(alpha: 0.45),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  colorName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_tempDarkMode ? 'Modo Escuro' : 'Modo Claro'} • $hexString',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _promptHexColor,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _tempColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _tempColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, size: 12, color: _tempColor),
                  const SizedBox(width: 4),
                  Text(
                    'HEX',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _tempColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Seletor horizontal compacto de categorias/grupos
  Widget _buildCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              avatar: Text(cat['icon']!, style: const TextStyle(fontSize: 12)),
              label: Text(cat['label']!),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: _tempColor,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (_tempColor.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                    : null,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(
                color: isSelected ? Colors.transparent : Colors.grey.withValues(alpha: 0.2),
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = cat['id']!);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // Conteúdo agrupado inteligente dependendo da categoria selecionada
  Widget _buildGroupedContent() {
    if (_selectedCategory == 'Ícone') {
      return _buildOfficialIconGroup();
    } else if (_selectedCategory == 'Livre') {
      return _buildFreeSpectrumGroup();
    } else if (_selectedCategory == 'Todas') {
      return _buildAllColorsGrid();
    } else {
      return _buildCategorySwatchesGrid(_selectedCategory);
    }
  }

  // 1. Grupo Ícone Oficial CARRIN
  Widget _buildOfficialIconGroup() {
    final isGreenSelected = _tempColor.toARGB32() == AppColors.iconGreen.toARGB32();
    final isBlueSelected = _tempColor.toARGB32() == AppColors.iconBlue.toARGB32();
    final isDark = _tempDarkMode;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _selectCuratedColor(AppColors.iconGreen),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: isGreenSelected
                    ? AppColors.iconGreen
                    : (isDark ? const Color(0xFF272A3E) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.iconGreen,
                  width: isGreenSelected ? 2.5 : 1.0,
                ),
                boxShadow: isGreenSelected
                    ? [
                        BoxShadow(
                          color: AppColors.iconGreen.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.iconGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: isGreenSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Verde do Ícone',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isGreenSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  Text(
                    'Padrão de Fábrica',
                    style: TextStyle(
                      fontSize: 10,
                      color: isGreenSelected ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () => _selectCuratedColor(AppColors.iconBlue),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: isBlueSelected
                    ? AppColors.iconBlue
                    : (isDark ? const Color(0xFF272A3E) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.iconBlue,
                  width: isBlueSelected ? 2.5 : 1.0,
                ),
                boxShadow: isBlueSelected
                    ? [
                        BoxShadow(
                          color: AppColors.iconBlue.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.iconBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: isBlueSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Azul do Ícone',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isBlueSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  Text(
                    'Padrão de Fábrica',
                    style: TextStyle(
                      fontSize: 10,
                      color: isBlueSelected ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 2. Grupo de Paleta por Categoria (Grade compacta de círculos com nome)
  Widget _buildCategorySwatchesGrid(String category) {
    final list = AppColors.curated.where((nc) => nc.category == category).toList();

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      alignment: WrapAlignment.start,
      children: list.map((nc) {
        final isSelected = _tempColor.toARGB32() == nc.color.toARGB32();
        return InkWell(
          onTap: () => _selectCuratedColor(nc.color),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? nc.color.withValues(alpha: 0.16)
                  : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? nc.color : Colors.grey.withValues(alpha: 0.2),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: nc.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: nc.color.withValues(alpha: 0.35),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
                const SizedBox(width: 6),
                Text(
                  nc.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? nc.color : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // 3. Grupo de Todas as Cores em Grade Ultra-Compacta (36 círculos limpos)
  Widget _buildAllColorsGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: AppColors.curated.map((nc) {
        final isSelected = _tempColor.toARGB32() == nc.color.toARGB32();
        return Tooltip(
          message: nc.name,
          child: InkWell(
            onTap: () => _selectCuratedColor(nc.color),
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: nc.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: nc.color.withValues(alpha: isSelected ? 0.6 : 0.3),
                    blurRadius: isSelected ? 8 : 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  // 4. Grupo Livre: Slider Arco-Íris + HEX
  Widget _buildFreeSpectrumGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRainbowSlider(),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: _promptHexColor,
            icon: const Icon(Icons.colorize_rounded, size: 16),
            label: const Text('Digitar Código HEX Personalizado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildRainbowSlider() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
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
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 38,
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

  // Botões de Ação
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text(
              'Aplicar Tema',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomThumbShape extends SliderComponentShape {
  final Color thumbColor;

  const _CustomThumbShape({required this.thumbColor});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(26, 26);

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
    canvas.drawCircle(center + const Offset(0, 2), 15, shadowPaint);

    // Borda branca externa
    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 15, outerPaint);

    // Círculo interno colorido com a cor selecionada
    final innerPaint = Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 11, innerPaint);
  }
}

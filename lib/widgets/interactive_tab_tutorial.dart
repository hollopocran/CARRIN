import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_themes.dart';

/// Identificadores de cada aba/tela do aplicativo que possui tutorial interativo próprio.
enum TutorialSection {
  dashboard,
  carts,
  shoppingList,
  statistics,
  buyerProfile,
  community,
  marketMap,
  settings,
}

extension TutorialSectionMeta on TutorialSection {
  String get id {
    switch (this) {
      case TutorialSection.dashboard:
        return 'dashboard';
      case TutorialSection.carts:
        return 'carts';
      case TutorialSection.shoppingList:
        return 'shopping_list';
      case TutorialSection.statistics:
        return 'statistics';
      case TutorialSection.buyerProfile:
        return 'buyer_profile';
      case TutorialSection.community:
        return 'community';
      case TutorialSection.marketMap:
        return 'market_map';
      case TutorialSection.settings:
        return 'settings';
    }
  }

  String get title {
    switch (this) {
      case TutorialSection.dashboard:
        return 'Início & Painel';
      case TutorialSection.carts:
        return 'Meus Carrinhos';
      case TutorialSection.shoppingList:
        return 'Lista de Compras';
      case TutorialSection.statistics:
        return 'Análises & Gráficos';
      case TutorialSection.buyerProfile:
        return 'Perfil de Comprador';
      case TutorialSection.community:
        return 'Comunidade & Radar';
      case TutorialSection.marketMap:
        return 'Mapa de Mercados';
      case TutorialSection.settings:
        return 'Ajustes & Conta';
    }
  }

  IconData get icon {
    switch (this) {
      case TutorialSection.dashboard:
        return Icons.home_rounded;
      case TutorialSection.carts:
        return Icons.shopping_cart_rounded;
      case TutorialSection.shoppingList:
        return Icons.playlist_add_check_circle_rounded;
      case TutorialSection.statistics:
        return Icons.bar_chart_rounded;
      case TutorialSection.buyerProfile:
        return Icons.psychology_alt_rounded;
      case TutorialSection.community:
        return Icons.radar_rounded;
      case TutorialSection.marketMap:
        return Icons.map_rounded;
      case TutorialSection.settings:
        return Icons.settings_rounded;
    }
  }

  Color get accentColor => AppColors.navy;
}

/// Gerenciador e modal de tutoriais interativos contextuais por aba/tela.
class InteractiveTabTutorial {
  static const String _prefPrefix = 'interactive_tab_tutorial_v547_';
  static final Set<String> _sessionShown = {};
  static SharedPreferences? _prefsCache;
  static bool _isDialogOpen = false;

  /// Permite habilitar o disparo automático em testes específicos quando desejado.
  static bool enableAutoShowInTests = false;

  static bool _isRunningInFlutterTest() {
    if (enableAutoShowInTests) return false;
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    return bindingName.contains('TestWidgetsFlutterBinding') ||
        bindingName.contains('AutomatedTestWidgetsFlutterBinding');
  }

  static String _buildKey(TutorialSection section, String? userEmail) {
    final cleanUser = (userEmail ?? 'guest').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return '$_prefPrefix${cleanUser}_${section.id}';
  }

  static Future<SharedPreferences> _getPrefs() async {
    return _prefsCache ??= await SharedPreferences.getInstance();
  }

  /// Verifica se o usuário já viu o tutorial interativo desta aba; se for a primeira vez, exibe-o
  /// somente após o término completo de qualquer animação de rota/aba para garantir fluidez de 60fps.
  static Future<void> checkAndShowIfFirstTime(
    BuildContext context,
    TutorialSection section, {
    String? userEmail,
  }) async {
    if (_isRunningInFlutterTest()) return;
    if (_isDialogOpen) return;

    final key = _buildKey(section, userEmail);
    if (_sessionShown.contains(key)) return;

    final prefs = await _getPrefs();
    final alreadySeen = prefs.getBool(key) ?? false;
    if (alreadySeen) {
      _sessionShown.add(key);
      return;
    }

    if (!context.mounted || _isDialogOpen) return;

    // Se a tela estiver no meio de uma transição de rota (Navigator.push), aguarda a animação terminar
    // antes de abrir o modal para evitar queda de quadros (jank)
    if (!enableAutoShowInTests) {
      final route = ModalRoute.of(context);
      final anim = route?.animation;
      if (anim != null && anim.status == AnimationStatus.forward) {
        await Future.delayed(const Duration(milliseconds: 260));
        if (!context.mounted || _isDialogOpen) return;
      }
    }

    _sessionShown.add(key);
    await prefs.setBool(key, true);

    if (!context.mounted) return;
    await show(context, section, userEmail: userEmail);
  }

  /// Reseta todos os tutoriais de abas para que apareçam novamente ao entrar em cada aba.
  static Future<void> resetAllTabTutorials({String? userEmail}) async {
    _sessionShown.clear();
    final prefs = await _getPrefs();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefPrefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  /// Exibe manualmente o tutorial interativo de uma aba/tela específica com animação leve acelerada por GPU.
  static Future<void> show(
    BuildContext context,
    TutorialSection section, {
    String? userEmail,
  }) async {
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(_buildKey(section, userEmail), true);
      if (!context.mounted) return;

      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Fechar tutorial',
        barrierColor: Colors.black.withValues(alpha: 0.60),
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (ctx, anim1, anim2) {
          return SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
                  child: RepaintBoundary(
                    child: Material(
                      color: Colors.transparent,
                      child: InteractiveSectionTutorialCard(
                        section: section,
                        isModal: true,
                        onClose: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (ctx, anim1, anim2, child) {
          final curved = CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
    } finally {
      _isDialogOpen = false;
    }
  }
}

/// Card interativo de demonstração e tutorial para uma seção específica do CARRIN.
/// Pode ser exibido tanto como modal de primeira visita quanto embutido na tela.
class InteractiveSectionTutorialCard extends StatefulWidget {
  final TutorialSection section;
  final bool isModal;
  final VoidCallback? onClose;
  final VoidCallback? onPrimaryAction;
  final String? primaryActionLabel;

  const InteractiveSectionTutorialCard({
    super.key,
    required this.section,
    this.isModal = false,
    this.onClose,
    this.onPrimaryAction,
    this.primaryActionLabel,
  });

  @override
  State<InteractiveSectionTutorialCard> createState() => _InteractiveSectionTutorialCardState();
}

class _InteractiveSectionTutorialCardState extends State<InteractiveSectionTutorialCard> {
  int _stepIndex = 0;
  int _stepDirection = 1;

  // --- Estado interativo: ABA INÍCIO (Dashboard) ---
  bool _demoIsFamily = false;
  double _demoSpent = 240.0;
  final double _demoBudget = 400.0;
  List<String> _demoDashboardCards = ['Saldo Restante', 'Orçamento Total', 'Análise Anual', 'Meus Carrinhos'];
  int? _tappedDashboardCard;

  // --- Estado interativo: ABA CARRINHOS (MonthSelection) ---
  String _demoPurpose = 'churrasco';
  int _selectedMockMonthIdx = 0;
  bool _simulatedNfceImport = false;

  // --- Estado interativo: LISTA DE COMPRAS (ShoppingList) ---
  bool _scanModalOpen = false;
  final String _scannedDemoName = 'Leite Condensado Moça 395g';
  final String _scannedDemoCat = 'Mercearia';
  String _scannedDemoPrice = '7,99';
  bool _batchMode = false;
  bool _marketModeActive = false;
  int _rateioPeople = 6;
  final List<Map<String, dynamic>> _demoListItems = [
    {'name': 'Arroz Branco 5kg', 'cat': 'Mercearia 🌾', 'price': 23.90, 'bought': true, 'selected': false},
    {'name': 'Contra-Filé Bovino 1kg', 'cat': 'Açougue 🥩', 'price': 44.90, 'bought': false, 'selected': false},
    {'name': 'Detergente Neutro 500ml', 'cat': 'Limpeza 🧼', 'price': 2.49, 'bought': false, 'selected': false},
  ];

  // --- Estado interativo: ABA ANÁLISES (Statistics) ---
  int _statsPeriodIdx = 0;
  int _selectedChartBarIdx = 3;
  int _selectedCatIdx = 0;

  // --- Estado interativo: PERFIL DE COMPRADOR (BuyerProfile) ---
  double _profileRatio = 0.78;

  // --- Estado interativo: ABA COMUNIDADE (CommunityRadar) ---
  int _selectedProductIdx = 0;
  String _selectedChain = 'Todas';

  // --- Estado interativo: MAPA DE MERCADOS (MarketMap) ---
  int? _selectedMapPinIdx = 0; // Começa com pino 0 ou null para demonstrar clique
  String _mapChainFilter = 'Todas';

  // --- Estado interativo: ABA AJUSTES (Settings) ---
  int _demoColorBlindIdx = 0;
  double _demoFontScale = 1.0;
  final List<String> _demoEssentials = ['Arroz 5kg', 'Feijão 1kg', 'Café 500g', 'Leite 1L'];

  void _haptic() {
    HapticFeedback.selectionClick();
  }

  void _goToStep(int newStep) {
    if (newStep == _stepIndex || newStep < 0 || newStep >= _totalSteps) return;
    _haptic();
    setState(() {
      _stepDirection = newStep > _stepIndex ? 1 : -1;
      _stepIndex = newStep;
    });
  }

  List<String> get _stepLabels {
    switch (widget.section) {
      case TutorialSection.dashboard:
        return const ['1. Velocímetro', '2. Família & GPS', '3. Atalhos'];
      case TutorialSection.carts:
        return const ['1. Finalidades', '2. Histórico & NFC-e'];
      case TutorialSection.shoppingList:
        return const ['1. Scanner Direto', '2. Seleção em Lote', '3. Modo Mercado'];
      case TutorialSection.statistics:
        return const ['1. Evolução Mensal', '2. Categorias'];
      case TutorialSection.buyerProfile:
        return const ['Arquétipos'];
      case TutorialSection.community:
        return const ['1. Comparador', '2. Redes & Busca'];
      case TutorialSection.marketMap:
        return const ['1. Pinos & Mapa', '2. Camadas & Redes'];
      case TutorialSection.settings:
        return const ['1. Temas & Fonte', '2. Nuvem & Backup'];
    }
  }

  int get _totalSteps => _stepLabels.length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final bgColor = isDark ? const Color(0xFF1A1D2D) : Colors.white;
    final labels = _stepLabels;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cabeçalho colorido da seção
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: isDark ? 0.25 : 0.14),
                      accent.withValues(alpha: 0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(widget.section.icon, color: accent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'TUTORIAL INTERATIVO',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                  if (_totalSteps > 1) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      'Passo ${_stepIndex + 1} de $_totalSteps',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.section.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onClose != null)
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Fechar',
                            onPressed: widget.onClose,
                          ),
                      ],
                    ),
                    // Abas rápidas de passos para troca instantânea em 1 toque
                    if (_totalSteps > 1) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_totalSteps, (i) {
                            final active = i == _stepIndex;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => _goToStep(i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? accent
                                        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.75)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: active ? accent : accent.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Text(
                                    labels[i],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: active ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Conteúdo interativo fluido (com AnimatedSize e transição acelerada por GPU)
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: widget.isModal && _totalSteps > 1
                      ? (details) {
                          final vx = details.primaryVelocity ?? 0;
                          if (vx < -240 && _stepIndex < _totalSteps - 1) {
                            _goToStep(_stepIndex + 1);
                          } else if (vx > 240 && _stepIndex > 0) {
                            _goToStep(_stepIndex - 1);
                          }
                        }
                      : null,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: Offset(0.05 * _stepDirection, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey('${widget.section.id}_step_$_stepIndex'),
                          child: _buildStepBody(context, isDark, accent),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Rodapé de navegação entre passos
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black12 : Colors.grey.withValues(alpha: 0.04),
                  border: Border(
                    top: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                ),
                child: Row(
                  children: [
                    if (_stepIndex > 0)
                      TextButton.icon(
                        onPressed: () => _goToStep(_stepIndex - 1),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Anterior'),
                      )
                    else if (widget.onClose != null)
                      TextButton(
                        onPressed: widget.onClose,
                        child: const Text('Pular', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    if (_totalSteps > 1)
                      Row(
                        children: List.generate(_totalSteps, (i) {
                          final active = i == _stepIndex;
                          return GestureDetector(
                            onTap: () => _goToStep(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: active ? 18 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: active ? accent : accent.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }),
                      ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        if (_stepIndex < _totalSteps - 1) {
                          _goToStep(_stepIndex + 1);
                        } else {
                          _haptic();
                          if (widget.onPrimaryAction != null) {
                            widget.onPrimaryAction!();
                          } else if (widget.onClose != null) {
                            widget.onClose!();
                          } else {
                            _goToStep(0);
                          }
                        }
                      },
                      icon: Icon(
                        _stepIndex < _totalSteps - 1
                            ? Icons.arrow_forward_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _stepIndex < _totalSteps - 1
                            ? 'Próximo'
                            : (widget.primaryActionLabel ?? (widget.isModal ? 'Entendi!' : 'Reiniciar Demo')),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveHintBanner(String text, Color accent) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, size: 17, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody(BuildContext context, bool isDark, Color accent) {
    switch (widget.section) {
      case TutorialSection.dashboard:
        return _buildDashboardSteps(isDark, accent);
      case TutorialSection.carts:
        return _buildCartsSteps(isDark, accent);
      case TutorialSection.shoppingList:
        return _buildShoppingListSteps(isDark, accent);
      case TutorialSection.statistics:
        return _buildStatisticsSteps(isDark, accent);
      case TutorialSection.buyerProfile:
        return _buildBuyerProfileSteps(isDark, accent);
      case TutorialSection.community:
        return _buildCommunitySteps(isDark, accent);
      case TutorialSection.marketMap:
        return _buildMarketMapSteps(isDark, accent);
      case TutorialSection.settings:
        return _buildSettingsSteps(isDark, accent);
    }
  }

  // ===========================================================================
  // 1. ABA INÍCIO (DASHBOARD)
  // ===========================================================================
  Widget _buildDashboardSteps(bool isDark, Color accent) {
    if (_stepIndex == 0) {
      final percent = (_demoSpent / _demoBudget).clamp(0.0, 1.2);
      final isAlert = percent >= 0.9;
      final gaugeColor = isAlert
          ? Colors.redAccent
          : (percent >= 0.7 ? Colors.orangeAccent : Colors.teal);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monitor de Gastos & Velocímetro',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Acompanhe quanto já gastou no mês em tempo real. Toque no velocímetro para abrir sua lista ativa e arraste a barra abaixo para testar o alerta de 90%:',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          _buildInteractiveHintBanner('Arraste o controle abaixo para simular seus gastos!', accent),
          Center(
            child: GestureDetector(
              onTap: () {
                _haptic();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No painel real, tocar no velocímetro abre direto a lista do mês!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 125,
                    height: 125,
                    child: CircularProgressIndicator(
                      value: percent.clamp(0.0, 1.0),
                      strokeWidth: 12,
                      backgroundColor: gaugeColor.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'R\$ ${_demoSpent.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'de R\$ ${_demoBudget.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: gaugeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${(percent * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: gaugeColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Slider(
            value: _demoSpent,
            min: 0,
            max: 450,
            activeColor: gaugeColor,
            onChanged: (v) {
              if (v >= 360 && _demoSpent < 360) _haptic();
              setState(() => _demoSpent = v);
            },
          ),
          if (isAlert)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pé no freio! Você passou de 90% do orçamento planejado.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    if (_stepIndex == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Espaço Pessoal vs. Família + Geofencing',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Separe suas compras pessoais das compras da casa com 1 toque. Além disso, o CARRIN detecta automaticamente em qual supermercado você chegou via GPS!',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          _buildInteractiveHintBanner('Toque abaixo para alternar entre Meu Carrinho e Família:', accent),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _haptic();
                      setState(() => _demoIsFamily = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_demoIsFamily ? AppThemes.primaryNavy : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_rounded, size: 16, color: !_demoIsFamily ? Colors.white : Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'Meu Carrinho',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: !_demoIsFamily ? Colors.white : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _haptic();
                      setState(() => _demoIsFamily = true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _demoIsFamily ? Colors.deepOrange : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.family_restroom_rounded, size: 16, color: _demoIsFamily ? Colors.white : Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'Família',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _demoIsFamily ? Colors.white : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (_demoIsFamily ? Colors.deepOrange : Colors.blue).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: (_demoIsFamily ? Colors.deepOrange : Colors.blue).withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _demoIsFamily ? Icons.home_work_rounded : Icons.person_pin_circle_rounded,
                      color: _demoIsFamily ? Colors.deepOrange : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _demoIsFamily
                            ? 'Espaço Família Ativo (Listas da Casa)'
                            : 'Espaço Meu Carrinho Ativo (Listas Pessoais)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 15, color: Colors.teal),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Geofencing: Supermercados Guanabara - Niterói detectado automaticamente!',
                        style: TextStyle(fontSize: 11.5, color: Colors.teal, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cards de Atalho Reordenáveis',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Toque em um card para ver seu histórico rápido ou inverta a ordem dos cards como preferir:',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
        ),
        const SizedBox(height: 12),
        _buildInteractiveHintBanner('Toque em qualquer card abaixo ou clique em "Inverter Ordem":', accent),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _demoDashboardCards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.1,
          ),
          itemBuilder: (ctx, i) {
            final title = _demoDashboardCards[i];
            final isSelected = _tappedDashboardCard == i;
            return InkWell(
              onTap: () {
                _haptic();
                setState(() => _tappedDashboardCard = i);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent.withValues(alpha: 0.15)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSelected ? accent : Colors.transparent, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.drag_indicator_rounded, size: 16, color: isSelected ? accent : Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              _haptic();
              setState(() {
                _demoDashboardCards = _demoDashboardCards.reversed.toList();
              });
            },
            icon: const Icon(Icons.swap_vert_rounded, size: 16),
            label: const Text('Simular Reordenação', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. ABA CARRINHOS (MONTH SELECTION)
  // ===========================================================================
  Widget _buildCartsSteps(bool isDark, Color accent) {
    if (_stepIndex == 0) {
      final purposes = [
        {'id': 'geral', 'label': 'Geral', 'icon': Icons.shopping_cart_outlined, 'color': Colors.indigo, 'items': 'Arroz, Feijão, Café, Leite, Óleo...'},
        {'id': 'churrasco', 'label': 'Churrasco', 'icon': Icons.outdoor_grill_rounded, 'color': Colors.deepOrange, 'items': 'Picanha, Linguiça, Pão de Alho, Carvão, Cerveja + Rateio!'},
        {'id': 'abastecimento', 'label': 'Atacarejo', 'icon': Icons.inventory_2_outlined, 'color': Colors.teal, 'items': 'Fardos, Limpeza Pesada, Estoque Mensal...'},
        {'id': 'conveniencia', 'label': 'Reposição', 'icon': Icons.bolt_rounded, 'color': Colors.amber.shade800, 'items': 'Pão, Frutas, Hortifruti e Caixa Rápido...'},
      ];
      final selected = purposes.firstWhere((p) => p['id'] == _demoPurpose);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Finalidades & Templates Inteligentes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Ao criar um Novo Carrinho, escolha a finalidade da compra para carregar automaticamente itens essenciais, kit churrasco ou copiar do mês anterior:',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          _buildInteractiveHintBanner('Toque nas finalidades abaixo para testar os templates:', accent),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: purposes.map((p) {
              final isSel = p['id'] == _demoPurpose;
              final color = p['color'] as Color;
              return ChoiceChip(
                label: Text(p['label'] as String),
                avatar: Icon(p['icon'] as IconData, size: 16, color: isSel ? Colors.white : color),
                selected: isSel,
                selectedColor: color,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                onSelected: (_) {
                  _haptic();
                  setState(() => _demoPurpose = p['id'] as String);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (selected['color'] as Color).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: (selected['color'] as Color).withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Template Sugerido: ${selected['label']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: selected['color'] as Color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selected['items'] as String,
                  style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final mockMonths = [
      {'name': 'Outubro de 2026', 'spent': 345.90, 'budget': 400.0, 'items': 32},
      {'name': 'Churrasco Fim de Semana', 'spent': 280.00, 'budget': 300.0, 'items': 14},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Histórico de Carrinhos & Nota Fiscal (NFC-e)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Toque em um carrinho para abri-lo ou use o menu (⋮) para escanear o QR Code da Nota Fiscal SEFAZ e importar todos os itens da compra de uma vez!',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
        ),
        const SizedBox(height: 12),
        _buildInteractiveHintBanner('Toque nos carrinhos abaixo ou simule a leitura de Nota Fiscal:', accent),
        ...List.generate(mockMonths.length, (i) {
          final m = mockMonths[i];
          final isSel = _selectedMockMonthIdx == i;
          final spent = m['spent'] as double;
          final budget = m['budget'] as double;
          final pct = (spent / budget).clamp(0.0, 1.0);
          return GestureDetector(
            onTap: () {
              _haptic();
              setState(() => _selectedMockMonthIdx = i);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSel
                    ? accent.withValues(alpha: 0.12)
                    : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSel ? accent : Colors.transparent, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        Text(
                          'Gasto: R\$ ${spent.toStringAsFixed(2).replaceAll('.', ',')} • Saldo: R\$ ${(budget - spent).toStringAsFixed(2).replaceAll('.', ',')}',
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: pct,
                          strokeWidth: 3.5,
                          color: accent,
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        ),
                        Text('${(pct * 100).toInt()}%', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () {
            _haptic();
            setState(() => _simulatedNfceImport = !_simulatedNfceImport);
          },
          icon: Icon(_simulatedNfceImport ? Icons.check_circle : Icons.receipt_long_rounded, size: 18),
          label: Text(
            _simulatedNfceImport
                ? 'Nota Fiscal SEFAZ Importada (18 itens + loja identificada!)'
                : 'Simular Leitura de Cupom Fiscal (NFC-e)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 3. LISTA DE COMPRAS (SHOPPING LIST)
  // ===========================================================================
  Widget _buildShoppingListSteps(bool isDark, Color accent) {
    if (_stepIndex == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scanner Direto para o Menu de Edição',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Ao escanear um código de barras, o CARRIN NÃO exibe perguntas intermediárias: ele busca na API e abre direto o menu de edição com os dados preenchidos!',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          _buildInteractiveHintBanner(
            _scanModalOpen
                ? 'Edite qualquer campo abaixo como no menu real do app!'
                : 'Toque em "Escanear Código de Barras" para ver o menu abrir direto:',
            accent,
          ),
          if (!_scanModalOpen)
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemes.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () {
                  _haptic();
                  setState(() => _scanModalOpen = true);
                },
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Simular Scanner de Produto (EAN-13)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_scanner_rounded, size: 13, color: Colors.teal),
                            SizedBox(width: 4),
                            Text(
                              'Preenchido via código de barras (API)',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.teal),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _scanModalOpen = false),
                        child: const Text('Testar de novo', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Produto: $_scannedDemoName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Código: 7891000100103 • Categoria: $_scannedDemoCat', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Preço Unit.: R\$ ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ChoiceChip(
                        label: const Text('7,99'),
                        selected: _scannedDemoPrice == '7,99',
                        onSelected: (_) => setState(() => _scannedDemoPrice = '7,99'),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('6,49 (Promoção)'),
                        selected: _scannedDemoPrice == '6,49',
                        onSelected: (_) => setState(() => _scannedDemoPrice = '6,49'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    }

    if (_stepIndex == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Marcar Comprado & Seleção em Lote',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Toque na caixa para riscar um item ou segure pressionado para selecionar vários itens de uma só vez:',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          _buildInteractiveHintBanner(
            _batchMode
                ? 'Modo em Lote ativo! Toque nos itens e depois em "Marcar Comprados"'
                : 'Toque para riscar ou SEGURE PRESSIONADO em um item abaixo:',
            accent,
          ),
          ...List.generate(_demoListItems.length, (i) {
            final item = _demoListItems[i];
            final bought = item['bought'] as bool;
            final selected = item['selected'] as bool;
            return GestureDetector(
              onLongPress: () {
                _haptic();
                setState(() {
                  _batchMode = true;
                  item['selected'] = true;
                });
              },
              onTap: () {
                _haptic();
                setState(() {
                  if (_batchMode) {
                    item['selected'] = !selected;
                    if (_demoListItems.every((e) => e['selected'] == false)) {
                      _batchMode = false;
                    }
                  } else {
                    item['bought'] = !bought;
                  }
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.15)
                      : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? accent : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Icon(
                      _batchMode
                          ? (selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                          : (bought ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded),
                      color: _batchMode ? accent : (bought ? Colors.green : Colors.grey),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item['name'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          decoration: bought ? TextDecoration.lineThrough : null,
                          color: bought ? Colors.grey : null,
                        ),
                      ),
                    ),
                    Text(
                      'R\$ ${(item['price'] as double).toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_batchMode)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () {
                  _haptic();
                  setState(() {
                    for (final it in _demoListItems) {
                      if (it['selected'] == true) {
                        it['bought'] = true;
                        it['selected'] = false;
                      }
                    }
                    _batchMode = false;
                  });
                },
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text('Riscar Selecionados', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Modo Mercado, Peso (Kg) & Rateio',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Ative o Modo Mercado para manter a tela acesa com bloqueio anti-toque no bolso, calcule itens por quilo e divida a conta do churrasco:',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
        ),
        const SizedBox(height: 12),
        _buildInteractiveHintBanner('Experimente o Modo Mercado e o Rateio de Conta abaixo:', accent),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Modo Mercado (Tela Acesa & Trava de Bolso)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: Text(
            _marketModeActive ? 'Ativado! Bloqueia toques acidentais após 15s.' : 'Toque para testar',
            style: const TextStyle(fontSize: 11.5),
          ),
          value: _marketModeActive,
          onChanged: (v) {
            _haptic();
            setState(() => _marketModeActive = v);
          },
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Simulador de Rateio (R\$ 300,00):', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: _rateioPeople > 1
                      ? () {
                          _haptic();
                          setState(() => _rateioPeople--);
                        }
                      : null,
                ),
                Text('$_rateioPeople pessoas', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () {
                    _haptic();
                    setState(() => _rateioPeople++);
                  },
                ),
              ],
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Valor por pessoa: R\$ ${(300.0 / _rateioPeople).toStringAsFixed(2).replaceAll('.', ',')}',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: accent),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. ABA ANÁLISES (STATISTICS)
  // ===========================================================================
  Widget _buildStatisticsSteps(bool isDark, Color accent) {
    final months = ['Jul', 'Ago', 'Set', 'Out'];
    final values = [310.0, 285.0, 390.0, 340.0];
    final budgets = [350.0, 350.0, 380.0, 400.0];

    if (_stepIndex == 0) {
      final selMonth = months[_selectedChartBarIdx];
      final selVal = values[_selectedChartBarIdx];
      final selBud = budgets[_selectedChartBarIdx];
      final bal = selBud - selVal;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gráfico Interativo de Evolução Mensal',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Alterne o período (3 Meses, 6 Meses, 1 Ano) e toque nas colunas/pontos do gráfico para inspecionar gasto e saldo de cada mês:',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          _buildInteractiveHintBanner('Toque nas barras dos meses abaixo para inspecionar os valores:', accent),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final labels = ['3 Meses', '6 Meses', '1 Ano'];
              final active = _statsPeriodIdx == i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(labels[i], style: const TextStyle(fontSize: 11)),
                  selected: active,
                  onSelected: (_) {
                    _haptic();
                    setState(() => _statsPeriodIdx = i);
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppThemes.primaryNavy,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$selMonth/2026 • Gasto: R\$ ${selVal.toStringAsFixed(0)} • ${bal >= 0 ? "Economia: R\$ ${bal.toStringAsFixed(0)}" : "Excedido: R\$ ${bal.abs().toStringAsFixed(0)}"}',
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(months.length, (i) {
                    final isSel = _selectedChartBarIdx == i;
                    final h = (values[i] / 400.0) * 90;
                    return GestureDetector(
                      onTap: () {
                        _haptic();
                        setState(() => _selectedChartBarIdx = i);
                      },
                      child: Column(
                        children: [
                          Text(
                            'R\$ ${values[i].toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSel ? accent : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: isSel ? 38 : 30,
                            height: h,
                            decoration: BoxDecoration(
                              color: isSel ? accent : accent.withValues(alpha: 0.35),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            months[i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.w900 : FontWeight.normal,
                              color: isSel ? accent : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final cats = [
      {'name': 'Mercearia 🌾', 'pct': 0.45, 'val': 'R\$ 153,00', 'tip': 'Arroz, feijão, café e massas representam 45% da cesta.'},
      {'name': 'Açougue & Frios 🥩', 'pct': 0.30, 'val': 'R\$ 102,00', 'tip': 'Dica: compare proteínas no Radar de Preços para economizar até 22%.'},
      {'name': 'Limpeza & Higiene 🧼', 'pct': 0.25, 'val': 'R\$ 85,00', 'tip': 'Comprar embalagens econômicas em atacarejos reduz este custo.'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categorias & Perfil de Comprador',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Descubra para onde vai seu dinheiro e acesse o diagnóstico completo do seu Perfil de Comprador no topo da aba Análises:',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
        ),
        const SizedBox(height: 12),
        _buildInteractiveHintBanner('Toque em uma categoria abaixo para ver a análise detalhada:', accent),
        ...List.generate(cats.length, (i) {
          final c = cats[i];
          final isSel = _selectedCatIdx == i;
          return GestureDetector(
            onTap: () {
              _haptic();
              setState(() => _selectedCatIdx = i);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSel ? accent.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSel ? accent : Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(c['val'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: accent)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: c['pct'] as double,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                    color: accent,
                    backgroundColor: accent.withValues(alpha: 0.15),
                  ),
                  if (isSel) ...[
                    const SizedBox(height: 6),
                    Text(c['tip'] as String, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ===========================================================================
  // 5. PERFIL DE COMPRADOR (BUYER PROFILE)
  // ===========================================================================
  Widget _buildBuyerProfileSteps(bool isDark, Color accent) {
    String title;
    String desc;
    Color color;
    IconData icon;
    if (_profileRatio <= 0.85) {
      title = 'Poupador Consciente';
      desc = 'Você mantém os pés no freio e fecha os meses com excelente economia!';
      color = Colors.green;
      icon = Icons.savings_rounded;
    } else if (_profileRatio <= 1.0) {
      title = 'Planejador Rigoroso';
      desc = 'Equilíbrio cirúrgico entre o planejado e o executado no caixa.';
      color = Colors.blueAccent;
      icon = Icons.track_changes_rounded;
    } else {
      title = 'Comprador Entusiasta';
      desc = 'Despensa cheia! Você prioriza oportunidades mesmo passando do teto inicial.';
      color = Colors.orange;
      icon = Icons.local_fire_department_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Como Funciona seu Arquétipo de Comprador',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'O CARRIN cruza seus orçamentos, frequência de itens e categorias para identificar seu estilo financeiro. Arraste o controle para simular os 3 arquétipos:',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
        ),
        const SizedBox(height: 12),
        _buildInteractiveHintBanner('Arraste para ver seu arquétipo mudar em tempo real:', accent),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.2),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color)),
                    const SizedBox(height: 4),
                    Text(desc, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: _profileRatio,
          min: 0.6,
          max: 1.2,
          activeColor: color,
          onChanged: (v) => setState(() => _profileRatio = v),
        ),
        Center(
          child: Text(
            'Uso médio do orçamento: ${(_profileRatio * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 6. ABA COMUNIDADE / RADAR DE PREÇOS
  // ===========================================================================
  Widget _buildCommunitySteps(bool isDark, Color accent) {
    if (_stepIndex == 0) {
      final products = [
        {'name': 'Arroz Branco 5kg', 'min': 21.90, 'max': 28.90, 'best': 'Supermercados Guanabara', 'save': '24%'},
        {'name': 'Café Torrado 500g', 'min': 14.50, 'max': 19.90, 'best': 'Assaí Atacadista - Tribobó', 'save': '27%'},
        {'name': 'Azeite Extra Virgem 500ml', 'min': 29.90, 'max': 39.90, 'best': 'Atacadão - São Gonçalo', 'save': '25%'},
      ];
      final sel = products[_selectedProductIdx];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Radar de Preços: Lista, Comparador e Mercados',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Compare o preço de qualquer produto entre os mercados da sua região e descubra na hora onde economizar mais:',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          _buildInteractiveHintBanner('Toque em um produto abaixo para comparar os preços por loja:', accent),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(products.length, (i) {
              final active = _selectedProductIdx == i;
              return ChoiceChip(
                label: Text(products[i]['name'] as String, style: const TextStyle(fontSize: 11.5)),
                selected: active,
                selectedColor: accent,
                labelStyle: TextStyle(
                  color: active ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (_) {
                  _haptic();
                  setState(() => _selectedProductIdx = i);
                },
              );
            }),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(sel['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        'Economize ${sel['save']}',
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '🏆 Mais barato: ${sel['best']} por R\$ ${(sel['min'] as double).toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                Text(
                  'Mais caro na região: R\$ ${(sel['max'] as double).toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final chains = ['Todas', 'Guanabara', 'Assaí', 'Supermarket', 'Rede Economia'];
    final allMockMarkets = [
      {'name': 'Supermercados Guanabara - Niterói', 'chain': 'Guanabara', 'city': 'Centro, Niterói', 'crown': true},
      {'name': 'Assaí Atacadista - Tribobó', 'chain': 'Assaí', 'city': 'Tribobó, São Gonçalo', 'crown': false},
      {'name': 'Supermarket - Rio do Ouro', 'chain': 'Supermarket', 'city': 'Rio do Ouro, São Gonçalo', 'crown': false},
      {'name': 'Rede Economia - Inoã', 'chain': 'Rede Economia', 'city': 'Inoã, Maricá', 'crown': false},
    ];
    final filtered = _selectedChain == 'Todas'
        ? allMockMarkets
        : allMockMarkets.where((m) => m['chain'] == _selectedChain).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pesquisa por Nome e Filtro por Redes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Na aba Mercados (e no Mapa!), você pode pesquisar qualquer supermercado pelo nome ou bairro e filtrar pelas principais redes:',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
        ),
        const SizedBox(height: 12),
        _buildInteractiveHintBanner('Toque nas redes abaixo para filtrar as lojas instantaneamente:', accent),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: chains.map((c) {
              final active = _selectedChain == c;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(c, style: const TextStyle(fontSize: 11.5)),
                  selected: active,
                  selectedColor: AppThemes.primaryNavy,
                  labelStyle: TextStyle(
                    color: active ? Colors.white : (isDark ? Colors.white : Colors.black87),
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) {
                    _haptic();
                    setState(() => _selectedChain = c);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        ...filtered.map((m) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(m['crown'] == true ? '👑' : '📍', style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        Text(m['city'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // ===========================================================================
  // 7. MAPA INTERATIVO DE MERCADOS (MARKET MAP)
  // ===========================================================================
  Widget _buildMarketMapSteps(bool isDark, Color accent) {
    final pins = [
      {'name': 'Supermercados Guanabara - Niterói', 'price': 'Média R\$ 11,80', 'crown': true, 'x': 0.22, 'y': 0.42},
      {'name': 'Assaí Atacadista - Tribobó', 'price': 'Média R\$ 12,40', 'crown': false, 'x': 0.56, 'y': 0.28},
      {'name': 'Supermarket - Icaraí', 'price': 'Média R\$ 13,10', 'crown': false, 'x': 0.72, 'y': 0.58},
    ];

    if (_stepIndex == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mapa Estilo Google Maps + Pinos Inteligentes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Escolha o visual do mapa no botão de Camadas (Google Padrão desenhado, Satélite, Relevo ou Limpo), toque nos pinos dos 3.484 mercados (.mwm) para ver o nome ou toque direto no mapa!',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          _buildInteractiveHintBanner('Toque nos pinos no mini-mapa abaixo para revelar o nome da loja:', accent),
          Container(
            height: 165,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF132226) : const Color(0xFFE6F2EA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Stack(
              children: [
                // Linhas decorativas simulando ruas do mapa
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  child: Container(height: 2, color: Colors.grey.withValues(alpha: 0.2)),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 140,
                  child: Container(width: 2, color: Colors.grey.withValues(alpha: 0.2)),
                ),
                ...List.generate(pins.length, (i) {
                  final p = pins[i];
                  final isSel = _selectedMapPinIdx == i;
                  final isCrown = p['crown'] == true;
                  return Align(
                    alignment: Alignment(
                      (p['x'] as double) * 2 - 1,
                      (p['y'] as double) * 2 - 1,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        _haptic();
                        setState(() => _selectedMapPinIdx = i);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSel)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppThemes.primaryNavy,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${p['name']} • ${p['price']}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          Container(
                            width: isSel ? 36 : 30,
                            height: isSel ? 36 : 30,
                            decoration: BoxDecoration(
                              color: isCrown ? Colors.amber.shade700 : (isSel ? accent : Colors.teal),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: isCrown
                                ? const Text('👑', style: TextStyle(fontSize: 14))
                                : const Icon(Icons.storefront_rounded, color: Colors.white, size: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Camadas Google, Busca por Redes e Seleção no Mapa',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Use o botão Camadas para alternar entre Google Desenhado, Satélite e Relevo, ative o botão de Toque no Mapa para escolher qualquer ponto desenhado ou filtre pelas redes:',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
        ),
        const SizedBox(height: 12),
        _buildInteractiveHintBanner('Teste os chips de rede abaixo como no topo do mapa:', accent),
        Wrap(
          spacing: 6,
          children: ['Todas', 'Guanabara', 'Assaí', 'Supermarket', 'Rede Economia'].map((c) {
            final isSel = _mapChainFilter == c;
            return ChoiceChip(
              label: Text(c, style: const TextStyle(fontSize: 11.5)),
              selected: isSel,
              selectedColor: accent,
              labelStyle: TextStyle(
                color: isSel ? Colors.white : (isDark ? Colors.white : Colors.black87),
                fontWeight: FontWeight.bold,
              ),
              onSelected: (_) {
                _haptic();
                setState(() => _mapChainFilter = c);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ===========================================================================
  // 8. ABA AJUSTES (SETTINGS)
  // ===========================================================================
  Widget _buildSettingsSteps(bool isDark, Color accent) {
    if (_stepIndex == 0) {
      final modes = ['Padrão', 'Protanopia', 'Deuteranopia', 'Alto Contraste'];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Temas, Acessibilidade & Tamanho da Fonte',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Personalize as cores do aplicativo, ative paletas para daltônicos e ajuste o tamanho das letras em tempo real:',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          _buildInteractiveHintBanner('Teste a escala de fonte e os modos visuais abaixo:', accent),
          Wrap(
            spacing: 6,
            children: List.generate(modes.length, (i) {
              final active = _demoColorBlindIdx == i;
              return ChoiceChip(
                label: Text(modes[i], style: const TextStyle(fontSize: 11)),
                selected: active,
                onSelected: (_) {
                  _haptic();
                  setState(() => _demoColorBlindIdx = i);
                },
              );
            }),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Exemplo de Item: Arroz 5kg • R\$ 23,90',
              style: TextStyle(fontSize: 14 * _demoFontScale, fontWeight: FontWeight.bold),
            ),
          ),
          Slider(
            value: _demoFontScale,
            min: 0.85,
            max: 1.30,
            onChanged: (v) => setState(() => _demoFontScale = v),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Itens Essenciais, Google Sheets & Backups',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Cadastre seus Itens Essenciais recorrentes, gerencie sua planilha Google Sheets ou exporte backups locais com segurança:',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
        ),
        const SizedBox(height: 12),
        _buildInteractiveHintBanner('Toque nos Itens Essenciais abaixo para testar a lista rápida:', accent),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ..._demoEssentials.map((item) => InputChip(
                  label: Text(item, style: const TextStyle(fontSize: 12)),
                  onDeleted: () {
                    _haptic();
                    setState(() => _demoEssentials.remove(item));
                  },
                )),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Adicionar Azeite', style: TextStyle(fontSize: 12)),
              onPressed: () {
                _haptic();
                if (!_demoEssentials.contains('Azeite 500ml')) {
                  setState(() => _demoEssentials.add('Azeite 500ml'));
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

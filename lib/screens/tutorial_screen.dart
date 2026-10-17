import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/item_provider.dart';
import '../theme/app_themes.dart';
import '../widgets/interactive_tab_tutorial.dart';
import 'main_screen.dart';

class TutorialScreen extends StatefulWidget {
  final bool showStartButton;

  const TutorialScreen({
    super.key,
    this.showStartButton = true,
  });

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _numPages = 9;

  // Estado interativo do Slide 2 (Visão Geral das 5 Abas + Mapa)
  int _selectedTabOverviewIdx = 0;

  // Estado interativo do Slide 9 (Calculadora de Peso / Preço por Kg)
  double _demoWeightGrams = 650;
  final double _demoPricePerKg = 42.90;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _triggerVibration() {
    HapticFeedback.selectionClick();
  }

  void _nextPage() {
    _triggerVibration();
    if (_currentPage < _numPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishTutorial();
    }
  }

  void _prevPage() {
    _triggerVibration();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finishTutorial() async {
    final itemProvider = context.read<ItemProvider>();
    final email = itemProvider.activeUserEmail ?? 'guest';
    final key = 'has_seen_tutorial_${email.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);

    if (!mounted) return;

    if (widget.showStartButton) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121420) : const Color(0xFFF6F8FC);
    final textColor = isDark ? Colors.white : Colors.black87;
    final primaryColor = isDark ? const Color(0xFFAEB2FF) : AppThemes.primaryNavy;

    final slideTitles = [
      'Boas-vindas',
      '5 Abas do App',
      'Aba Início',
      'Aba Carrinhos',
      'Lista & Scanner',
      'Aba Análises',
      'Perfil Comprador',
      'Comunidade',
      'Mapa & Ajustes',
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Barra Superior: Título + Botão para Reativar Tutoriais + Pular/Fechar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded, size: 16, color: primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          'Guia Interativo (${_currentPage + 1}/$_numPages)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      _triggerVibration();
                      final provider = context.read<ItemProvider>();
                      await InteractiveTabTutorial.resetAllTabTutorials(userEmail: provider.activeUserEmail);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tutoriais das abas reativados! Eles abrirão na próxima visita a cada aba.'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.replay_rounded, size: 16),
                    label: const Text('Reativar nas Abas', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: _finishTutorial,
                    child: Text(
                      widget.showStartButton ? 'Pular' : 'Fechar',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.65),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Barra de atalho rápido para saltar direto para qualquer seção do tutorial
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: slideTitles.length,
                itemBuilder: (context, index) {
                  final active = _currentPage == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(slideTitles[index], style: const TextStyle(fontSize: 11.5)),
                      selected: active,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      selectedColor: primaryColor,
                      labelStyle: TextStyle(
                        color: active ? (isDark ? Colors.black : Colors.white) : textColor,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (_) {
                        _triggerVibration();
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 6),

            // Área Principal dos Slides Interativos
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (int page) {
                  setState(() => _currentPage = page);
                },
                children: [
                  _buildSlide1Welcome(textColor, isDark, primaryColor),
                  _buildSlide2FiveTabsOverview(textColor, isDark, primaryColor),
                  _buildSectionInteractiveSlide(
                    section: TutorialSection.dashboard,
                    headerTitle: '1ª Aba: Início & Painel',
                    headerSubtitle:
                        'Arraste o velocímetro de gastos, alterne entre Meu Carrinho e Família e teste os cards reordenáveis:',
                    textColor: textColor,
                  ),
                  _buildSectionInteractiveSlide(
                    section: TutorialSection.carts,
                    headerTitle: '2ª Aba: Meus Carrinhos & NFC-e',
                    headerSubtitle:
                        'Teste as finalidades inteligentes (Geral, Churrasco, Atacarejo, Reposição) e a importação de Nota Fiscal SEFAZ:',
                    textColor: textColor,
                  ),
                  _buildSectionInteractiveSlide(
                    section: TutorialSection.shoppingList,
                    headerTitle: 'Lista de Compras & Scanner Direto',
                    headerSubtitle:
                        'Ao escanear um produto, o app busca na API e abre DIRETO o menu de edição sem perguntas! Teste também lote e Modo Mercado:',
                    textColor: textColor,
                  ),
                  _buildSectionInteractiveSlide(
                    section: TutorialSection.statistics,
                    headerTitle: '3ª Aba: Análises & Gráficos',
                    headerSubtitle:
                        'Toque nas barras do gráfico para inspecionar gastos mensais e explore o detalhamento por categoria:',
                    textColor: textColor,
                  ),
                  _buildSectionInteractiveSlide(
                    section: TutorialSection.buyerProfile,
                    headerTitle: 'Diagnóstico: Perfil de Comprador',
                    headerSubtitle:
                        'Arraste o controle abaixo para simular como o CARRIN classifica seu arquétipo financeiro:',
                    textColor: textColor,
                  ),
                  _buildSectionInteractiveSlide(
                    section: TutorialSection.community,
                    headerTitle: '4ª Aba: Comunidade & Radar de Preços',
                    headerSubtitle:
                        'Compare preços entre mercados em cache local instantâneo e filtre lojas por rede:',
                    textColor: textColor,
                  ),
                  _buildSlide9MapAndCalculators(textColor, isDark, primaryColor),
                ],
              ),
            ),

            // Rodapé com Indicadores e Botões Anterior / Próximo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      onPressed: _prevPage,
                      icon: Icon(Icons.arrow_back_ios_rounded, color: textColor),
                      tooltip: 'Slide Anterior',
                    )
                  else
                    const SizedBox(width: 48),

                  Row(
                    children: List.generate(
                      _numPages,
                      (index) => GestureDetector(
                        onTap: () {
                          _triggerVibration();
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 8,
                          width: _currentPage == index ? 22 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? primaryColor
                                : textColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),

                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemes.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 3,
                    ),
                    child: Text(
                      _currentPage == _numPages - 1
                          ? (widget.showStartButton ? 'Começar!' : 'Concluir')
                          : 'Próximo',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SLIDE 1: BOAS-VINDAS + ATALHOS PARA TUTORIAIS POR ABA
  // ===========================================================================
  Widget _buildSlide1Welcome(Color textColor, bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withValues(alpha: 0.12),
                ),
                padding: const EdgeInsets.all(18),
                child: ClipOval(
                  child: Image.asset(
                    'assets/1.png',
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => const Icon(
                      Icons.shopping_cart_checkout_rounded,
                      size: 48,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Bem-vindo ao CARRIN!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Seu copiloto inteligente de supermercado. Todos os cards de demonstração deste guia — e os que aparecem na sua primeira visita a cada aba — são 100% interativos!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.72), height: 1.4),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.ads_click_rounded, color: primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Toque em qualquer seção para abrir seu Card Interativo:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TutorialSection.values.map((section) {
                        return ActionChip(
                          avatar: Icon(section.icon, size: 16, color: section.accentColor),
                          label: Text(
                            section.title,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            _triggerVibration();
                            InteractiveTabTutorial.show(context, section);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '💡 Dica: Em todas as abas e telas do app, você também encontra o botão (?) no topo para rever o tutorial interativo daquela tela a qualquer momento.',
                      style: TextStyle(fontSize: 11.5, color: textColor.withValues(alpha: 0.65)),
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

  // ===========================================================================
  // SLIDE 2: VISÃO GERAL INTERATIVA DAS 5 ABAS PRINCIPAIS + MAPA
  // ===========================================================================
  Widget _buildSlide2FiveTabsOverview(Color textColor, bool isDark, Color primaryColor) {
    final tabs = [
      {
        'title': '1. Início (Painel)',
        'icon': Icons.home_rounded,
        'color': Colors.blueAccent,
        'desc': 'Velocímetro do orçamento em tempo real, alternância rápida entre Meu Carrinho e Família, detecção automática de mercado por GPS (Geofencing) e cards de atalho reordenáveis.',
        'slide': 2,
      },
      {
        'title': '2. Carrinhos (Listas)',
        'icon': Icons.shopping_cart_rounded,
        'color': Colors.teal,
        'desc': 'Crie carrinhos com templates por finalidade (Geral, Churrasco, Atacarejo, Reposição), importe a Nota Fiscal SEFAZ (NFC-e) via QR Code e use o Scanner Direto para Edição.',
        'slide': 3,
      },
      {
        'title': '3. Análises (Estatísticas)',
        'icon': Icons.bar_chart_rounded,
        'color': Colors.purpleAccent,
        'desc': 'Gráficos interativos de gastos vs. economia (3M, 6M, 1 Ano), distribuição por categorias e acesso ao seu Perfil de Comprador.',
        'slide': 5,
      },
      {
        'title': '4. Comunidade (Radar & Mapa)',
        'icon': Icons.radar_rounded,
        'color': Colors.orange,
        'desc': '3 sub-abas (Lista, Comparador e Mercados) com cache SQLite instantâneo, pesquisa por nome/bairro, filtro por redes e Mapa Estilo Google Maps com 3.484 lojas!',
        'slide': 7,
      },
      {
        'title': '5. Ajustes (Conta & Acessibilidade)',
        'icon': Icons.settings_rounded,
        'color': Colors.blueGrey,
        'desc': 'Sincronização Google Sheets, Modo Offline Local, Itens Essenciais, temas, Modo Daltônico, tamanho da fonte e backups criptografados.',
        'slide': 8,
      },
    ];

    final current = tabs[_selectedTabOverviewIdx];
    final currentColor = current['color'] as Color;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              Text(
                'O CARRIN em 5 Abas no Rodapé',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 6),
              Text(
                'Toque nos ícones da barra simulada abaixo para explorar o que cada uma das 5 abas faz:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: textColor.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 16),

              // Barra de navegação simulada e clicável com as 5 abas reais do app
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2235) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(tabs.length, (i) {
                    final t = tabs[i];
                    final isSel = _selectedTabOverviewIdx == i;
                    final col = t['color'] as Color;
                    final shortLabels = ['Início', 'Carrinhos', 'Análises', 'Comunidade', 'Ajustes'];
                    return GestureDetector(
                      onTap: () {
                        _triggerVibration();
                        setState(() => _selectedTabOverviewIdx = i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? col.withValues(alpha: 0.16) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(t['icon'] as IconData, color: isSel ? col : Colors.grey, size: 24),
                            const SizedBox(height: 4),
                            Text(
                              shortLabels[i],
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: isSel ? FontWeight.w900 : FontWeight.w500,
                                color: isSel ? col : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 16),

              // Card de detalhes da aba selecionada
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Container(
                  key: ValueKey('tab_overview_$_selectedTabOverviewIdx'),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: currentColor.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: currentColor.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: currentColor.withValues(alpha: 0.2),
                            child: Icon(current['icon'] as IconData, color: currentColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              current['title'] as String,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: currentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        current['desc'] as String,
                        style: TextStyle(fontSize: 13.5, color: textColor.withValues(alpha: 0.85), height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _triggerVibration();
                            _pageController.animateToPage(
                              current['slide'] as int,
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                            );
                          },
                          icon: Icon(Icons.play_circle_outline_rounded, size: 18, color: currentColor),
                          label: Text(
                            'Testar Simulador desta Aba',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: currentColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SLIDES 3 A 8: CARDS DE DEMONSTRAÇÃO INTERATIVOS DE CADA SEÇÃO
  // ===========================================================================
  Widget _buildSectionInteractiveSlide({
    required TutorialSection section,
    required String headerTitle,
    required String headerSubtitle,
    required Color textColor,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              Text(
                headerTitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                headerSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: textColor.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 12),
              InteractiveSectionTutorialCard(
                section: section,
                isModal: false,
                onPrimaryAction: _nextPage,
                primaryActionLabel: 'Próximo Slide',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SLIDE 9: MAPA INTERATIVO + CALCULADORA DE PESO + AJUSTES
  // ===========================================================================
  Widget _buildSlide9MapAndCalculators(Color textColor, bool isDark, Color primaryColor) {
    final calculatedTotal = (_demoWeightGrams / 1000.0) * _demoPricePerKg;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              Text(
                'Mapa de Mercados, Calculadoras & Ajustes',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                'Toque nos pinos do mini-mapa abaixo para revelar o nome do mercado e experimente a Calculadora de Peso:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: textColor.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 12),

              // Card Interativo do Mapa (Pinos sem texto -> Clique revela nome + filtro de redes)
              const InteractiveSectionTutorialCard(
                section: TutorialSection.marketMap,
                isModal: false,
              ),

              const SizedBox(height: 16),

              // Simulador Interativo da Calculadora de Peso (Kg / Gramas)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D2D) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.teal.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.scale_rounded, color: Colors.teal),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Simulador: Calculadora de Peso & Flutuante',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No rodapé da Lista de Compras, use a Balança (Peso) para hortifruti/açougue ou a Calculadora Flutuante arrastável:',
                      style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Peso na balança: ${_demoWeightGrams.toInt()} g',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        Text(
                          'Preço/Kg: R\$ ${_demoPricePerKg.toStringAsFixed(2).replaceAll('.', ',')}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.teal),
                        ),
                      ],
                    ),
                    Slider(
                      value: _demoWeightGrams,
                      min: 100,
                      max: 2000,
                      divisions: 19,
                      activeColor: Colors.teal,
                      onChanged: (v) => setState(() => _demoWeightGrams = v),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Valor Calculado Automaticamente: R\$ ${calculatedTotal.toStringAsFixed(2).replaceAll('.', ',')}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.teal),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Card Interativo de Ajustes e Acessibilidade
              const InteractiveSectionTutorialCard(
                section: TutorialSection.settings,
                isModal: false,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

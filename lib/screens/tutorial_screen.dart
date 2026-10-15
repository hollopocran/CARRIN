import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../providers/item_provider.dart';
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

class _TutorialScreenState extends State<TutorialScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 9;

  // Slide 6: Scanner Simulation State
  bool _isScanning = false;
  bool _scanSuccess = false;
  late AnimationController _scannerLineController;

  // Slide 7: Batch Edit Simulation State
  bool _isBatchMode = false;
  final List<Map<String, dynamic>> _mockItems = [
    {'id': '1', 'name': 'Arroz Integral 5kg', 'price': 24.90, 'category': 'Mercearia 🌾', 'selected': false, 'bought': false},
    {'id': '2', 'name': 'Leite Integral 1L', 'price': 4.89, 'category': 'Laticínios 🥛', 'selected': false, 'bought': false},
    {'id': '3', 'name': 'Sabão em Pó 1kg', 'price': 15.50, 'category': 'Limpeza 🧼', 'selected': false, 'bought': false},
  ];

  // Slide 8: Budget Simulation State
  double _budgetSpent = 150.0;
  final double _budgetLimit = 400.0;

  // Slide 9: Finalize Simulation State
  bool _mockFinalized = false;

  @override
  void initState() {
    super.initState();
    _scannerLineController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scannerLineController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _numPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishTutorial();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
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

  void _triggerVibration() async {
    try {
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(duration: 80);
      }
    } catch (_) {
      // Fallback silent or system default haptics
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _prevPage,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    )
                  else
                    const SizedBox(width: 48),
                  Text(
                    'PASSO ${_currentPage + 1} DE $_numPages',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: isDarkMode ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  TextButton(
                    onPressed: _finishTutorial,
                    child: Text(
                      widget.showStartButton ? 'Pular' : 'Fechar',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildWelcomeSlide(primaryColor, isDarkMode),
                  _buildAppModeSlide(primaryColor, isDarkMode),
                  _buildActionMapSlide(primaryColor, isDarkMode),
                  _buildCarrinhosMockSlide(primaryColor, isDarkMode),
                  _buildEstatisticasMockSlide(primaryColor, isDarkMode),
                  _buildScannerSlide(primaryColor, isDarkMode),
                  _buildBatchEditSlide(primaryColor, isDarkMode),
                  _buildBudgetSlide(primaryColor, isDarkMode),
                  _buildFinalizarMockSlide(primaryColor, isDarkMode),
                ],
              ),
            ),

            // Bottom Navigation Area
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page Indicators
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_numPages, (index) => _buildPageIndicator(index, primaryColor)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action Button
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: isDarkMode ? Colors.black : Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentPage == _numPages - 1
                          ? (widget.showStartButton ? 'COMEÇAR A USAR' : 'CONCLUIR')
                          : 'AVANÇAR',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
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

  Widget _buildPageIndicator(int index, Color primaryColor) {
    final bool isCurrent = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      height: 8,
      width: isCurrent ? 20 : 8,
      decoration: BoxDecoration(
        color: isCurrent ? primaryColor : primaryColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // Slide 1: Welcome Slide
  Widget _buildWelcomeSlide(Color primaryColor, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_rounded,
              size: 80,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Bem-vindo ao CARRIN',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sua lista de compras, sem complicação.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'O CARRIN foi feito para você planejar, gerenciar e economizar no supermercado, funcionando perfeitamente em segundo plano e se integrando ao Google Sheets.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: isDarkMode ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // Slide 2: Online vs Offline Mode Explainer
  Widget _buildAppModeSlide(Color primaryColor, bool isDarkMode) {
    final itemProvider = Provider.of<ItemProvider>(context);
    final bool isOffline = itemProvider.isActiveUserOffline;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isOffline ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
              size: 70,
              color: isOffline ? Colors.orange : Colors.green,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            isOffline ? 'Você escolheu o Modo Offline' : 'Você escolheu o Modo Online',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Perfil ativo: ${_getCleanDisplayName(itemProvider)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E2030) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOffline ? Colors.orange.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isOffline ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                      color: isOffline ? Colors.orange : Colors.green,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isOffline ? 'O que você NÃO fará:' : 'O que você fará:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isOffline ? Colors.orange : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isOffline) ...[
                  _buildBulletPoint(
                    'Sem Sincronização em Nuvem:',
                    'As listas não serão salvas no Google Drive e não estarão acessíveis em outros aparelhos.',
                    isDarkMode,
                  ),
                  const SizedBox(height: 12),
                  _buildBulletPoint(
                    'Sem Edição via Computador:',
                    'Você não poderá abrir o Google Sheets no PC para adicionar ou remover itens.',
                    isDarkMode,
                  ),
                  const SizedBox(height: 12),
                  _buildBulletPoint(
                    'Segurança Local:',
                    'Se desinstalar o app, seus dados serão apagados. Lembre-se de usar a opção "Exportar Backup" nas Configurações regularmente!',
                    isDarkMode,
                  ),
                ] else ...[
                  _buildBulletPoint(
                    'Sincronização Automática:',
                    'Suas listas são salvas em tempo real em uma planilha do Google Sheets no seu Drive pessoal.',
                    isDarkMode,
                  ),
                  const SizedBox(height: 12),
                  _buildBulletPoint(
                    'Acesso Multiplataforma:',
                    'Você pode gerenciar as compras no celular ou editar a planilha diretamente de qualquer navegador de internet.',
                    isDarkMode,
                  ),
                  _buildBulletPoint(
                    'Backup Eterno:',
                    'Mesmo que mude ou perca o celular, basta logar com sua conta Google para restaurar tudo.',
                    isDarkMode,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String title, String desc, bool isDarkMode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white54 : Colors.black45,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
              children: [
                TextSpan(
                  text: '$title ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Slide 3: Action Map (Where to do what)
  Widget _buildActionMapSlide(Color primaryColor, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Onde Fazer Cada Ação?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'O CARRIN é organizado em 4 abas principais no rodapé. Veja como usá-las:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Menu Map
          Column(
            children: [
              _buildActionMapItem(
                icon: Icons.home_rounded,
                title: 'Início (Dashboard)',
                desc: 'Acompanhe o termômetro de gastos do mês, confira seu saldo e acesse atalhos rápidos.',
                color: Colors.blueAccent,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 12),
              _buildActionMapItem(
                icon: Icons.shopping_cart_rounded,
                title: 'Carrinhos (Listas de Compras) 🌟',
                desc: 'Onde a mágica acontece! Crie novas listas de compras, gerencie produtos e escaneie itens.',
                color: Colors.teal,
                isDarkMode: isDarkMode,
                highlight: true,
              ),
              const SizedBox(height: 12),
              _buildActionMapItem(
                icon: Icons.bar_chart_rounded,
                title: 'Análises (Estatísticas)',
                desc: 'Veja gráficos de comparação mensal e o percentual de gastos por categoria.',
                color: Colors.purpleAccent,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 12),
              _buildActionMapItem(
                icon: Icons.settings_rounded,
                title: 'Ajustes (Configurações)',
                desc: 'Altere temas, gerencie contas, defina o orçamento padrão e exporte/importe backups.',
                color: Colors.blueGrey,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionMapItem({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required bool isDarkMode,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2030) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: highlight
            ? Border.all(color: color.withValues(alpha: 0.6), width: 1.5)
            : Border.all(color: isDarkMode ? Colors.white10 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: highlight ? color : (isDarkMode ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                    if (highlight)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'PRINCIPAL',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                        ),
                      )
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12.5, color: isDarkMode ? Colors.white60 : Colors.black54, height: 1.3),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Slide 4: "Meus Carrinhos" Tab Presentation with Mock Data
  Widget _buildCarrinhosMockSlide(Color primaryColor, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Meus Carrinhos',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Esta aba lista todos os seus carrinhos mensais. Veja o histórico de compras com dados fictícios:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Mock Carrinhos List Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E2030) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDarkMode ? Colors.white10 : Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lista de Meses',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Icon(Icons.history_toggle_off, color: primaryColor, size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Month 1: Active Month (May)
                _buildMockMonthItem(
                  monthName: 'Maio de 2026',
                  spent: 380.00,
                  budget: 400.00,
                  itemsCount: 45,
                  isActive: true,
                  isDarkMode: isDarkMode,
                  accentColor: Colors.orangeAccent,
                ),
                const SizedBox(height: 12),
                
                // Month 2: April
                _buildMockMonthItem(
                  monthName: 'Abril de 2026',
                  spent: 310.00,
                  budget: 350.00,
                  itemsCount: 38,
                  isActive: false,
                  isDarkMode: isDarkMode,
                  accentColor: Colors.teal,
                ),
                const SizedBox(height: 12),
                
                // Month 3: March
                _buildMockMonthItem(
                  monthName: 'Março de 2026',
                  spent: 260.00,
                  budget: 300.00,
                  itemsCount: 30,
                  isActive: false,
                  isDarkMode: isDarkMode,
                  accentColor: Colors.teal,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Helper tip
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Como criar uma nova lista?'),
                  content: const Text('Para criar uma lista real, acesse a aba "Carrinhos" no rodapé do aplicativo após o tutorial, e clique no botão "+" no canto superior direito.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Entendi'),
                    )
                  ],
                ),
              );
            },
            icon: const Icon(Icons.info_outline, size: 16),
            label: const Text('Como criar um novo carrinho?', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildMockMonthItem({
    required String monthName,
    required double spent,
    required double budget,
    required int itemsCount,
    required bool isActive,
    required bool isDarkMode,
    required Color accentColor,
  }) {
    final double percent = spent / budget;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black12 : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5)
            : Border.all(color: Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ATIVO',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'R\$ ${spent.toStringAsFixed(0)} de R\$ ${budget.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              Text(
                '$itemsCount itens',
                style: const TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: isDarkMode ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(percent >= 0.90 ? Colors.redAccent : accentColor),
            ),
          ),
        ],
      ),
    );
  }

  // Slide 5: "Estatísticas" Tab Presentation with Mock Chart Data
  Widget _buildEstatisticasMockSlide(Color primaryColor, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Análises & Gráficos',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Acompanhe seu progresso de gastos de forma 100% automática com estes gráficos fictícios:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Charts Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E2030) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDarkMode ? Colors.white10 : Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics_outlined, color: Colors.purpleAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Evolução de Gastos Mensais',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Custom Paint / Fake Bar Chart
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildMockBar(month: 'MAR', amount: 260.00, height: 60, color: Colors.teal),
                    _buildMockBar(month: 'ABR', amount: 310.00, height: 80, color: Colors.teal),
                    _buildMockBar(month: 'MAI', amount: 380.00, height: 110, color: Colors.purpleAccent),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                
                // Categorias
                const Row(
                  children: [
                    Icon(Icons.pie_chart_outline, color: Colors.teal, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Divisão por Categorias',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMockCategoryRow(name: 'Alimentação 🥩', percent: 0.50, color: Colors.teal, percentText: '50%'),
                const SizedBox(height: 8),
                _buildMockCategoryRow(name: 'Limpeza 🧼', percent: 0.25, color: Colors.blueAccent, percentText: '25%'),
                const SizedBox(height: 8),
                _buildMockCategoryRow(name: 'Hortifrúti 🍎', percent: 0.15, color: Colors.orangeAccent, percentText: '15%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockBar({
    required String month,
    required double amount,
    required double height,
    required Color color,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'R\$ ${amount.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(seconds: 1),
          height: height,
          width: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))
            ]
          ),
        ),
        const SizedBox(height: 8),
        Text(
          month,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildMockCategoryRow({
    required String name,
    required double percent,
    required Color color,
    required String percentText,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          percentText,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ],
    );
  }

  // Slide 6: Barcode Scanner Simulation
  Widget _buildScannerSlide(Color primaryColor, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Scanner Inteligente',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Escaneie o código de barras para preencher nome e preço automaticamente baseados no seu histórico.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 30),

          // Finder simulator
          Container(
            height: 220,
            width: 280,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 3),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Scan guide lines
                Positioned(
                  left: 30,
                  right: 30,
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.qr_code_scanner,
                        size: 44,
                        color: _scanSuccess ? Colors.green : Colors.white38,
                      ),
                    ),
                  ),
                ),
                // Laser line anim
                if (_isScanning && !_scanSuccess)
                  AnimatedBuilder(
                    animation: _scannerLineController,
                    builder: (context, child) {
                      return Positioned(
                        top: 70 + (_scannerLineController.value * 80),
                        left: 40,
                        right: 40,
                        child: Container(
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent,
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                if (_scanSuccess)
                  Positioned(
                    top: 110,
                    left: 40,
                    right: 40,
                    child: Container(
                      height: 3,
                      color: Colors.greenAccent,
                    ),
                  ),
                // Feedback overlay
                if (!_isScanning && !_scanSuccess)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isScanning = true;
                          });
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) {
                              _triggerVibration();
                              setState(() {
                                _isScanning = false;
                                _scanSuccess = true;
                              });
                            }
                          });
                        },
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text('Simular Leitura', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Success Card
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _scanSuccess
                ? Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1E2030) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.green, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Arroz Integral 5kg',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    'Preço sugerido: R\$ 24,90  •  Mercearia 🌾',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _scanSuccess = false;
                            });
                          },
                          child: const Text('Limpar e Testar de Novo'),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(height: 0),
          ),
        ],
      ),
    );
  }

  // Slide 7: Batch Edit Simulation
  Widget _buildBatchEditSlide(Color primaryColor, bool isDarkMode) {
    final int selectedCount = _mockItems.where((i) => i['selected'] == true).length;
    final bool allDone = _mockItems.every((i) => i['bought'] == true);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Edição em Lote',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Segure e pressione um item para entrar no modo de seleção em massa. Perfeito para riscar vários itens de uma vez!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Interactivity Guideline
          if (!_isBatchMode && !allDone)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app, size: 16, color: primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    'Pressione e segure um item abaixo',
                    style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          if (_isBatchMode)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                  SizedBox(width: 6),
                  Text(
                    'Selecione os outros itens tocando neles',
                    style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          if (allDone)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isBatchMode = false;
                  for (var item in _mockItems) {
                    item['selected'] = false;
                    item['bought'] = false;
                  }
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Resetar lista de testes'),
            ),
          const SizedBox(height: 16),

          // List Container
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E2030) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _mockItems.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final item = _mockItems[index];
                final bool isSelected = item['selected'] == true;
                final bool isBought = item['bought'] == true;

                return GestureDetector(
                  onLongPress: () {
                    if (!allDone && !_isBatchMode) {
                      _triggerVibration();
                      setState(() {
                        _isBatchMode = true;
                        item['selected'] = true;
                      });
                    }
                  },
                  onTap: () {
                    if (_isBatchMode && !isBought) {
                      _triggerVibration();
                      setState(() {
                        item['selected'] = !item['selected'];
                        if (_mockItems.where((i) => i['selected'] == true).isEmpty) {
                          _isBatchMode = false;
                        }
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: isSelected 
                        ? primaryColor.withValues(alpha: 0.08) 
                        : Colors.transparent,
                    child: Row(
                      children: [
                        if (_isBatchMode) ...[
                          Checkbox(
                            value: isSelected,
                            onChanged: (bool? val) {
                              _triggerVibration();
                              setState(() {
                                item['selected'] = val ?? false;
                                if (_mockItems.where((i) => i['selected'] == true).isEmpty) {
                                  _isBatchMode = false;
                                }
                              });
                            },
                            activeColor: primaryColor,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: isBought ? TextDecoration.lineThrough : null,
                                  color: isBought ? Colors.grey : null,
                                ),
                              ),
                              Text(
                                '${item['category']}  •  R\$ ${item['price'].toStringAsFixed(2).replaceAll('.', ',')}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        if (isBought)
                          const Icon(Icons.check_circle, color: Colors.green, size: 24)
                        else if (!_isBatchMode)
                          const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Batch Action Panel simulation
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _isBatchMode
                ? Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$selectedCount selecionado(s)',
                          style: TextStyle(
                            color: isDarkMode ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.check_circle_outline, color: isDarkMode ? Colors.black : Colors.white),
                              onPressed: () {
                                _triggerVibration();
                                setState(() {
                                  for (var item in _mockItems) {
                                    if (item['selected'] == true) {
                                      item['bought'] = true;
                                      item['selected'] = false;
                                    }
                                  }
                                  _isBatchMode = false;
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: isDarkMode ? Colors.black : Colors.white),
                              onPressed: () {
                                _triggerVibration();
                                setState(() {
                                  _mockItems.removeWhere((item) => item['selected'] == true);
                                  _isBatchMode = false;
                                });
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                : const SizedBox(height: 0),
          ),
        ],
      ),
    );
  }

  // Slide 8: Budget and Limits Simulation
  Widget _buildBudgetSlide(Color primaryColor, bool isDarkMode) {
    final double percent = (_budgetSpent / _budgetLimit).clamp(0.0, 1.25);
    final bool isLimitAlert = percent >= 0.90;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Orçamento Inteligente',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Defina sua meta mensal de gastos. O CARRIN avisa quando você atingir 90% do valor limite.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),

          // Gauge Simulation
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: percent.clamp(0.0, 1.0),
                  strokeWidth: 14,
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  color: percent >= 0.90 
                      ? Colors.redAccent 
                      : (percent >= 0.70 ? Colors.orangeAccent : Colors.teal),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'R\$ ${_budgetSpent.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Meta: R\$ ${_budgetLimit.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Interactive slider to adjust spent value
          Row(
            children: [
              const Icon(Icons.remove, size: 16),
              Expanded(
                child: Slider(
                  value: _budgetSpent,
                  min: 0.0,
                  max: 500.0,
                  activeColor: isLimitAlert ? Colors.redAccent : primaryColor,
                  onChanged: (double val) {
                    if (val >= 360 && _budgetSpent < 360) {
                      _triggerVibration();
                    }
                    setState(() {
                      _budgetSpent = val;
                    });
                  },
                ),
              ),
              const Icon(Icons.add, size: 16),
            ],
          ),
          Text(
            'Arraste para ajustar o valor gasto',
            style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white38 : Colors.black38),
          ),
          const SizedBox(height: 24),

          // Budget Alert Badge simulation
          AnimatedOpacity(
            opacity: isLimitAlert ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pé no freio!',
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Você atingiu ${(percent * 100).toStringAsFixed(0)}% do seu orçamento planejado.',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Slide 9: Finalize List Simulation
  Widget _buildFinalizarMockSlide(Color primaryColor, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Finalizar Compra',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Após concluir as compras do mês, você pode finalizar a lista. Isso a congela em modo de leitura, evitando edições acidentais.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 28),

          // Interactive Locked Card Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E2030) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _mockFinalized 
                    ? Colors.green.withValues(alpha: 0.3) 
                    : (isDarkMode ? Colors.white10 : Colors.black12),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Carrinho: Maio 2026',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Icon(
                      _mockFinalized ? Icons.lock : Icons.lock_open,
                      color: _mockFinalized ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Status Banner Simulation
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _mockFinalized
                      ? Container(
                          key: const ValueKey('banner_finalized'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline, color: Colors.green, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Compra Finalizada (Modo Leitura)',
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // Simulated Item Tile
                Opacity(
                  opacity: _mockFinalized ? 0.4 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Checkbox(
                          value: true,
                          onChanged: null, // Disabled in both states to simulate checked item
                          activeColor: Colors.green,
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sabão em Pó 1kg',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '1 un x R\$ 15,50',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'R\$ 15,50',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Finalize/Reopen Trigger Button
                ElevatedButton.icon(
                  onPressed: () {
                    _triggerVibration();
                    setState(() {
                      _mockFinalized = !_mockFinalized;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mockFinalized ? Colors.grey[850] : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                  ),
                  icon: Icon(_mockFinalized ? Icons.lock_open : Icons.check_circle_outline),
                  label: Text(
                    _mockFinalized ? 'Reabrir para Edições' : 'Finalizar esta Compra',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Toque no botão para simular a finalização',
            style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  String _getCleanDisplayName(ItemProvider provider) {
    String name = provider.activeUserDisplayName;
    if (name.contains('@')) {
      name = name.split('@').first;
    }
    if (name.toLowerCase() == 'offline' || name.toLowerCase() == 'convidado') {
      return 'Weverton';
    }
    // Capitalize first letter
    if (name.isNotEmpty) {
      return name[0].toUpperCase() + name.substring(1);
    }
    return name;
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dashboard_screen.dart';
import 'month_selection_screen.dart';
import 'statistics_screen.dart';
import 'community_radar_screen.dart';
import 'settings_screen.dart';
import '../services/notification_service.dart';
import '../providers/item_provider.dart';
import '../widgets/interactive_tab_tutorial.dart';
import '../services/app_update_service.dart';
import '../widgets/app_update_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late PageController _pageController;
  Timer? _tutorialSettleTimer;
  int? _programmaticTargetIndex;

  TutorialSection _sectionForTab(int index) {
    switch (index) {
      case 0:
        return TutorialSection.dashboard;
      case 1:
        return TutorialSection.carts;
      case 2:
        return TutorialSection.statistics;
      case 3:
        return TutorialSection.community;
      case 4:
      default:
        return TutorialSection.settings;
    }
  }

  void _scheduleTabTutorial(int index, {Duration delay = const Duration(milliseconds: 240)}) {
    // Mantém o tutorial automático apenas no Início (0) e nas Configurações (4)
    if (index != 0 && index != 4) return;
    _tutorialSettleTimer?.cancel();
    _tutorialSettleTimer = Timer(delay, () {
      if (!mounted || _currentIndex != index) return;
      if (_programmaticTargetIndex != null && _programmaticTargetIndex != index) return;
      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      InteractiveTabTutorial.checkAndShowIfFirstTime(
        context,
        _sectionForTab(index),
        userEmail: itemProvider.activeUserEmail,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      // Detecção silenciosa e invisível em segundo plano logo na inicialização
      itemProvider.detectNearbySupermarket(
        notify: false,
      );
      _scheduleTabTutorial(_currentIndex, delay: const Duration(milliseconds: 220));

      // Checagem automática e não-intrusiva de nova versão lançada
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        AppUpdateService.instance.checkForUpdate().then((info) {
          if (info != null && mounted) {
            AppUpdateDialog.show(context, info);
          }
        });
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reavalia o GPS silenciosamente sempre que o usuário reabrir o app
      Provider.of<ItemProvider>(context, listen: false).detectNearbySupermarket(
        notify: false,
      );
    }
  }

  @override
  void dispose() {
    _tutorialSettleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  void switchTab(int index) {
    if (mounted) {
      _onItemTapped(index);
    }
  }

  void _onPageChanged(int index) {
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);
    itemProvider.setInteractingWithChart(false);
    setState(() {
      _currentIndex = index;
    });
    if (_programmaticTargetIndex != null && _programmaticTargetIndex != index) {
      return;
    }
    _scheduleTabTutorial(index, delay: const Duration(milliseconds: 240));
  }

  Future<void> _onItemTapped(int index) async {
    if (index == _currentIndex) return;
    _tutorialSettleTimer?.cancel();
    _programmaticTargetIndex = index;
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    _programmaticTargetIndex = null;
    _scheduleTabTutorial(index, delay: const Duration(milliseconds: 80));
  }

  @override
  Widget build(BuildContext context) {
    final itemProvider = Provider.of<ItemProvider>(context);
    final isChartInteracting = itemProvider.isInteractingWithChart;

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          NotificationService().cancelAll();
          return;
        }
        _onItemTapped(0);
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: isChartInteracting
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          children: const [
            DashboardScreen(),
            MonthSelectionScreen(),
            StatisticsScreen(),
            CommunityRadarScreen(),
            SettingsScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Theme.of(context).cardColor,
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey : Colors.grey.shade600,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Início',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shopping_cart_outlined),
                activeIcon: Icon(Icons.shopping_cart),
                label: 'Carrinhos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: 'Análises',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.radar_outlined),
                activeIcon: Icon(Icons.radar_rounded),
                label: 'Comunidade',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Ajustes',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

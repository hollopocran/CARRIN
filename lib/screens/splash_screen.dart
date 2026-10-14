import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';
import 'tutorial_screen.dart';
import 'terms_screen.dart';
import '../theme/app_themes.dart';
import '../services/auth_service.dart';
import '../providers/item_provider.dart';
import '../widgets/supermarket_avatar.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _showLogin = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _controller.forward();

    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Wait for animation
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final authService = context.read<AuthService>();
    final prefs = await SharedPreferences.getInstance();
    final activeEmail = prefs.getString('active_user_email');

    if (authService.isSignedIn || (activeEmail != null && activeEmail.isNotEmpty)) {
      _checkTutorialAndNavigate(activeEmail ?? authService.currentUser?.email ?? 'guest');
    } else {
      setState(() {
        _showLogin = true;
      });
    }
  }

  Future<void> _checkTutorialAndNavigate(String email) async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email.replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final hasSeenTutorial = prefs.getBool('has_seen_tutorial_$cleanEmail') ?? false;

    if (!mounted) return;

    if (hasSeenTutorial) {
      _navigateToMain();
    } else {
      _navigateToTutorial();
    }
  }

  void _navigateToTutorial() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const TutorialScreen(showStartButton: true),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _navigateToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    final authService = context.read<AuthService>();
    final success = await authService.signIn();
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        final email = authService.currentUser?.email ?? 'guest';
        final itemProvider = context.read<ItemProvider>();
        await itemProvider.switchActiveUserEmail(email);
        _checkTutorialAndNavigate(email);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao entrar com Google')),
        );
      }
    }
  }

  void _showOfflineProfileSetupDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    String selectedAvatarId = 'supermarket_cart_ocean';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, anim1, anim2) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Configurar Perfil Offline', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Perfil',
                    hintText: 'Weverton',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),
                SupermarketAvatarSelector(
                  selectedId: selectedAvatarId,
                  onSelected: (avatarId) {
                    selectedAvatarId = avatarId;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim().isEmpty 
                    ? 'Weverton' 
                    : nameController.text.trim();
                
                Navigator.pop(dialogContext); // Close dialog
                
                setState(() => _isLoading = true);
                try {
                  final itemProvider = context.read<ItemProvider>();
                  await itemProvider.enableOfflineMode(
                    displayName: name,
                    photoUrl: selectedAvatarId,
                  );
                  final email = itemProvider.activeUserEmail ?? 'offline_guest';
                  _checkTutorialAndNavigate(email);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao entrar em modo offline: $e')),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              },
              child: const Text('Entrar'),
            ),
          ],
        );
      },
      transitionBuilder: (dialogContext, anim1, anim2, child) {
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: curve,
          child: child,
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: Stack(
        children: [
          // Logo centralizado com animação
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 200,
                      height: 200,
                      alignment: Alignment.center,
                      child: Image.asset(
                        themeProvider.appIcon,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.shopping_cart, size: 100, color: Colors.blueAccent),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Nome do App e slogan (Microheadline)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'CARRIN',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFF1A1C2C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sua lista, sem complicação.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 40),
                if (_showLogin)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: _isLoading 
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _handleSignIn,
                              icon: const Icon(Icons.login),
                              label: const Text('Entrar com Google'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _showOfflineProfileSetupDialog(context),
                              icon: const Icon(Icons.cloud_off, size: 18),
                              label: const Text('Usar sem conta (Offline)'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                side: BorderSide(
                                  color: isDarkMode ? Colors.white30 : Colors.black26,
                                ),
                                foregroundColor: isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const TermsScreen()),
                                );
                              },
                              child: Text(
                                'Ao entrar, você concorda com os Termos & Privacidade',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDarkMode ? Colors.white38 : Colors.black38,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                  )
                else
                  SizedBox(
                    width: 40,
                    height: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        backgroundColor: const Color(0xFF1A1C2C).withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A1C2C)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

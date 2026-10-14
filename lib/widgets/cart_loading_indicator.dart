import 'package:flutter/material.dart';

class CartLoadingIndicator extends StatefulWidget {
  final String message;
  const CartLoadingIndicator({super.key, this.message = 'Carregando...'});

  @override
  State<CartLoadingIndicator> createState() => _CartLoadingIndicatorState();
}

class _CartLoadingIndicatorState extends State<CartLoadingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _cartAnimation;
  late Animation<double> _trailAnimation;
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Inicia o fade-in suave após um pequeno frame
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _opacity = 1.0);
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Mais rápido para ser mais fluido
    )..repeat();

    _cartAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 15.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 15.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
    ]).animate(_controller);

    _trailAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear)
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: _opacity,
      curve: Curves.easeIn,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return SizedBox(
                  width: 120,
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Rastros do Carrinho (Sincronizados com o movimento horizontal)
                      ...List.generate(6, (index) {
                        double moveProgress = _trailAnimation.value;
                        double individualOffset = (index * 12.0) + (moveProgress * 60.0);
                        if (individualOffset > 70) individualOffset -= 70;
                        
                        double opacity = (1.0 - (individualOffset / 70)).clamp(0.0, 0.6);
                        
                        double vPos = (index % 2 == 0) ? -8.0 : 8.0;
                        if (index == 5) vPos = -14.0;
                        if (index == 0) vPos = 14.0;

                        // Sincroniza o rastro com a posição ATUAL do carrinho (_cartAnimation.value)
                        return Positioned(
                          right: 55 + individualOffset - _cartAnimation.value, 
                          top: 30 + vPos,
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              width: (index % 2 == 0) ? 14.0 : 8.0,
                              height: 1.8,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        );
                      }),
                      
                      // Carrinho de Compras
                      Transform.translate(
                        offset: Offset(_cartAnimation.value, 0),
                        child: const Icon(
                          Icons.shopping_cart,
                          size: 42,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              widget.message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

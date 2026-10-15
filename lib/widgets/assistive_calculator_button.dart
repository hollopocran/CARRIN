import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'floating_calculator_popup.dart';

/// Um botão flutuante arrastável estilo AssistiveTouch (iOS) para acesso rápido à calculadora.
/// 
/// Ao ser solto pelo usuário, ele se ancora suavemente na borda esquerda ou direita
/// da tela para nunca obstruir o conteúdo central da lista de compras.
class AssistiveCalculatorButton extends StatefulWidget {
  final VoidCallback? onTap;

  const AssistiveCalculatorButton({super.key, this.onTap});

  @override
  State<AssistiveCalculatorButton> createState() => _AssistiveCalculatorButtonState();
}

class _AssistiveCalculatorButtonState extends State<AssistiveCalculatorButton> with SingleTickerProviderStateMixin {
  static const double _buttonSize = 52.0;
  static const double _margin = 14.0;

  Offset? _position;
  late AnimationController _snapAnimController;
  Animation<Offset>? _snapAnimation;
  bool _isInteracting = false;
  Offset _dragStartGlobal = Offset.zero;
  bool _movedSignificantly = false;

  @override
  void initState() {
    super.initState();
    _snapAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        if (_snapAnimation != null) {
          setState(() {
            _position = _snapAnimation!.value;
          });
        }
      });
  }

  @override
  void dispose() {
    _snapAnimController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      FloatingCalculatorPopup.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;
    final double maxWidth = screenSize.width;
    final double maxHeight = screenSize.height;
    final double topSafe = mediaQuery.padding.top;
    final double bottomSafe = mediaQuery.padding.bottom;

    // Limites de movimentação livres em quase toda a tela
    final double bottomLimit = maxHeight - bottomSafe;
    final double topLimit = topSafe + 10.0;

    // Posição padrão inicial: canto inferior direito, repousando acima do footer bar
    _position ??= Offset(
      maxWidth - _buttonSize - _margin,
      maxHeight - bottomSafe - 135.0,
    );

    final double currentX = _position!.dx.clamp(0.0, math.max(0.0, maxWidth - _buttonSize));
    final double currentY = _position!.dy.clamp(topLimit, math.max(topLimit, bottomLimit - _buttonSize));

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      left: currentX,
      top: currentY,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          _snapAnimController.stop();
          _dragStartGlobal = details.globalPosition;
          _movedSignificantly = false;
          setState(() {
            _isInteracting = true;
          });
        },
        onPanUpdate: (details) {
          if ((details.globalPosition - _dragStartGlobal).distance > 7.0) {
            _movedSignificantly = true;
          }
          setState(() {
            _position = Offset(
              _position!.dx + details.delta.dx,
              _position!.dy + details.delta.dy,
            );
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isInteracting = false;
          });

          if (!_movedSignificantly) {
            _handleTap();
            return;
          }

          final velocity = details.velocity.pixelsPerSecond;
          final double vx = velocity.dx;
          final double vy = velocity.dy;

          // Física de arremesso (fling / toss) calibrada:
          // Limiar aumentado para 550 px/s para exigir intenção real de arremesso
          final double targetX;
          if (vx.abs() > 550) {
            targetX = vx > 0 ? (maxWidth - _buttonSize - _margin) : _margin;
          } else {
            final double centerX = _position!.dx + (_buttonSize / 2);
            targetX = (centerX < maxWidth / 2) ? _margin : (maxWidth - _buttonSize - _margin);
          }

          // Inércia vertical suave e amortecida (fator 0.07, limitada a ±100px)
          final double rawInertiaY = vy * 0.07;
          final double clampedInertiaY = rawInertiaY.clamp(-100.0, 100.0);
          final double targetY = (_position!.dy + clampedInertiaY)
              .clamp(topLimit, math.max(topLimit, bottomLimit - _buttonSize));

          final Offset startOffset = _position!;
          final Offset endOffset = Offset(targetX, targetY);

          // Duração calibrada para uma desaceleração macia e natural (280ms a 420ms)
          final double distance = (endOffset - startOffset).distance;
          final double speed = velocity.distance;
          int durationMs = 340;
          if (speed > 550) {
            durationMs = (distance / speed * 1000).clamp(280, 420).toInt();
          } else {
            durationMs = (distance * 0.7).clamp(300, 420).toInt();
          }

          _snapAnimController.duration = Duration(milliseconds: durationMs);
          _snapAnimation = Tween<Offset>(
            begin: startOffset,
            end: endOffset,
          ).animate(CurvedAnimation(
            parent: _snapAnimController, 
            curve: Curves.easeOutCubic,
          ));

          _snapAnimController.forward(from: 0.0);
        },
        onTap: _handleTap,
        child: AnimatedScale(
          scale: _isInteracting ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedOpacity(
            opacity: _isInteracting ? 1.0 : 0.90,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: _buttonSize,
              height: _buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Estilo frosted glass escuro com borda translúcida
                color: isDark ? const Color(0xE61E2235) : const Color(0xEE2A2D40),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.32),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Anel interno característico do AssistiveTouch
                  Container(
                    width: _buttonSize - 14,
                    height: _buttonSize - 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                        width: 1.5,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calculate_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

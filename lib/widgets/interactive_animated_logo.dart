import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Um widget de logo animado, cinematográfico e altamente interativo para o CARRIN.
///
/// Apresenta:
/// - Brilho pulsante em aura de luz neon (verde esmeralda e azul royal).
/// - Flutuação contínua suave (levitação tipo onda senoidal).
/// - Varredura de brilho especular (shimmer / glossy light-sweep) que atravessa o logo como uma vinheta de vídeo.
/// - Interatividade por toque: compressão elástica (squash & stretch), salto para cima, rotação 3D por arrasto e explosão de partículas/moedas.
/// - Toque duplo para giro completo 360° com efeito turbo.
class InteractiveAnimatedLogo extends StatefulWidget {
  final String imagePath;
  final double size;
  final VoidCallback? onTap;
  final bool enableInteraction;
  final bool autoPlayIntro;

  const InteractiveAnimatedLogo({
    super.key,
    this.imagePath = '1-removebg-preview.png',
    this.size = 200,
    this.onTap,
    this.enableInteraction = true,
    this.autoPlayIntro = true,
  });

  @override
  State<InteractiveAnimatedLogo> createState() => _InteractiveAnimatedLogoState();
}

class _InteractiveAnimatedLogoState extends State<InteractiveAnimatedLogo>
    with TickerProviderStateMixin {
  // Controlador de animações contínuas de fundo (levitação, pulso, brilho, aura)
  late AnimationController _ambientController;

  // Controlador de reação elástica ao toque (squash & stretch, pulo)
  late AnimationController _tapController;
  late Animation<double> _squashAnimation;
  late Animation<double> _jumpAnimation;

  // Controlador de giro 360° (turbo spin no toque duplo ou tap rápido)
  late AnimationController _spinController;

  // Efeito 3D Parallax de inclinação por arrasto
  Offset _tiltOffset = Offset.zero;
  Offset _tiltTarget = Offset.zero;

  // Lista de partículas ativas que explodem ao tocar
  final List<_LogoParticle> _particles = [];
  final math.Random _random = math.Random();

  // Contador de toques rápidos para ativar efeito especial
  int _rapidTapCount = 0;
  DateTime _lastTapTime = DateTime.now();

  @override
  void initState() {
    super.initState();

    // 1. Loop contínuo de ambiente e varredura de luz (2.2 segundos por ciclo)
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // 2. Animação de impacto elástico e salto
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _squashAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.82).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.18).chain(CurveTween(curve: Curves.easeOutBack)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 0.95).chain(CurveTween(curve: Curves.easeInOut)), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 20),
    ]).animate(_tapController);

    _jumpAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 6.0).chain(CurveTween(curve: Curves.easeOut)), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -28.0).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: -28.0, end: 0.0).chain(CurveTween(curve: Curves.bounceOut)), weight: 45),
    ]).animate(_tapController);

    // 3. Giro 360° suave
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Ouvinte para atualizar física de partículas e relaxamento de inclinação
    _ambientController.addListener(_updatePhysics);

    // Disparo autônomo da animação (abre rápido e sem precisar de toques)
    if (widget.autoPlayIntro) {
      Future.delayed(const Duration(milliseconds: 280), () {
        if (!mounted) return;
        _triggerAutoIntroSequence();
      });
    }
  }

  void _triggerAutoIntroSequence() {
    if (!mounted) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    _tapController.forward(from: 0.0);
    _spawnBurstParticles(
      Offset(widget.size / 2, widget.size / 2),
      count: 18,
      turbo: true,
    );
  }

  void _updatePhysics() {
    if (_particles.isNotEmpty) {
      setState(() {
        for (int i = _particles.length - 1; i >= 0; i--) {
          final p = _particles[i];
          p.position += p.velocity;
          p.velocity = Offset(p.velocity.dx * 0.96, (p.velocity.dy + 0.3) * 0.97); // gravidade + atrito
          p.rotation += p.rotationSpeed;
          p.life -= 0.025;
          if (p.life <= 0) {
            _particles.removeAt(i);
          }
        }
      });
    }

    // Retorna a inclinação suavemente ao centro quando solto
    if (_tiltTarget == Offset.zero && _tiltOffset != Offset.zero) {
      setState(() {
        _tiltOffset = Offset.lerp(_tiltOffset, Offset.zero, 0.1) ?? Offset.zero;
        if (_tiltOffset.distance < 0.005) _tiltOffset = Offset.zero;
      });
    }
  }

  void _spawnBurstParticles(Offset origin, {int count = 14, bool turbo = false}) {
    final colors = [
      const Color(0xFF10B981), // Verde Esmeralda do Ícone
      const Color(0xFF0179F3), // Azul Royal do Ícone
      const Color(0xFF34D399), // Verde Claro
      const Color(0xFF38BDF8), // Azul Céu
      const Color(0xFFFBBF24), // Dourado Moeda
      Colors.white,
    ];

    final emojis = turbo ? ['🪙', '✨', '⚡', '🛒', '🌟'] : ['🪙', '✨', '🟢', '🔵', '⭐'];

    for (int i = 0; i < count; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = _random.nextDouble() * (turbo ? 8.0 : 5.0) + 2.5;
      final velocity = Offset(math.cos(angle) * speed, math.sin(angle) * speed - (turbo ? 3.0 : 1.5));
      final color = colors[_random.nextInt(colors.length)];
      final emoji = (_random.nextDouble() < (turbo ? 0.6 : 0.35))
          ? emojis[_random.nextInt(emojis.length)]
          : null;

      _particles.add(
        _LogoParticle(
          position: origin,
          velocity: velocity,
          color: color,
          size: _random.nextDouble() * 8 + 6,
          rotation: _random.nextDouble() * math.pi * 2,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.3,
          life: 1.0,
          emoji: emoji,
        ),
      );
    }
  }

  void _handleTap() {
    if (!widget.enableInteraction) return;

    HapticFeedback.mediumImpact();

    final now = DateTime.now();
    if (now.difference(_lastTapTime).inMilliseconds < 500) {
      _rapidTapCount++;
    } else {
      _rapidTapCount = 1;
    }
    _lastTapTime = now;

    // Se usuário der múltiplos toques rápidos, ativa giro 360° turbo!
    final bool isTurbo = _rapidTapCount >= 3;
    if (isTurbo) {
      HapticFeedback.heavyImpact();
      _spinController.forward(from: 0.0);
      _rapidTapCount = 0;
    }

    _tapController.forward(from: 0.0);
    _spawnBurstParticles(
      Offset(widget.size / 2, widget.size / 2),
      count: isTurbo ? 26 : 14,
      turbo: isTurbo,
    );

    widget.onTap?.call();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!widget.enableInteraction) return;
    setState(() {
      final double dx = (details.localPosition.dx - widget.size / 2) / (widget.size / 2);
      final double dy = (details.localPosition.dy - widget.size / 2) / (widget.size / 2);
      _tiltTarget = Offset(dx.clamp(-1.0, 1.0), dy.clamp(-1.0, 1.0));
      _tiltOffset = Offset.lerp(_tiltOffset, _tiltTarget, 0.35)!;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!widget.enableInteraction) return;
    setState(() {
      _tiltTarget = Offset.zero;
    });
  }

  @override
  void dispose() {
    _ambientController.removeListener(_updatePhysics);
    _ambientController.dispose();
    _tapController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onDoubleTap: () {
        HapticFeedback.heavyImpact();
        _spinController.forward(from: 0.0);
        _spawnBurstParticles(
          Offset(widget.size / 2, widget.size / 2),
          count: 24,
          turbo: true,
        );
      },
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _ambientController,
          _tapController,
          _spinController,
        ]),
        builder: (context, _) {
          final t = _ambientController.value;

          // Levitação vertical suave (onda senoidal contínua)
          final double hoverDy = math.sin(t * 2 * math.pi) * 8.0;

          // Efeito de pulso de escala suave
          final double ambientScale = 1.0 + math.sin(t * 2 * math.pi) * 0.03;

          // Squash & stretch do toque
          final double tapScaleY = _squashAnimation.value;
          final double tapScaleX = 2.0 - tapScaleY; // compensação proporcional de volume
          final double jumpDy = _jumpAnimation.value;

          // Giro de 360°
          final double spinAngle = _spinController.value * 2 * math.pi;

          // Parallax 3D
          final double rotY = _tiltOffset.dx * 0.35;
          final double rotX = -_tiltOffset.dy * 0.35;

          return SizedBox(
            width: widget.size * 1.5,
            height: widget.size * 1.5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Aura de neon pulsante e anéis de radar no fundo
                CustomPaint(
                  size: Size(widget.size * 1.4, widget.size * 1.4),
                  painter: _AuraPainter(
                    progress: t,
                    isDark: Theme.of(context).brightness == Brightness.dark,
                  ),
                ),

                // 2. Partículas físicas ativas desenhadas no canvas
                if (_particles.isNotEmpty)
                  CustomPaint(
                    size: Size(widget.size * 1.5, widget.size * 1.5),
                    painter: _ParticlesPainter(particles: _particles),
                  ),

                // 3. Logo com transformação 3D, flutuação e brilho (Shimmer)
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0018) // perspectiva 3D
                    ..rotateX(rotX)
                    ..rotateY(rotY + spinAngle)
                    ..setTranslationRaw(0.0, hoverDy + jumpDy, 0.0),
                  child: Transform.scale(
                    scaleX: ambientScale * tapScaleX,
                    scaleY: ambientScale * tapScaleY,
                    child: SizedBox(
                      width: widget.size,
                      height: widget.size,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // A imagem da logo com sombra suave projetada
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.28),
                                  blurRadius: 36,
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF0179F3).withValues(alpha: 0.25),
                                  blurRadius: 48,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              widget.imagePath,
                              width: widget.size,
                              height: widget.size,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.shopping_cart_rounded,
                                size: widget.size * 0.65,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),

                          // Efeito Shimmer cinematográfico (feixe de luz diagonal que varre a logo)
                          ShaderMask(
                            blendMode: BlendMode.srcATop,
                            shaderCallback: (bounds) {
                              final double sweep = (t * 2.5) % 3.0 - 0.5; // varre a cada ciclo
                              return LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                stops: [
                                  (sweep - 0.25).clamp(0.0, 1.0),
                                  sweep.clamp(0.0, 1.0),
                                  (sweep + 0.25).clamp(0.0, 1.0),
                                ],
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.45),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ).createShader(bounds);
                            },
                            child: Image.asset(
                              widget.imagePath,
                              width: widget.size,
                              height: widget.size,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
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
        },
      ),
    );
  }
}

/// Modelo de partícula física para explosões ao toque
class _LogoParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double rotation;
  double rotationSpeed;
  double life; // de 1.0 a 0.0
  String? emoji;

  _LogoParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.life,
    this.emoji,
  });
}

/// Pintor customizado para renderizar as partículas físicas de alta performance
class _ParticlesPainter extends CustomPainter {
  final List<_LogoParticle> particles;

  _ParticlesPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.life <= 0) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: p.life.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      if (p.emoji != null) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: p.emoji,
            style: TextStyle(
              fontSize: p.size * 1.6 * p.life,
              color: Colors.white.withValues(alpha: p.life),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        canvas.save();
        canvas.translate(p.position.dx, p.position.dy);
        canvas.rotate(p.rotation);
        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );
        canvas.restore();
      } else {
        // Círculo com rastro brilhante
        canvas.drawCircle(p.position, p.size * p.life, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) => true;
}

/// Pintor da aura de neon e anéis de energia concêntricos
class _AuraPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _AuraPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.45;

    // 1. Gradiente radial de aura brilhante
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.16),
          const Color(0xFF0179F3).withValues(alpha: isDark ? 0.15 : 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius * 1.1));

    canvas.drawCircle(center, maxRadius * 1.1, auraPaint);

    // 2. Anéis concêntricos que expandem e desaparecem (efeito radar / pulso de vídeo)
    for (int i = 0; i < 2; i++) {
      final ringProgress = (progress + (i * 0.5)) % 1.0;
      final ringRadius = maxRadius * (0.6 + (ringProgress * 0.45));
      final ringAlpha = (1.0 - ringProgress).clamp(0.0, 1.0) * (isDark ? 0.35 : 0.20);

      final ringPaint = Paint()
        ..color = (i == 0 ? const Color(0xFF10B981) : const Color(0xFF0179F3))
            .withValues(alpha: ringAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1.0 - ringProgress);

      canvas.drawCircle(center, ringRadius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuraPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}

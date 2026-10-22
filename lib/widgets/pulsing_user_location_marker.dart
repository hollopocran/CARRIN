import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Marcador animado estilo radar/pulso para a localização do usuário em tempo real no mapa
class PulsingUserLocationMarker extends StatefulWidget {
  final double? heading;
  final bool isFollowing;

  const PulsingUserLocationMarker({
    super.key,
    this.heading,
    this.isFollowing = false,
  });

  @override
  State<PulsingUserLocationMarker> createState() => _PulsingUserLocationMarkerState();
}

class _PulsingUserLocationMarkerState extends State<PulsingUserLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );
    _pulseOpacity = Tween<double>(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final currentScale = _pulseScale.value;
        final currentOpacity = _pulseOpacity.value;
        final pulseDiameter = 22.0 + (currentScale * 46.0); // 22 -> 68

        return SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Onda de pulso azul tipo radar
              Container(
                width: pulseDiameter,
                height: pulseDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withValues(alpha: currentOpacity),
                  border: Border.all(
                    color: Colors.blue.shade400.withValues(alpha: currentOpacity * 1.6),
                    width: 1.5,
                  ),
                ),
              ),

              // Feixe de direção (cone de visualização se heading estiver presente)
              if (widget.heading != null && widget.heading! > 0)
                Transform.rotate(
                  angle: (widget.heading! * math.pi / 180.0),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.blue.withValues(alpha: 0.35),
                          Colors.blue.withValues(alpha: 0.0),
                        ],
                        radius: 0.8,
                      ),
                    ),
                  ),
                ),

              // Anel de precisão intermediário
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withValues(alpha: 0.20),
                ),
              ),

              // Ponto central de alta precisão
              Transform.rotate(
                angle: (widget.heading != null && widget.heading! > 0)
                    ? (widget.heading! * math.pi / 180.0)
                    : 0.0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isFollowing ? const Color(0xFF007AFF) : Colors.blue.shade700,
                    border: Border.all(color: Colors.white, width: 2.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: (widget.heading != null && widget.heading! > 0)
                        ? const Icon(
                            Icons.navigation_rounded,
                            size: 11,
                            color: Colors.white,
                          )
                        : Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

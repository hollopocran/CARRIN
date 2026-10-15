import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../services/utils.dart';

/// Overlay de proteção de tela para o Modo Mercado.
/// 
/// Quando ativado após 15 segundos de inatividade, cobre a tela com uma camada
/// escura econômica (OLED) que bloqueia 100% dos toques involuntários no bolso
/// ou no carrinho de compras, exibindo o resumo do carrinho e exigindo segurar
/// o botão central por 1 segundo para desbloquear.
class MarketLockOverlay extends StatefulWidget {
  final VoidCallback onUnlock;
  final double totalCost;
  final int boughtItemsCount;
  final int totalItemsCount;
  final double budget;

  const MarketLockOverlay({
    super.key,
    required this.onUnlock,
    required this.totalCost,
    required this.boughtItemsCount,
    required this.totalItemsCount,
    this.budget = 0.0,
  });

  @override
  State<MarketLockOverlay> createState() => _MarketLockOverlayState();
}

class _MarketLockOverlayState extends State<MarketLockOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _holdController;
  bool _isHolding = false;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _holdController.addListener(() {
      setState(() {});
      if (_holdController.value >= 1.0 && !_unlocked) {
        _unlocked = true;
        _triggerUnlock();
      }
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  void _triggerUnlock() {
    try {
      Vibration.vibrate(duration: 60);
    } catch (_) {
      HapticFeedback.heavyImpact();
    }

    if (mounted) {
      widget.onUnlock();
    }
  }

  void _onHoldStart() {
    if (_unlocked) return;
    setState(() {
      _isHolding = true;
    });
    HapticFeedback.selectionClick();
    _holdController.forward(from: 0.0);
  }

  void _onHoldEnd() {
    if (_unlocked) return;
    setState(() {
      _isHolding = false;
    });
    if (_holdController.status != AnimationStatus.completed) {
      _holdController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _holdController.value;
    final double percent = widget.totalItemsCount > 0 
        ? (widget.boughtItemsCount / widget.totalItemsCount).clamp(0.0, 1.0) 
        : 0.0;

    return PopScope(
      canPop: false, // Bloqueia o botão voltar do Android enquanto a tela estiver travada
      child: Material(
        color: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            // Fundo preto profundo econômico para telas OLED/AMOLED
            color: const Color(0xF2090B10),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Bar: Indicador de Modo Mercado Centralizado
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.35), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_rounded, color: Colors.amber, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Modo Mercado Ativo',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Centro: Botão de Segurar para Desbloquear com Ring de Progresso
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (_) => _onHoldStart(),
                          onPointerUp: (_) => _onHoldEnd(),
                          onPointerCancel: (_) => _onHoldEnd(),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Anel circular de progresso (1 segundo)
                              SizedBox(
                                width: 104,
                                height: 104,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 4.5,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              // Botão central do cadeado
                              AnimatedScale(
                                scale: _isHolding ? 1.08 : 1.0,
                                duration: const Duration(milliseconds: 140),
                                child: Container(
                                  width: 82,
                                  height: 82,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isHolding ? const Color(0xFF28251D) : const Color(0xFF161A24),
                                    border: Border.all(
                                      color: _isHolding ? Colors.amber : Colors.white.withValues(alpha: 0.22),
                                      width: 2.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _isHolding 
                                            ? Colors.amber.withValues(alpha: 0.35) 
                                            : Colors.black.withValues(alpha: 0.4),
                                        blurRadius: _isHolding ? 18 : 8,
                                        spreadRadius: _isHolding ? 2 : 0,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isHolding ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                                    size: 38,
                                    color: _isHolding ? Colors.amber : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _isHolding ? 'Segure até completar o círculo...' : 'Segure para desbloquear',
                          style: TextStyle(
                            color: _isHolding ? Colors.amber : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Protegido contra toques no bolso ou carrinho',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    // Rodapé: Resumo do Carrinho de Compras
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TOTAL COMPRADO',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    Utils.formatCurrency(widget.totalCost),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'ITENS NO CARRINHO',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${widget.boughtItemsCount} de ${widget.totalItemsCount}',
                                    style: const TextStyle(
                                      color: Color(0xFF4ADE80),
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Barra de progresso dos itens
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 6,
                              backgroundColor: Colors.white.withValues(alpha: 0.10),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

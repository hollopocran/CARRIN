import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CountingText extends StatefulWidget {
  final double value;
  final TextStyle style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final bool isInteger;

  const CountingText({
    super.key,
    required this.value,
    required this.style,
    this.prefix = 'R\$ ',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 600), // Aumentado de 300ms para 600ms
    this.isInteger = false,
  });

  @override
  State<CountingText> createState() => _CountingTextState();
}

class _CountingTextState extends State<CountingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final NumberFormat _fmtCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: '');
  final NumberFormat _fmtInt = NumberFormat.decimalPattern('pt_BR');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    // Inicia IMEDIATAMENTE no próximo frame disponível
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(CountingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final double currentVal = _animation.value;
      _controller.stop();
      _animation = Tween<double>(begin: currentVal, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        String formatted;
        if (widget.isInteger) {
          formatted = _fmtInt.format(_animation.value.round());
        } else {
          formatted = _fmtCurrency.format(_animation.value).trim();
        }
        return Text(
          '${widget.prefix}$formatted${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

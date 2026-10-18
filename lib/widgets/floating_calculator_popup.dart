import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/utils.dart';

/// Interactive floating popup calculator for shopping math and price comparisons.
class FloatingCalculatorPopup extends StatefulWidget {
  final Function(double value)? onUseValue;

  const FloatingCalculatorPopup({super.key, this.onUseValue});

  /// Static helper to display the floating calculator modal dialog.
  static Future<void> show(BuildContext context, {Function(double value)? onUseValue}) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Calculadora',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => FloatingCalculatorPopup(onUseValue: onUseValue),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: curve,
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<FloatingCalculatorPopup> createState() => _FloatingCalculatorPopupState();
}

class _FloatingCalculatorPopupState extends State<FloatingCalculatorPopup> {
  String _expression = '';
  String _displayValue = '0';
  double? _firstOperand;
  String? _operator;
  bool _resetDisplayOnNextInput = false;

  void _onDigitPress(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_resetDisplayOnNextInput || _displayValue == '0') {
        _displayValue = digit;
        _resetDisplayOnNextInput = false;
      } else {
        if (_displayValue.length < 12) {
          _displayValue += digit;
        }
      }
    });
  }

  void _onDecimalPress() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_resetDisplayOnNextInput) {
        _displayValue = '0,';
        _resetDisplayOnNextInput = false;
      } else if (!_displayValue.contains(',')) {
        _displayValue += ',';
      }
    });
  }

  void _onOperatorPress(String op) {
    HapticFeedback.mediumImpact();
    final currentVal = _parseDisplayNumber(_displayValue);
    setState(() {
      if (_firstOperand != null && _operator != null && !_resetDisplayOnNextInput) {
        _calculateIntermediate();
      } else {
        _firstOperand = currentVal;
      }
      _operator = op;
      _expression = '${Utils.formatNumber(_firstOperand!)} $op';
      _resetDisplayOnNextInput = true;
    });
  }

  void _calculateIntermediate() {
    if (_firstOperand == null || _operator == null) return;
    final secondOperand = _parseDisplayNumber(_displayValue);
    double result = 0.0;
    switch (_operator) {
      case '+':
        result = _firstOperand! + secondOperand;
        break;
      case '-':
        result = _firstOperand! - secondOperand;
        break;
      case '×':
        result = _firstOperand! * secondOperand;
        break;
      case '÷':
        result = secondOperand != 0 ? _firstOperand! / secondOperand : 0.0;
        break;
    }
    _firstOperand = result;
    _displayValue = Utils.formatNumber(result);
  }

  void _onEqualsPress() {
    HapticFeedback.heavyImpact();
    if (_firstOperand == null || _operator == null) return;
    final secondOperand = _parseDisplayNumber(_displayValue);
    double result = 0.0;
    switch (_operator) {
      case '+':
        result = _firstOperand! + secondOperand;
        break;
      case '-':
        result = _firstOperand! - secondOperand;
        break;
      case '×':
        result = _firstOperand! * secondOperand;
        break;
      case '÷':
        result = secondOperand != 0 ? _firstOperand! / secondOperand : 0.0;
        break;
    }
    setState(() {
      _expression = '${Utils.formatNumber(_firstOperand!)} $_operator ${Utils.formatNumber(secondOperand)} =';
      _displayValue = Utils.formatNumber(result);
      _firstOperand = null;
      _operator = null;
      _resetDisplayOnNextInput = true;
    });
  }

  void _onClearPress() {
    HapticFeedback.lightImpact();
    setState(() {
      _displayValue = '0';
      _expression = '';
      _firstOperand = null;
      _operator = null;
      _resetDisplayOnNextInput = false;
    });
  }

  void _onBackspacePress() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_displayValue.length > 1) {
        _displayValue = _displayValue.substring(0, _displayValue.length - 1);
      } else {
        _displayValue = '0';
      }
    });
  }

  void _onPercentPress() {
    HapticFeedback.lightImpact();
    final currentVal = _parseDisplayNumber(_displayValue);
    setState(() {
      final result = currentVal / 100.0;
      _displayValue = Utils.formatNumber(result);
      _resetDisplayOnNextInput = true;
    });
  }

  double _parseDisplayNumber(String text) {
    return double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _displayValue));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Valor copiado: R\$ $_displayValue'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF12131D) : Colors.white;
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color btnBg = isDark ? const Color(0xFF222536) : Colors.grey.withValues(alpha: 0.12);
    final Color opBtnBg = isDark ? const Color(0xFF2A3152) : primaryColor.withValues(alpha: 0.15);
    final Color opTextColor = isDark ? const Color(0xFF93C5FD) : primaryColor;
    final Color clearBg = isDark ? const Color(0xFF3B1A22) : Colors.redAccent.withValues(alpha: 0.15);
    final Color clearTextColor = isDark ? const Color(0xFFFF6B6B) : Colors.redAccent;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: isDark ? const BorderSide(color: Color(0xFF2E334D), width: 1.5) : BorderSide.none,
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calculate_rounded, color: primaryColor, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Calculadora',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 22, color: isDark ? Colors.white70 : Colors.grey[700]),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Display Area
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF000000) : const Color(0xFFF3F5F9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3A3E54) : Colors.grey.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _expression.isEmpty ? ' ' : _expression,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _displayValue,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Keypad Grid
              _buildKeypad(btnBg, opBtnBg, primaryColor, opTextColor, clearBg, clearTextColor, isDark),
              const SizedBox(height: 14),

              // Bottom Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copiar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        side: BorderSide(color: isDark ? const Color(0xFF3A3E54) : Colors.grey.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _copyToClipboard,
                    ),
                  ),
                  if (widget.onUseValue != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Usar Valor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final val = _parseDisplayNumber(_displayValue);
                          widget.onUseValue!(val);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(
    Color btnBg, 
    Color opBtnBg, 
    Color primaryColor, 
    Color opTextColor, 
    Color clearBg, 
    Color clearTextColor, 
    bool isDark
  ) {
    return Column(
      children: [
        _buildRow([
          _calcBtn('C', color: clearBg, textColor: clearTextColor, onTap: _onClearPress),
          _calcBtn('⌫', color: isDark ? const Color(0xFF2A2E40) : btnBg, textColor: isDark ? Colors.white : null, onTap: _onBackspacePress),
          _calcBtn('%', color: isDark ? const Color(0xFF2A2E40) : btnBg, textColor: isDark ? Colors.white : null, onTap: _onPercentPress),
          _calcBtn('÷', color: opBtnBg, textColor: opTextColor, isOp: true, onTap: () => _onOperatorPress('÷')),
        ]),
        const SizedBox(height: 8),
        _buildRow([
          _calcBtn('7', color: btnBg, onTap: () => _onDigitPress('7')),
          _calcBtn('8', color: btnBg, onTap: () => _onDigitPress('8')),
          _calcBtn('9', color: btnBg, onTap: () => _onDigitPress('9')),
          _calcBtn('×', color: opBtnBg, textColor: opTextColor, isOp: true, onTap: () => _onOperatorPress('×')),
        ]),
        const SizedBox(height: 8),
        _buildRow([
          _calcBtn('4', color: btnBg, onTap: () => _onDigitPress('4')),
          _calcBtn('5', color: btnBg, onTap: () => _onDigitPress('5')),
          _calcBtn('6', color: btnBg, onTap: () => _onDigitPress('6')),
          _calcBtn('-', color: opBtnBg, textColor: opTextColor, isOp: true, onTap: () => _onOperatorPress('-')),
        ]),
        const SizedBox(height: 8),
        _buildRow([
          _calcBtn('1', color: btnBg, onTap: () => _onDigitPress('1')),
          _calcBtn('2', color: btnBg, onTap: () => _onDigitPress('2')),
          _calcBtn('3', color: btnBg, onTap: () => _onDigitPress('3')),
          _calcBtn('+', color: opBtnBg, textColor: opTextColor, isOp: true, onTap: () => _onOperatorPress('+')),
        ]),
        const SizedBox(height: 8),
        _buildRow([
          _calcBtn('0', color: btnBg, flex: 2, onTap: () => _onDigitPress('0')),
          _calcBtn(',', color: btnBg, onTap: _onDecimalPress),
          _calcBtn('=', color: isDark ? const Color(0xFF6366F1) : primaryColor, textColor: Colors.white, onTap: _onEqualsPress),
        ]),
      ],
    );
  }

  Widget _buildRow(List<Widget> buttons) {
    return Row(
      children: buttons.map((b) => Expanded(flex: b is _FlexButton ? b.flex : 1, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: b))).toList(),
    );
  }

  Widget _calcBtn(String label, {required Color color, Color? textColor, bool isOp = false, int flex = 1, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _FlexButton(
      flex: flex,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: isDark ? BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOp 
                  ? const Color(0xFF3B487A)
                  : (label == 'C' 
                      ? Colors.redAccent.withValues(alpha: 0.4) 
                      : (label == '=' ? Colors.transparent : Colors.white.withValues(alpha: 0.12))),
                width: 1.2,
              ),
            ) : null,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isOp ? 22 : 19,
                fontWeight: FontWeight.bold,
                color: textColor ?? (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlexButton extends StatelessWidget {
  final int flex;
  final Widget child;

  const _FlexButton({required this.flex, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

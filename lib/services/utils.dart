import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class Utils {
  static final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final quantityFormat = NumberFormat.decimalPattern('pt_BR');
  static final currencyInputFormat = NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2);

  static String formatCurrency(double value) {
    return currencyFormat.format(value);
  }

  /// Formata um valor numérico para exibição limpa (ex: 12.5 -> "12,5" ou 10.0 -> "10")
  static String formatNumber(double value) {
    return value == value.toInt() 
        ? value.toInt().toString() 
        : value.toString().replaceAll('.', ',');
  }

  /// Formata um valor monetário para campos de entrada com máscara automática (ex: 25.0 -> "25,00", 7.99 -> "7,99")
  static String formatCurrencyInput(double value) {
    if (value <= 0) return '';
    return currencyInputFormat.format(value).trim();
  }

  /// Converte texto digitado com máscara ou vírgula em double (ex: "1.250,50" -> 1250.5, "12,99" -> 12.99, "25" -> 25.0)
  static double parseCurrency(String text) {
    if (text.trim().isEmpty) return 0.0;
    String clean = text.replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (clean.isEmpty) return 0.0;
    if (clean.startsWith('(') && clean.endsWith(')')) {
      clean = '-${clean.substring(1, clean.length - 1)}';
    }
    if (clean.contains(',')) {
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    }
    clean = clean.replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  static final dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  static String formatDate(DateTime date) {
    return dateFormat.format(date);
  }

  static final Map<String, String> _normalizeCache = {};
  static final Map<int, String> _charMap = _buildCharMap();

  static Map<int, String> _buildCharMap() {
    const withDiacritics = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñ';
    const withoutDiacritics = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuyNn';
    final map = <int, String>{};
    for (int i = 0; i < withDiacritics.length; i++) {
      map[withDiacritics.codeUnitAt(i)] = withoutDiacritics[i];
    }
    return map;
  }

  static String normalize(String text) {
    if (text.isEmpty) return text;
    final cached = _normalizeCache[text];
    if (cached != null) return cached;

    final lower = text.toLowerCase().trim();
    final buffer = StringBuffer();
    for (int i = 0; i < lower.length; i++) {
      final code = lower.codeUnitAt(i);
      final replaced = _charMap[code];
      if (replaced != null) {
        buffer.write(replaced.toLowerCase());
      } else {
        buffer.writeCharCode(code);
      }
    }
    final result = buffer.toString();
    if (_normalizeCache.length < 5000) {
      _normalizeCache[text] = result;
    }
    return result;
  }
}

/// Formatador de entrada para valores monetários com máscara dinâmica (centavos da direita para esquerda).
/// Ex: digita 1 -> "0,01", digita 2 -> "0,12", digita 9 -> "1,29", digita 9 -> "12,99"
class CurrencyInputFormatter extends TextInputFormatter {
  final int maxDigits;
  static final NumberFormat _formatter = NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2);

  CurrencyInputFormatter({this.maxDigits = 10});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Mantém apenas dígitos numéricos
    final String clean = newValue.text.replaceAll(RegExp(r'\D'), '');
    final int intVal = int.tryParse(clean) ?? 0;
    if (intVal == 0) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    String digits = intVal.toString();
    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }

    final double value = int.parse(digits) / 100.0;
    final String formatted = _formatter.format(value).trim();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}


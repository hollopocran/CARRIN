import 'package:intl/intl.dart';

class Utils {
  static final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final quantityFormat = NumberFormat.decimalPattern('pt_BR');

  static String formatCurrency(double value) {
    return currencyFormat.format(value);
  }

  static String formatNumber(double value) {
    return value == value.toInt() 
        ? value.toInt().toString() 
        : value.toString().replaceAll('.', ',');
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

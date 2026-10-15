import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço responsável por manter um resumo rápido das compras sincronizado
/// para exibição em widgets da tela inicial, tela de bloqueio e atalhos rápidos.
class QuickSummaryService {
  static const String _prefKey = 'carrin_quick_summary';

  /// Salva o resumo consolidado das compras atuais
  static Future<void> saveQuickSummary({
    required String month,
    required double totalSpent,
    required double budget,
    required int totalItems,
    required int boughtItems,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'month': month,
        'totalSpent': totalSpent,
        'budget': budget,
        'balance': budget - totalSpent,
        'totalItems': totalItems,
        'boughtItems': boughtItems,
        'pendingItems': totalItems - boughtItems,
        'percent': budget > 0 ? (totalSpent / budget).clamp(0.0, 2.0) : 0.0,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_prefKey, jsonEncode(data));
    } catch (_) {
      // Ignora falhas de escrita silenciosas de cache rápido
    }
  }

  /// Recupera o último resumo consolidado
  static Future<Map<String, dynamic>?> getQuickSummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

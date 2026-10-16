import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/item.dart';
import '../providers/item_provider.dart';

/// Informações consolidadas de um produto obtidas via código de barras
class ScannedProductInfo {
  final String barcode;
  final String name;
  final String? brand;
  final String category;
  final String? quantity;
  final String? imageUrl;
  final double? lastPrice;
  final String source; // 'local', 'online', 'community'

  const ScannedProductInfo({
    required this.barcode,
    required this.name,
    this.brand,
    required this.category,
    this.quantity,
    this.imageUrl,
    this.lastPrice,
    required this.source,
  });

  bool get isFromOnline => source == 'online';
}

/// Serviço inteligente para identificar produtos a partir do código de barras
/// Consultando histórico local do usuário e a base aberta Open Food Facts Brasil
class BarcodeLookupService {
  BarcodeLookupService._privateConstructor();
  static final BarcodeLookupService instance = BarcodeLookupService._privateConstructor();

  final Map<String, ScannedProductInfo> _cache = {};

  /// Formata strings em Title Case (primeira letra de cada palavra maiúscula)
  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    final words = text.toLowerCase().split(' ');
    final capitalized = words.map((w) {
      if (w.isEmpty) return w;
      if (['de', 'da', 'do', 'das', 'dos', 'em', 'com', 'e'].contains(w)) return w;
      return w[0].toUpperCase() + w.substring(1);
    });
    return capitalized.join(' ');
  }

  /// Limpa e formata o nome do produto combinando marca e quantidade se relevante
  String _formatProductName(String rawName, String? brand, String? quantity) {
    String cleanName = rawName.trim();
    if (cleanName.isEmpty && brand != null && brand.isNotEmpty) {
      cleanName = brand;
    }

    cleanName = _toTitleCase(cleanName);

    // Se tiver marca e ela não estiver contida no nome, adiciona suavemente
    if (brand != null && brand.trim().isNotEmpty) {
      final cleanBrand = brand.split(',')[0].trim();
      final normName = cleanName.toLowerCase();
      final normBrand = cleanBrand.toLowerCase();
      if (!normName.contains(normBrand) && cleanBrand.length > 2) {
        cleanName = '$cleanName ${_toTitleCase(cleanBrand)}';
      }
    }

    // Se tiver quantidade/gramatura e não estiver contida no nome, adiciona ao final
    if (quantity != null && quantity.trim().isNotEmpty) {
      final cleanQty = quantity.trim();
      final normName = cleanName.toLowerCase();
      final normQty = cleanQty.toLowerCase();
      if (!normName.contains(normQty)) {
        cleanName = '$cleanName $cleanQty';
      }
    }

    return cleanName.trim();
  }

  /// Busca informações detalhadas de um produto pelo código de barras
  Future<ScannedProductInfo?> lookup(
    String barcode, {
    ItemProvider? itemProvider,
  }) async {
    final cleanBarcode = Item.parseBarcode(barcode);
    if (cleanBarcode == null || cleanBarcode.isEmpty) return null;

    // 1. Tenta identificar no histórico local do próprio usuário (mais relevante e com preço real)
    if (itemProvider != null) {
      final local = itemProvider.findProductByBarcode(cleanBarcode);
      if (local != null) {
        final name = (local['name'] as String? ?? '').trim();
        if (name.isNotEmpty) {
          final info = ScannedProductInfo(
            barcode: cleanBarcode,
            name: name,
            category: (local['category'] as String?) ?? ItemProvider.suggestCategoryForName(name),
            lastPrice: (local['price'] as num?)?.toDouble(),
            source: 'local',
          );
          _cache[cleanBarcode] = info;
          return info;
        }
      }
    }

    // 2. Verifica se já está em cache em memória
    if (_cache.containsKey(cleanBarcode)) {
      return _cache[cleanBarcode];
    }

    // 3. Consulta a API global/nacional do Open Food Facts
    try {
      final endpoint = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$cleanBarcode.json?fields=product_name,product_name_pt,brands,categories,quantity,image_url',
      );

      final response = await http.get(
        endpoint,
        headers: {
          'User-Agent': 'CarrinApp/1.0 (Android; pt-BR; https://github.com/hollopocran/CARRIN)',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          final p = data['product'] as Map<String, dynamic>;
          final rawName = (p['product_name_pt'] as String?) ??
              (p['product_name'] as String?) ??
              (p['brands'] as String?);

          if (rawName != null && rawName.trim().isNotEmpty) {
            final brand = p['brands'] as String?;
            final quantity = p['quantity'] as String?;
            final imageUrl = p['image_url'] as String?;

            final formattedName = _formatProductName(rawName, brand, quantity);
            final suggestedCategory = ItemProvider.suggestCategoryForName(formattedName);

            final info = ScannedProductInfo(
              barcode: cleanBarcode,
              name: formattedName,
              brand: brand != null ? _toTitleCase(brand.split(',')[0].trim()) : null,
              category: suggestedCategory,
              quantity: quantity?.trim(),
              imageUrl: imageUrl,
              source: 'online',
            );

            _cache[cleanBarcode] = info;
            debugPrint('🔍 BarcodeLookup: Produto identificado online -> $formattedName ($suggestedCategory)');
            return info;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ BarcodeLookup: Erro na busca online do barcode $cleanBarcode: $e');
    }

    return null;
  }
}

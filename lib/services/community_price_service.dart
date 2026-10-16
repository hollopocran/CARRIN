import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/community_price.dart';
import 'database_helper.dart';
import 'location_service.dart';

class CommunityPriceService {
  CommunityPriceService._privateConstructor();
  static final CommunityPriceService instance = CommunityPriceService._privateConstructor();

  static const String _prefUrlKey = 'supabase_community_url';
  static const String _prefAnonKey = 'supabase_community_anon_key';
  static const String _prefSeedDoneKey = 'community_seed_prices_v1_done';

  String? _cachedUrl;
  String? _cachedAnonKey;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedUrl = prefs.getString(_prefUrlKey);
      _cachedAnonKey = prefs.getString(_prefAnonKey);

      final seedDone = prefs.getBool(_prefSeedDoneKey) ?? false;
      if (!seedDone) {
        await _seedInitialCommunityPrices();
        await prefs.setBool(_prefSeedDoneKey, true);
      }
    } catch (e) {
      debugPrint('📍 CommunityPriceService init error: $e');
    }
    _isInitialized = true;
  }

  bool get isConfigured => 
      _cachedUrl != null && _cachedUrl!.trim().isNotEmpty && 
      _cachedAnonKey != null && _cachedAnonKey!.trim().isNotEmpty;

  String? get supabaseUrl => _cachedUrl;
  String? get supabaseAnonKey => _cachedAnonKey;

  Future<void> saveConfig(String url, String anonKey) async {
    final prefs = await SharedPreferences.getInstance();
    _cachedUrl = url.trim();
    _cachedAnonKey = anonKey.trim();
    await prefs.setString(_prefUrlKey, _cachedUrl!);
    await prefs.setString(_prefAnonKey, _cachedAnonKey!);
  }

  /// Publica um preço registrado pelo usuário na base da comunidade
  Future<bool> publishPrice({
    required String productName,
    required double price,
    required String supermarketName,
    String? category,
    String? unit,
    double? latitude,
    double? longitude,
    String? submittedBy,
    bool verifiedReceipt = false,
  }) async {
    await init();
    if (productName.trim().isEmpty || price <= 0 || supermarketName.trim().isEmpty) {
      return false;
    }

    final newPrice = CommunityPrice(
      id: 'cp_${DateTime.now().millisecondsSinceEpoch}_${productName.hashCode.abs()}',
      productName: productName.trim(),
      category: category,
      unit: unit ?? 'un',
      price: price,
      supermarketName: supermarketName.trim(),
      latitude: latitude,
      longitude: longitude,
      submittedBy: submittedBy ?? 'Cliente CARRIN',
      verifiedReceipt: verifiedReceipt,
      createdAt: DateTime.now(),
    );

    // 1. Salva imediatamente no banco SQLite local do dispositivo
    await DatabaseHelper.instance.saveCommunityPrice(newPrice);

    // 2. Se o Supabase estiver configurado, envia via REST API
    if (isConfigured) {
      try {
        final endpoint = Uri.parse('${_cachedUrl!}/rest/v1/community_prices');
        final response = await http.post(
          endpoint,
          headers: {
            'apikey': _cachedAnonKey!,
            'Authorization': 'Bearer ${_cachedAnonKey!}',
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          },
          body: jsonEncode({
            'product_name': newPrice.productName,
            'category': newPrice.category,
            'unit': newPrice.unit,
            'price': newPrice.price,
            'supermarket_name': newPrice.supermarketName,
            'latitude': newPrice.latitude,
            'longitude': newPrice.longitude,
            'submitted_by': newPrice.submittedBy,
            'verified_receipt': newPrice.verifiedReceipt,
            'created_at': newPrice.createdAt.toIso8601String(),
          }),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('✅ Preço publicado na nuvem Supabase com sucesso: ${newPrice.productName}');
          return true;
        } else {
          debugPrint('⚠️ Resposta Supabase: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao enviar preço para o Supabase (salvo localmente): $e');
      }
    }

    return true;
  }

  /// Busca os preços mais recentes e sincroniza com a nuvem se disponível
  Future<List<CommunityPrice>> getRecentFeed({
    double? userLat,
    double? userLng,
    double radiusKm = 25.0,
    String? query,
  }) async {
    await init();

    // 1. Tenta buscar dados novos do Supabase se configurado
    if (isConfigured) {
      try {
        String urlStr = '${_cachedUrl!}/rest/v1/community_prices?select=*&order=created_at.desc&limit=100';
        if (query != null && query.trim().isNotEmpty) {
          urlStr += '&product_name=ilike.*${Uri.encodeComponent(query.trim())}*';
        }
        final endpoint = Uri.parse(urlStr);
        final response = await http.get(
          endpoint,
          headers: {
            'apikey': _cachedAnonKey!,
            'Authorization': 'Bearer ${_cachedAnonKey!}',
          },
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final List<dynamic> list = jsonDecode(response.body);
          final cloudPrices = list.map((item) => CommunityPrice.fromMap(item as Map<String, dynamic>, userLat: userLat, userLng: userLng)).toList();
          if (cloudPrices.isNotEmpty) {
            await DatabaseHelper.instance.saveCommunityPrices(cloudPrices);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao buscar feed no Supabase (usando cache local): $e');
      }
    }

    // 2. Lê do cache local SQLite
    final localPrices = await DatabaseHelper.instance.getCachedCommunityPrices(
      query: query,
      userLat: userLat,
      userLng: userLng,
    );

    // 3. Filtra pelo raio do GPS se o usuário tiver localização
    if (userLat != null && userLng != null) {
      final maxMeters = radiusKm * 1000;
      final filtered = localPrices.where((p) {
        if (p.distanceMeters == null) return true; // sem coordenadas aceita
        return p.distanceMeters! <= maxMeters;
      }).toList();

      filtered.sort((a, b) {
        final distA = a.distanceMeters ?? double.infinity;
        final distB = b.distanceMeters ?? double.infinity;
        return distA.compareTo(distB);
      });
      return filtered;
    }

    return localPrices;
  }

  /// Retorna o ranking comparativo de quais mercados na região estão valendo mais a pena
  Future<List<MarketComparison>> getCheapestMarketsNearby({
    required double userLat,
    required double userLng,
    double radiusKm = 15.0,
  }) async {
    final allPrices = await getRecentFeed(userLat: userLat, userLng: userLng, radiusKm: radiusKm);
    if (allPrices.isEmpty) return [];

    // Agrupa preços por supermercado
    final Map<String, List<CommunityPrice>> marketMap = {};
    final Map<String, CommunityPrice> marketPosMap = {};

    for (var p in allPrices) {
      final market = p.supermarketName.trim();
      if (market.isEmpty) continue;
      marketMap.putIfAbsent(market, () => []).add(p);
      if (p.latitude != null && p.longitude != null && !marketPosMap.containsKey(market)) {
        marketPosMap[market] = p;
      }
    }

    // Agrupa preços por produto para descobrir onde cada produto é mais barato
    final Map<String, double> lowestProductPrice = {};
    for (var p in allPrices) {
      final normName = p.productName.toLowerCase().trim();
      if (!lowestProductPrice.containsKey(normName) || p.price < lowestProductPrice[normName]!) {
        lowestProductPrice[normName] = p.price;
      }
    }

    List<MarketComparison> comparisons = [];

    for (var entry in marketMap.entries) {
      final market = entry.key;
      final prices = entry.value;

      double totalSum = 0;
      int cheapestCount = 0;

      for (var p in prices) {
        totalSum += p.price;
        final normName = p.productName.toLowerCase().trim();
        if (lowestProductPrice.containsKey(normName) && p.price <= lowestProductPrice[normName]!) {
          cheapestCount++;
        }
      }

      final avgPrice = prices.isNotEmpty ? totalSum / prices.length : 0.0;
      final posRef = marketPosMap[market];
      double? dist;
      if (posRef?.latitude != null && posRef?.longitude != null) {
        dist = LocationService.instance.calculateDistance(userLat, userLng, posRef!.latitude!, posRef.longitude!);
      }

      comparisons.add(MarketComparison(
        supermarketName: market,
        latitude: posRef?.latitude,
        longitude: posRef?.longitude,
        distanceMeters: dist,
        itemsCount: prices.length,
        averageItemPrice: avgPrice,
        cheapestCount: cheapestCount,
      ));
    }

    // Ordena pelo maior número de itens mais baratos e menor média
    comparisons.sort((a, b) {
      if (b.cheapestCount != a.cheapestCount) {
        return b.cheapestCount.compareTo(a.cheapestCount);
      }
      return a.averageItemPrice.compareTo(b.averageItemPrice);
    });

    if (comparisons.isNotEmpty) {
      final first = comparisons.first;
      comparisons[0] = MarketComparison(
        supermarketName: first.supermarketName,
        latitude: first.latitude,
        longitude: first.longitude,
        distanceMeters: first.distanceMeters,
        itemsCount: first.itemsCount,
        averageItemPrice: first.averageItemPrice,
        cheapestCount: first.cheapestCount,
        isCheapest: true,
      );
    }

    return comparisons;
  }

  /// Busca e compara preços de um determinado produto entre diferentes mercados
  Future<ProductComparison?> getProductComparison(
    String query, {
    double? userLat,
    double? userLng,
    double radiusKm = 20.0,
  }) async {
    final prices = await getRecentFeed(userLat: userLat, userLng: userLng, radiusKm: radiusKm, query: query);
    final cleanQ = query.toLowerCase().trim();
    final matching = prices.where((p) => p.productName.toLowerCase().contains(cleanQ)).toList();

    if (matching.isEmpty) return null;

    matching.sort((a, b) => a.price.compareTo(b.price));

    double sum = 0;
    for (var p in matching) {
      sum += p.price;
    }

    final minPrice = matching.first.price;
    final maxPrice = matching.last.price;
    final avgPrice = sum / matching.length;
    final cheapest = matching.first;
    final mostExpensive = matching.last;

    return ProductComparison(
      productName: cheapest.productName,
      unit: cheapest.unit ?? 'un',
      averagePrice: avgPrice,
      minPrice: minPrice,
      maxPrice: maxPrice,
      cheapestMarket: cheapest.supermarketName,
      cheapestMarketDistance: cheapest.distanceMeters,
      mostExpensiveMarket: mostExpensive.supermarketName,
      totalQuotes: matching.length,
      prices: matching,
    );
  }

  /// Popula a base inicial com produtos comuns para teste imediato
  Future<void> _seedInitialCommunityPrices() async {
    final now = DateTime.now();
    final seedData = [
      {'name': 'Arroz Branco 5kg', 'price': 24.90, 'market': 'Assaí Atacadista', 'unit': 'pct', 'cat': 'Alimentos', 'receipt': 1},
      {'name': 'Arroz Branco 5kg', 'price': 27.50, 'market': 'Carrefour', 'unit': 'pct', 'cat': 'Alimentos', 'receipt': 0},
      {'name': 'Arroz Branco 5kg', 'price': 25.80, 'market': 'Atacadão', 'unit': 'pct', 'cat': 'Alimentos', 'receipt': 1},
      {'name': 'Feijão Carioca 1kg', 'price': 6.89, 'market': 'Assaí Atacadista', 'unit': 'pct', 'cat': 'Alimentos', 'receipt': 1},
      {'name': 'Feijão Carioca 1kg', 'price': 7.49, 'market': 'Carrefour', 'unit': 'pct', 'cat': 'Alimentos', 'receipt': 0},
      {'name': 'Feijão Carioca 1kg', 'price': 6.99, 'market': 'Pão de Açúcar', 'unit': 'pct', 'cat': 'Alimentos', 'receipt': 1},
      {'name': 'Leite Integral 1L', 'price': 4.19, 'market': 'Atacadão', 'unit': 'un', 'cat': 'Laticínios', 'receipt': 1},
      {'name': 'Leite Integral 1L', 'price': 4.79, 'market': 'Carrefour', 'unit': 'un', 'cat': 'Laticínios', 'receipt': 0},
      {'name': 'Leite Integral 1L', 'price': 4.39, 'market': 'Assaí Atacadista', 'unit': 'un', 'cat': 'Laticínios', 'receipt': 1},
      {'name': 'Óleo de Soja 900ml', 'price': 5.89, 'market': 'Assaí Atacadista', 'unit': 'un', 'cat': 'Alimentos', 'receipt': 1},
      {'name': 'Óleo de Soja 900ml', 'price': 6.49, 'market': 'Pão de Açúcar', 'unit': 'un', 'cat': 'Alimentos', 'receipt': 0},
      {'name': 'Café Torrado e Moído 500g', 'price': 16.90, 'market': 'Atacadão', 'unit': 'pct', 'cat': 'Matinais', 'receipt': 1},
      {'name': 'Café Torrado e Moído 500g', 'price': 19.80, 'market': 'Carrefour', 'unit': 'pct', 'cat': 'Matinais', 'receipt': 0},
      {'name': 'Açúcar Refinado 1kg', 'price': 3.99, 'market': 'Assaí Atacadista', 'unit': 'pct', 'cat': 'Alimentos', 'receipt': 1},
      {'name': 'Açúcar Refinado 1kg', 'price': 4.59, 'market': 'Carrefour', 'unit': 'pct', 'cat': 'Alimentos', 'receipt': 0},
      {'name': 'Detergente Líquido 500ml', 'price': 1.99, 'market': 'Atacadão', 'unit': 'un', 'cat': 'Limpeza', 'receipt': 1},
      {'name': 'Detergente Líquido 500ml', 'price': 2.49, 'market': 'Pão de Açúcar', 'unit': 'un', 'cat': 'Limpeza', 'receipt': 0},
      {'name': 'Sabão em Pó 1.6kg', 'price': 14.90, 'market': 'Assaí Atacadista', 'unit': 'cx', 'cat': 'Limpeza', 'receipt': 1},
      {'name': 'Sabão em Pó 1.6kg', 'price': 18.50, 'market': 'Carrefour', 'unit': 'cx', 'cat': 'Limpeza', 'receipt': 0},
    ];

    final prices = seedData.map((d) {
      return CommunityPrice(
        id: 'seed_${d['name']}_${d['market']}',
        productName: d['name'] as String,
        price: (d['price'] as num).toDouble(),
        supermarketName: d['market'] as String,
        unit: d['unit'] as String?,
        category: d['cat'] as String?,
        verifiedReceipt: d['receipt'] == 1,
        submittedBy: 'Colaborador CARRIN',
        createdAt: now.subtract(Duration(hours: (d['name'] as String).hashCode.abs() % 48)),
      );
    }).toList();

    await DatabaseHelper.instance.saveCommunityPrices(prices);
  }

  /// Retorna o SQL para criar a tabela no Supabase com 1 clique
  String getSupabaseSetupSql() {
    return '''
-- Tabela para a Rede Social de Preços do CARRIN
create table if not exists community_prices (
  id uuid default gen_random_uuid() primary key,
  product_name text not null,
  category text,
  unit text default 'un',
  price numeric(10,2) not null,
  supermarket_name text not null,
  latitude double precision,
  longitude double precision,
  submitted_by text default 'Cliente CARRIN',
  verified_receipt boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Índices para buscas ultrarrápidas por produto e mercado
create index if not exists idx_community_product on community_prices(product_name);
create index if not exists idx_community_market on community_prices(supermarket_name);
create index if not exists idx_community_created on community_prices(created_at desc);

-- Políticas de segurança: Leitura e escrita públicas e anônimas
alter table community_prices enable row level security;
create policy "Permitir leitura pública" on community_prices for select using (true);
create policy "Permitir inserção pública" on community_prices for insert with check (true);
''';
  }
}

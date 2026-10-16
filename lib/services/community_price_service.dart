import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/community_price.dart';
import 'database_helper.dart';
import 'default_supermarkets.dart';
import 'location_service.dart';

class CommunityPriceService {
  CommunityPriceService._privateConstructor();
  static final CommunityPriceService instance = CommunityPriceService._privateConstructor();

  static const String _prefUrlKey = 'supabase_community_url';
  static const String _prefAnonKey = 'supabase_community_anon_key';

  /// Credenciais padrão do Supabase embutidas (zero configuração para o usuário)
  static const String defaultSupabaseUrl = 'https://togbshissjtctvlsvapc.supabase.co';
  static const String defaultSupabaseAnonKey = 'sb_publishable_DikvfAMTza89HWcTX5zNBQ_Z987Ak_y';

  /// Supermercado padrão de referência (Guanabara Niterói)
  static const String defaultStoreName = 'Supermercados Guanabara - Niterói';
  static const double defaultStoreLat = -22.89012;
  static const double defaultStoreLng = -43.11535;

  /// Descobre as coordenadas reais de um supermercado usando o banco local e o catálogo pré-carregado
  Future<Map<String, double>?> resolveMarketCoordinates(String marketName, {double? userLat, double? userLng}) async {
    final clean = marketName.trim();
    if (clean.isEmpty) return null;

    // 1. Tenta no catálogo estático calibrado DefaultSupermarketsData (fonte de verdade oficial)
    final preloaded = DefaultSupermarketsData.findMatch(clean, userLat: userLat, userLng: userLng);
    if (preloaded != null) {
      return {'latitude': preloaded.latitude, 'longitude': preloaded.longitude};
    }

    // 2. Tenta buscar no SQLite (supermercados customizados salvos)
    final saved = await DatabaseHelper.instance.findSupermarketByName(clean);
    if (saved != null) {
      final lat = (saved['latitude'] as num?)?.toDouble();
      final lng = (saved['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        return {'latitude': lat, 'longitude': lng};
      }
    }

    // 3. Fallback se contiver guanabara
    if (clean.toLowerCase().contains('guanabara')) {
      return {'latitude': defaultStoreLat, 'longitude': defaultStoreLng};
    }

    return null;
  }

  String? _cachedUrl;
  String? _cachedAnonKey;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedUrl = prefs.getString(_prefUrlKey) ?? defaultSupabaseUrl;
      _cachedAnonKey = prefs.getString(_prefAnonKey) ?? defaultSupabaseAnonKey;

      await DatabaseHelper.instance.purgeSeedCommunityPrices();
      await DatabaseHelper.instance.cleanTestSupermarkets();
      await DatabaseHelper.instance.ensureDefaultSupermarkets();
      await DatabaseHelper.instance.assignDefaultSupermarket(defaultStoreName);
      await DatabaseHelper.instance.seedCommunityPricesFromUserPurchases();

      // Auto-sincronização obrigatória e transparente das compras do usuário para a comunidade
      _autoSyncUserPurchasesInBackground();
    } catch (e) {
      debugPrint('📍 CommunityPriceService init error: $e');
    }
    _isInitialized = true;
  }

  /// Sincronização automática e mandatória em segundo plano de todas as compras reais do usuário
  Future<void> _autoSyncUserPurchasesInBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userItems = await DatabaseHelper.instance.getAllUserPurchasedProducts();
      if (userItems.isEmpty) return;

      final syncedJson = prefs.getString('community_synced_items_v2');
      Map<String, dynamic> syncedMap = {};
      if (syncedJson != null && syncedJson.isNotEmpty) {
        try {
          syncedMap = jsonDecode(syncedJson) as Map<String, dynamic>;
        } catch (_) {}
      }

      final List<CommunityPrice> toPublish = [];
      final Map<String, dynamic> updatedMap = Map.from(syncedMap);

      for (var row in userItems) {
        final name = (row['name'] as String? ?? '').trim();
        final price = (row['unit_price'] as num?)?.toDouble() ?? 0.0;
        if (name.isEmpty || price <= 0) continue;

        String market = (row['supermarket'] as String? ?? '').trim();
        if (market.isEmpty || market.toLowerCase() == 'supermercado local' || market.toLowerCase() == 'supermercado') {
          market = defaultStoreName;
        }

        final key = '${name.toLowerCase()}|${market.toLowerCase()}';
        final lastSyncedPrice = (updatedMap[key] as num?)?.toDouble();

        // Se já sincronizado com este mesmo preço, não duplica
        if (lastSyncedPrice != null && (lastSyncedPrice - price).abs() < 0.001) {
          continue;
        }

        // Resolve as coordenadas exatas do supermercado
        final coords = await resolveMarketCoordinates(market);

        toPublish.add(CommunityPrice(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}_${key.hashCode.abs()}',
          productName: name,
          category: row['category'] as String?,
          unit: row['is_kg'] == 1 ? 'kg' : 'un',
          price: price,
          supermarketName: market,
          latitude: coords?['latitude'],
          longitude: coords?['longitude'],
          submittedBy: 'Cliente CARRIN',
          verifiedReceipt: false,
          createdAt: DateTime.now(),
        ));

        updatedMap[key] = price;
      }

      if (toPublish.isNotEmpty) {
        debugPrint('🚀 Auto-sincronizando ${toPublish.length} compras reais do usuário para a Comunidade...');
        final count = await publishPricesBatch(toPublish);
        if (count > 0) {
          await prefs.setString('community_synced_items_v2', jsonEncode(updatedMap));
          debugPrint('✅ $count compras do usuário sincronizadas com a Comunidade Supabase!');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erro na auto-sincronização de compras: $e');
    }
  }

  /// Sincroniza em lote os itens comprados de um carrinho/mês finalizado
  Future<void> syncMonthPurchases(String month, List<dynamic> items) async {
    try {
      final List<CommunityPrice> toPublish = [];
      for (var it in items) {
        final name = (it.name as String? ?? '').trim();
        final price = (it.unitPrice as num?)?.toDouble() ?? 0.0;
        if (name.isEmpty || price <= 0) continue;

        String market = (it.supermarket as String? ?? '').trim();
        if (market.isEmpty || market.toLowerCase() == 'supermercado local' || market.toLowerCase() == 'supermercado') {
          market = defaultStoreName;
        }

        final coords = await resolveMarketCoordinates(market);

        toPublish.add(CommunityPrice(
          id: 'month_${DateTime.now().millisecondsSinceEpoch}_${name.hashCode.abs()}',
          productName: name,
          category: it.category as String?,
          unit: it.isKg == true ? 'kg' : 'un',
          price: price,
          supermarketName: market,
          latitude: coords?['latitude'],
          longitude: coords?['longitude'],
          submittedBy: 'Cliente CARRIN',
          verifiedReceipt: false,
          createdAt: DateTime.now(),
        ));
      }
      if (toPublish.isNotEmpty) {
        await publishPricesBatch(toPublish);
      }
    } catch (e) {
      debugPrint('Erro ao sincronizar compras do mês: $e');
    }
  }

  bool get isConfigured => 
      _cachedUrl != null && _cachedUrl!.trim().isNotEmpty && 
      _cachedAnonKey != null && _cachedAnonKey!.trim().isNotEmpty;

  String? get supabaseUrl => _cachedUrl ?? defaultSupabaseUrl;
  String? get supabaseAnonKey => _cachedAnonKey ?? defaultSupabaseAnonKey;

  Map<String, String> _buildHeaders({bool isPost = false}) {
    final key = _cachedAnonKey ?? defaultSupabaseAnonKey;
    final headers = <String, String>{
      'apikey': key,
      'Accept': 'application/json',
    };
    // As chaves legadas do Supabase são JWTs (iniciando em eyJ).
    // Apenas JWTs devem ser enviados no header Authorization: Bearer.
    // As novas chaves (sb_publishable_...) não devem ir no Authorization Bearer.
    if (key.startsWith('eyJ')) {
      headers['Authorization'] = 'Bearer $key';
    }
    if (isPost) {
      headers['Content-Type'] = 'application/json';
      headers['Prefer'] = 'return=minimal';
    }
    return headers;
  }

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

    double? finalLat = latitude;
    double? finalLng = longitude;
    if (finalLat == null || finalLng == null) {
      final coords = await resolveMarketCoordinates(supermarketName);
      if (coords != null) {
        finalLat = coords['latitude'];
        finalLng = coords['longitude'];
      }
    }

    final newPrice = CommunityPrice(
      id: 'cp_${DateTime.now().millisecondsSinceEpoch}_${productName.hashCode.abs()}',
      productName: productName.trim(),
      category: category,
      unit: unit ?? 'un',
      price: price,
      supermarketName: supermarketName.trim(),
      latitude: finalLat,
      longitude: finalLng,
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
          headers: _buildHeaders(isPost: true),
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

  /// Publica uma lista de preços em lote na nuvem do Supabase e no SQLite local
  Future<int> publishPricesBatch(List<CommunityPrice> prices) async {
    if (prices.isEmpty) return 0;
    await init();

    // 1. Salva no SQLite local
    await DatabaseHelper.instance.saveCommunityPrices(prices);

    // 2. Se o Supabase estiver configurado, envia em lote via REST API
    if (isConfigured) {
      try {
        final endpoint = Uri.parse('${_cachedUrl!}/rest/v1/community_prices');
        final payload = prices.map((p) => {
          'product_name': p.productName,
          'category': p.category,
          'unit': p.unit,
          'price': p.price,
          'supermarket_name': p.supermarketName,
          'latitude': p.latitude,
          'longitude': p.longitude,
          'submitted_by': p.submittedBy,
          'verified_receipt': p.verifiedReceipt,
          'created_at': p.createdAt.toIso8601String(),
        }).toList();

        final response = await http.post(
          endpoint,
          headers: _buildHeaders(isPost: true),
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('✅ ${prices.length} preços publicados em lote no Supabase com sucesso!');
          return prices.length;
        } else {
          debugPrint('⚠️ Erro no batch Supabase: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao enviar lote para o Supabase: $e');
      }
    }

    return prices.length;
  }

  /// Coleta os produtos que o usuário possui com preços reais registrados no app
  Future<List<CommunityPrice>> getUserRegisteredPrices({
    String? fallbackSupermarket,
    double? fallbackLat,
    double? fallbackLng,
    Map<String, List<Map<String, dynamic>>>? priceHistoryCache,
  }) async {
    final List<CommunityPrice> list = [];
    final Set<String> seenKeys = {};

    // 1. Coleta do SQLite (todas as listas de compras registradas)
    final dbRows = await DatabaseHelper.instance.getAllUserPurchasedProducts();
    for (var row in dbRows) {
      final name = (row['name'] as String? ?? '').trim();
      final price = (row['unit_price'] as num?)?.toDouble() ?? 0.0;
      if (name.isEmpty || price <= 0) continue;

      String market = (row['supermarket'] as String? ?? '').trim();
      final lMarket = market.toLowerCase();
      if (market.isEmpty || lMarket == 'supermercado local' || lMarket == 'supermercado') {
        market = fallbackSupermarket ?? defaultStoreName;
      }

      final normName = name.toLowerCase();
      final normMarket = market.toLowerCase();
      final key = '${normName}_$normMarket';

      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        list.add(CommunityPrice(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}_${key.hashCode.abs()}',
          productName: name,
          category: row['category'] as String?,
          unit: row['is_kg'] == 1 ? 'kg' : 'un',
          price: price,
          supermarketName: market,
          latitude: (market == defaultStoreName) ? defaultStoreLat : fallbackLat,
          longitude: (market == defaultStoreName) ? defaultStoreLng : fallbackLng,
          submittedBy: 'Minhas Compras',
          verifiedReceipt: false,
          createdAt: DateTime.now(),
        ));
      }
    }

    // 2. Se houver histórico de preços em memória/cache, adiciona os que faltam
    if (priceHistoryCache != null) {
      for (var entryList in priceHistoryCache.values) {
        for (var entry in entryList) {
          final name = (entry['name'] as String? ?? '').trim();
          final price = (entry['price'] as num?)?.toDouble() ?? 0.0;
          if (name.isEmpty || price <= 0) continue;

          String market = (entry['supermarket'] as String? ?? '').trim();
          final lMarket = market.toLowerCase();
          if (market.isEmpty || lMarket == 'supermercado local' || lMarket == 'supermercado') {
            market = fallbackSupermarket ?? defaultStoreName;
          }

          final normName = name.toLowerCase();
          final normMarket = market.toLowerCase();
          final key = '${normName}_$normMarket';

          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            list.add(CommunityPrice(
              id: 'hist_${DateTime.now().millisecondsSinceEpoch}_${key.hashCode.abs()}',
              productName: name,
              category: entry['category'] as String?,
              unit: 'un',
              price: price,
              supermarketName: market,
              latitude: (market == defaultStoreName) ? defaultStoreLat : fallbackLat,
              longitude: (market == defaultStoreName) ? defaultStoreLng : fallbackLng,
              submittedBy: 'Minhas Compras',
              verifiedReceipt: false,
              createdAt: DateTime.now(),
            ));
          }
        }
      }
    }

    return list;
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
        String urlStr = '${_cachedUrl!}/rest/v1/community_prices?select=*&order=created_at.desc&limit=500';
        if (query != null && query.trim().isNotEmpty) {
          urlStr += '&product_name=ilike.*${Uri.encodeComponent(query.trim())}*';
        }
        final endpoint = Uri.parse(urlStr);
        final response = await http.get(
          endpoint,
          headers: _buildHeaders(isPost: false),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final List<dynamic> list = jsonDecode(response.body);
          final cloudPrices = list
              .map((item) => CommunityPrice.fromMap(item as Map<String, dynamic>, userLat: userLat, userLng: userLng))
              .where((p) {
                final isMock = p.submittedBy.contains('Teste') ||
                               p.submittedBy == 'Comunidade CARRIN' ||
                               p.id.startsWith('seed_');
                return !isMock;
              })
              .toList();
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
      if (filtered.isNotEmpty) {
        return filtered;
      }
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
      final rawMarket = p.supermarketName.trim();
      if (rawMarket.isEmpty) continue;
      // Normaliza para o nome oficial do catálogo se coincidir (ex: "Supermercados Guanabara" -> "Supermercados Guanabara - Niterói")
      final match = DefaultSupermarketsData.findMatch(rawMarket, userLat: userLat, userLng: userLng);
      final market = match?.name ?? rawMarket;

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

    final savedSupermarkets = await DatabaseHelper.instance.getSupermarkets();

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
      // PRIORIDADE MÁXIMA: Catálogo oficial calibrado (DefaultSupermarketsData / SQLite)
      final resolved = await resolveMarketCoordinates(market, userLat: userLat, userLng: userLng);
      double? lat = resolved?['latitude'] ?? posRef?.latitude;
      double? lng = resolved?['longitude'] ?? posRef?.longitude;

      double? dist;
      if (lat != null && lng != null) {
        dist = LocationService.instance.calculateDistance(userLat, userLng, lat, lng);
      }

      comparisons.add(MarketComparison(
        supermarketName: market,
        latitude: lat,
        longitude: lng,
        distanceMeters: dist,
        itemsCount: prices.length,
        averageItemPrice: avgPrice,
        cheapestCount: cheapestCount,
      ));
    }

    // Inclui mercados salvos no SQLite mesmo que ainda não tenham compras cadastradas
    for (var s in savedSupermarkets) {
      final sName = (s['name'] as String? ?? '').trim();
      if (sName.isEmpty) continue;
      final match = DefaultSupermarketsData.findMatch(sName, userLat: userLat, userLng: userLng);
      final canonicalName = match?.name ?? sName;

      final exists = comparisons.any((c) {
        if (c.supermarketName.toLowerCase() == canonicalName.toLowerCase()) return true;
        final cMatch = DefaultSupermarketsData.findMatch(c.supermarketName, userLat: userLat, userLng: userLng);
        return cMatch?.name.toLowerCase() == canonicalName.toLowerCase();
      });

      if (!exists) {
        final lat = match?.latitude ?? (s['latitude'] as num?)?.toDouble();
        final lng = match?.longitude ?? (s['longitude'] as num?)?.toDouble();
        double? dist;
        if (lat != null && lng != null) {
          dist = LocationService.instance.calculateDistance(userLat, userLng, lat, lng);
          if (dist > radiusKm * 1000) continue;
        }
        comparisons.add(MarketComparison(
          supermarketName: canonicalName,
          latitude: lat,
          longitude: lng,
          distanceMeters: dist,
          itemsCount: 0,
          averageItemPrice: 0.0,
          cheapestCount: 0,
        ));
      }
    }

    // Garante desduplicação rigorosa: mescla variações de nome do mesmo mercado
    final Map<String, MarketComparison> deduped = {};
    for (var comp in comparisons) {
      final match = DefaultSupermarketsData.findMatch(comp.supermarketName, userLat: userLat, userLng: userLng);
      final key = (match?.name ?? comp.supermarketName).toLowerCase();
      if (!deduped.containsKey(key)) {
        deduped[key] = comp;
      } else {
        final current = deduped[key]!;
        if (comp.itemsCount > current.itemsCount) {
          deduped[key] = comp;
        }
      }
    }
    comparisons = deduped.values.toList();

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

  /// Retorna as principais ofertas ou itens cadastrados de um supermercado específico
  Future<List<CommunityPrice>> getTopDealsForMarket(
    String marketName, {
    int limit = 6,
    double? userLat,
    double? userLng,
  }) async {
    final cleanMarket = marketName.trim().toLowerCase();
    final allPrices = await getRecentFeed(userLat: userLat, userLng: userLng, radiusKm: 50.0);
    final marketPrices = allPrices.where((p) => p.supermarketName.trim().toLowerCase() == cleanMarket).toList();

    // Remove produtos duplicados pelo nome, mantendo o menor preço
    final Map<String, CommunityPrice> uniqueByName = {};
    for (var p in marketPrices) {
      final k = p.productName.trim().toLowerCase();
      if (!uniqueByName.containsKey(k) || p.price < uniqueByName[k]!.price) {
        uniqueByName[k] = p;
      }
    }

    final result = uniqueByName.values.toList();
    result.sort((a, b) => a.price.compareTo(b.price));
    if (result.length > limit) {
      return result.sublist(0, limit);
    }
    return result;
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

  /// Retorna a lista comparativa de todos os produtos distintos monitorados na comunidade
  Future<List<ProductComparison>> getAllProductComparisons({
    double? userLat,
    double? userLng,
    double radiusKm = 25.0,
    String? query,
  }) async {
    final prices = await getRecentFeed(userLat: userLat, userLng: userLng, radiusKm: radiusKm, query: query);
    if (prices.isEmpty) return [];

    final Map<String, List<CommunityPrice>> grouped = {};
    for (var p in prices) {
      final key = p.productName.toLowerCase().trim();
      grouped.putIfAbsent(key, () => []).add(p);
    }

    final List<ProductComparison> result = [];
    for (var entry in grouped.entries) {
      final list = entry.value;
      list.sort((a, b) => a.price.compareTo(b.price));

      double sum = 0;
      for (var p in list) {
        sum += p.price;
      }

      final minPrice = list.first.price;
      final maxPrice = list.last.price;
      final avgPrice = sum / list.length;
      final cheapest = list.first;
      final mostExpensive = list.last;

      result.add(ProductComparison(
        productName: cheapest.productName,
        unit: cheapest.unit ?? 'un',
        averagePrice: avgPrice,
        minPrice: minPrice,
        maxPrice: maxPrice,
        cheapestMarket: cheapest.supermarketName,
        cheapestMarketDistance: cheapest.distanceMeters,
        mostExpensiveMarket: mostExpensive.supermarketName,
        totalQuotes: list.length,
        prices: list,
      ));
    }

    // Ordena alfabeticamente pelo nome do produto
    result.sort((a, b) => a.productName.toLowerCase().compareTo(b.productName.toLowerCase()));
    return result;
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
grant all on table community_prices to anon, authenticated;
drop policy if exists "Permitir leitura pública" on community_prices;
drop policy if exists "Permitir inserção pública" on community_prices;
create policy "Permitir leitura pública" on community_prices for select to anon, authenticated using (true);
create policy "Permitir inserção pública" on community_prices for insert to anon, authenticated with check (true);
''';
  }
}

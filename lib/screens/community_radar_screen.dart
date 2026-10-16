import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/community_price.dart';
import '../providers/item_provider.dart';
import '../services/community_price_service.dart';
import '../services/location_service.dart';
import '../services/utils.dart';

class CommunityRadarScreen extends StatefulWidget {
  const CommunityRadarScreen({super.key});

  @override
  State<CommunityRadarScreen> createState() => _CommunityRadarScreenState();
}

class _CommunityRadarScreenState extends State<CommunityRadarScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  double _radiusKm = 15.0;
  bool _isLoading = false;
  double? _userLat;
  double? _userLng;

  List<MarketComparison> _marketRankings = [];
  List<CommunityPrice> _recentFeed = [];
  ProductComparison? _searchedProduct;
  List<CommunityPrice> _myProducts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLocationAndData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationAndData() async {
    setState(() => _isLoading = true);

    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos != null) {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      }
    } catch (_) {}

    await _fetchData();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchData() async {
    final provider = Provider.of<ItemProvider>(context, listen: false);
    final fallbackMarket = provider.selectedSupermarketFilter ?? provider.detectedSupermarket?['name'];

    final lat = _userLat ?? -23.5505; // Fallback SP se sem GPS
    final lng = _userLng ?? -46.6333;

    final markets = await CommunityPriceService.instance.getCheapestMarketsNearby(
      userLat: lat,
      userLng: lng,
      radiusKm: _radiusKm,
    );

    final feed = await CommunityPriceService.instance.getRecentFeed(
      userLat: _userLat,
      userLng: _userLng,
      radiusKm: _radiusKm,
      query: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
    );

    ProductComparison? prodComp;
    if (_searchController.text.trim().isNotEmpty) {
      prodComp = await CommunityPriceService.instance.getProductComparison(
        _searchController.text.trim(),
        userLat: _userLat,
        userLng: _userLng,
        radiusKm: _radiusKm,
      );
    }

    final myProds = await CommunityPriceService.instance.getUserRegisteredPrices(
      fallbackSupermarket: fallbackMarket,
      fallbackLat: _userLat,
      fallbackLng: _userLng,
      priceHistoryCache: provider.priceHistoryCache,
    );

    if (mounted) {
      setState(() {
        _marketRankings = markets;
        _recentFeed = feed;
        _searchedProduct = prodComp;
        _myProducts = myProds;
      });
    }
  }

  void _onSearchChanged(String val) async {
    if (val.trim().isEmpty) {
      setState(() => _searchedProduct = null);
      _fetchData();
      return;
    }

    final comp = await CommunityPriceService.instance.getProductComparison(
      val.trim(),
      userLat: _userLat,
      userLng: _userLng,
      radiusKm: _radiusKm,
    );

    if (mounted) {
      setState(() => _searchedProduct = comp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final cardColor = Theme.of(context).cardColor;
    final itemProvider = Provider.of<ItemProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.radar_rounded, size: 24),
            SizedBox(width: 8),
            Text('Radar de Preços', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        centerTitle: false,
        actions: [
          PopupMenuButton<double>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.near_me_outlined, size: 16, color: primaryColor),
                const SizedBox(width: 4),
                Text('${_radiusKm.toInt()}km', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            tooltip: 'Raio de Busca (GPS)',
            onSelected: (val) {
              setState(() => _radiusKm = val);
              _fetchData();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 5.0, child: Text('Raio de 5 km')),
              const PopupMenuItem(value: 10.0, child: Text('Raio de 10 km')),
              const PopupMenuItem(value: 15.0, child: Text('Raio de 15 km')),
              const PopupMenuItem(value: 30.0, child: Text('Raio de 30 km')),
            ],
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _myProducts.isNotEmpty,
              label: Text('${_myProducts.length}'),
              child: const Icon(Icons.playlist_add_check_rounded),
            ),
            tooltip: 'Meus Produtos para a Comunidade',
            onPressed: () => _showMyProductsModal(context, itemProvider),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocationAndData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.storefront_rounded, size: 20), text: 'Mercados'),
            Tab(icon: Icon(Icons.compare_arrows_rounded, size: 20), text: 'Comparador'),
            Tab(icon: Icon(Icons.dynamic_feed_rounded, size: 20), text: 'Feed'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMarketsTab(isDark, cardColor, primaryColor),
                _buildComparatorTab(isDark, cardColor, primaryColor, itemProvider),
                _buildFeedTab(isDark, cardColor, primaryColor, itemProvider),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPriceDialog(context, itemProvider),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Colaborar Preço', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==========================================
  // --- ABA 1: RANKING DE MERCADOS ---
  // ==========================================
  Widget _buildMarketsTab(bool isDark, Color cardColor, Color primary) {
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);

    if (_marketRankings.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMyProductsBanner(primary, cardColor, itemProvider),
          const SizedBox(height: 24),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('Nenhum mercado com preços no raio selecionado.', style: TextStyle(color: Colors.grey, fontSize: 15)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _radiusKm = 30.0);
                    _fetchData();
                  },
                  icon: const Icon(Icons.near_me),
                  label: const Text('Expandir raio para 30 km'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final cheapest = _marketRankings.firstWhere((m) => m.isCheapest, orElse: () => _marketRankings.first);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMyProductsBanner(primary, cardColor, itemProvider),
        // Card do Mercado Campeão em Economia
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, primary.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🏆 ', style: TextStyle(fontSize: 14)),
                        Text('MAIS ECONÔMICO DA REGIÃO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (cheapest.formattedDistance.isNotEmpty)
                    Text('📍 ${cheapest.formattedDistance}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                cheapest.supermarketName,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Preço médio dos itens: ${Utils.formatCurrency(cheapest.averageItemPrice)}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Lidera como menor preço em ${cheapest.cheapestCount} de ${cheapest.itemsCount} produtos monitorados',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Text(
          'Comparativo de Todos os Mercados Próximos',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        ..._marketRankings.map((market) {
          final isBest = market.isCheapest;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: isBest ? Border.all(color: Colors.greenAccent.shade700, width: 1.5) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isBest ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                  child: Icon(
                    isBest ? Icons.savings_rounded : Icons.store_rounded,
                    color: isBest ? Colors.green : Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              market.supermarketName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (market.formattedDistance.isNotEmpty)
                            Text(
                              market.formattedDistance,
                              style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Média: ${Utils.formatCurrency(market.averageItemPrice)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '• ${market.itemsCount} produtos',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isBest)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Menor Preço', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }

  // ==========================================
  // --- ABA 2: COMPARADOR DE PRODUTOS ---
  // ==========================================
  Widget _buildComparatorTab(bool isDark, Color cardColor, Color primary, ItemProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Barra de Pesquisa
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Pesquise um produto (ex: Arroz, Leite, Café)...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            filled: true,
            fillColor: cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Atalhos de produtos rápidos
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Arroz', 'Feijão', 'Leite', 'Café', 'Óleo', 'Açúcar', 'Sabão'].map((item) {
              final isSelected = _searchController.text.toLowerCase() == item.toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(item),
                  selected: isSelected,
                  onSelected: (selected) {
                    _searchController.text = selected ? item : '';
                    _onSearchChanged(_searchController.text);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        if (_searchedProduct != null) ...[
          // Card de Resumo do Produto Pesquisado
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _searchedProduct!.productName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_searchedProduct!.maxSavingsPercent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Economia de até ${_searchedProduct!.maxSavingsPercent.toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildStatBox('Média Regional', Utils.formatCurrency(_searchedProduct!.averagePrice), Colors.blueAccent),
                    const SizedBox(width: 10),
                    _buildStatBox('Menor Preço', Utils.formatCurrency(_searchedProduct!.minPrice), Colors.green),
                    const SizedBox(width: 10),
                    _buildStatBox('Maior Preço', Utils.formatCurrency(_searchedProduct!.maxPrice), Colors.redAccent),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '💡 Mais barato em: ${_searchedProduct!.cheapestMarket}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Preços por Supermercado:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          ..._searchedProduct!.prices.map((p) {
            final isBest = p.price == _searchedProduct!.minPrice;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: isBest ? Border.all(color: Colors.green, width: 1.5) : null,
              ),
              child: Row(
                children: [
                  Icon(isBest ? Icons.check_circle_rounded : Icons.store_rounded, color: isBest ? Colors.green : Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.supermarketName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Row(
                          children: [
                            if (p.formattedDistance.isNotEmpty)
                              Text('📍 ${p.formattedDistance} • ', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                            Text(Utils.formatDate(p.createdAt), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                            if (p.verifiedReceipt) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 12, color: Colors.blueAccent),
                              const Text(' Nota Fiscal', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Utils.formatCurrency(p.price),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isBest ? Colors.green : null,
                    ),
                  ),
                ],
              ),
            );
          }),
        ] else ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.manage_search_rounded, size: 54, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text('Digite um produto acima para ver a média e qual mercado vende mais barato.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // --- ABA 3: FEED AO VIVO ---
  // ==========================================
  Widget _buildFeedTab(bool isDark, Color cardColor, Color primary, ItemProvider provider) {
    if (_recentFeed.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMyProductsBanner(primary, cardColor, provider),
          const SizedBox(height: 24),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dynamic_feed_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhum preço registrado ainda na região',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Os preços aparecem aqui automaticamente conforme as compras forem realizadas nas listas ou notas fiscais forem escaneadas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final hasBanner = _myProducts.isNotEmpty;
    final bannerOffset = hasBanner ? 1 : 0;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentFeed.length + bannerOffset + 1,
      itemBuilder: (ctx, i) {
        if (hasBanner && i == 0) {
          return _buildMyProductsBanner(primary, cardColor, provider);
        }

        final feedIndex = hasBanner ? i - 1 : i;

        if (feedIndex == _recentFeed.length) {
          return const SizedBox(height: 80);
        }

        final item = _recentFeed[feedIndex];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.productName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Text(
                    Utils.formatCurrency(item.price),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.storefront_rounded, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.supermarketName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.formattedDistance.isNotEmpty)
                    Text('📍 ${item.formattedDistance}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Por: ${item.submittedBy}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      if (item.verifiedReceipt) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, size: 14, color: Colors.blueAccent),
                        const Text(' Verificado por Nota', style: TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                  Text(
                    Utils.formatDate(item.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // --- MODAL DE COLABORAÇÃO DE PREÇO ---
  // ==========================================
  void _showAddPriceDialog(BuildContext context, ItemProvider provider) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final marketCtrl = TextEditingController(
      text: provider.detectedSupermarket?['name'] ?? provider.selectedSupermarketFilter ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.add_shopping_cart_rounded, color: Colors.green),
            SizedBox(width: 10),
            Text('Colaborar com Preço', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome do Produto (ex: Leite Integral 1L)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Preço (R\$)', prefixText: 'R\$ '),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: marketCtrl,
              decoration: const InputDecoration(labelText: 'Supermercado'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
              final market = marketCtrl.text.trim();

              if (name.isNotEmpty && price > 0 && market.isNotEmpty) {
                Navigator.pop(ctx);
                await CommunityPriceService.instance.publishPrice(
                  productName: name,
                  price: price,
                  supermarketName: market,
                  latitude: _userLat,
                  longitude: _userLng,
                  submittedBy: provider.activeUserDisplayName,
                  verifiedReceipt: false,
                );
                _fetchData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Obrigado! Seu preço foi compartilhado com a comunidade.')),
                  );
                }
              }
            },
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // --- BANNER & MODAL: MEUS PRODUTOS ---
  // ==========================================
  Widget _buildMyProductsBanner(Color primary, Color cardColor, ItemProvider provider) {
    if (_myProducts.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.playlist_add_check_rounded, color: primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usar Minhas Compras como Base',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_myProducts.length} produtos com preço nas suas listas.',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _showMyProductsModal(context, provider),
            child: const Text('Ver Lista'),
          ),
        ],
      ),
    );
  }

  void _showMyProductsModal(BuildContext context, ItemProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final cardColor = isDark ? Colors.grey[850]! : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isPublishing = false;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Meus Produtos para a Comunidade',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_myProducts.length} itens encontrados nas suas compras e listas',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Estes produtos foram encontrados nas suas compras salvas no celular. Ao publicar, eles servirão de base para o ranking de preços da comunidade na nuvem.',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _myProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_bag_outlined, size: 56, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                const Text(
                                  'Nenhum produto com preço registrado nas suas listas.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _myProducts.length,
                            itemBuilder: (itemCtx, index) {
                              final item = _myProducts[index];
                              return Card(
                                color: cardColor,
                                elevation: 0.5,
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  leading: CircleAvatar(
                                    backgroundColor: primary.withValues(alpha: 0.15),
                                    child: Icon(Icons.shopping_cart_outlined, color: primary, size: 20),
                                  ),
                                  title: Text(
                                    item.productName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Icon(Icons.store_outlined, size: 13, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          item.supermarketName,
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    Utils.formatCurrency(item.price),
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (_myProducts.isNotEmpty)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: isPublishing
                                ? null
                                : () async {
                                    final nav = Navigator.of(modalCtx);
                                    final messenger = ScaffoldMessenger.of(context);

                                    setModalState(() => isPublishing = true);
                                    final count = await CommunityPriceService.instance.publishPricesBatch(_myProducts);

                                    nav.pop();
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('🎉 $count produtos publicados na comunidade com sucesso!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );

                                    if (mounted) {
                                      _fetchData();
                                    }
                                  },
                            icon: isPublishing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.cloud_upload_outlined),
                            label: Text(
                              isPublishing
                                  ? 'Publicando na Nuvem...'
                                  : 'Publicar Todos na Nuvem (${_myProducts.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
      },
    );
  }
}

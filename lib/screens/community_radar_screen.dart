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
  final TextEditingController _listSearchController = TextEditingController();

  double _radiusKm = 15.0;
  bool _isLoading = false;
  double? _userLat;
  double? _userLng;

  List<MarketComparison> _marketRankings = [];
  List<CommunityPrice> _recentFeed = [];
  List<ProductComparison> _allComparisons = [];
  ProductComparison? _searchedProduct;
  String _selectedCategory = 'Todos';
  String _selectedMarketFilter = 'Todos';

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
    _listSearchController.dispose();
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
    final lat = _userLat ?? CommunityPriceService.defaultStoreLat;
    final lng = _userLng ?? CommunityPriceService.defaultStoreLng;

    final markets = await CommunityPriceService.instance.getCheapestMarketsNearby(
      userLat: lat,
      userLng: lng,
      radiusKm: _radiusKm,
    );

    final feed = await CommunityPriceService.instance.getRecentFeed(
      userLat: lat,
      userLng: lng,
      radiusKm: _radiusKm,
    );

    final allComps = await CommunityPriceService.instance.getAllProductComparisons(
      userLat: lat,
      userLng: lng,
      radiusKm: _radiusKm,
    );

    ProductComparison? prodComp;
    if (_searchController.text.trim().isNotEmpty) {
      prodComp = await CommunityPriceService.instance.getProductComparison(
        _searchController.text.trim(),
        userLat: lat,
        userLng: lng,
        radiusKm: _radiusKm,
      );
    }

    if (mounted) {
      setState(() {
        _marketRankings = markets;
        _recentFeed = feed;
        _allComparisons = allComps;
        _searchedProduct = prodComp;
      });
    }
  }

  void _onSearchChanged(String val) async {
    final lat = _userLat ?? CommunityPriceService.defaultStoreLat;
    final lng = _userLng ?? CommunityPriceService.defaultStoreLng;

    if (val.trim().isEmpty) {
      setState(() {
        _searchedProduct = null;
      });
      return;
    }

    final comp = await CommunityPriceService.instance.getProductComparison(
      val.trim(),
      userLat: lat,
      userLng: lng,
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
            Tab(icon: Icon(Icons.format_list_bulleted_rounded, size: 20), text: 'Lista'),
            Tab(icon: Icon(Icons.compare_arrows_rounded, size: 20), text: 'Comparador'),
            Tab(icon: Icon(Icons.storefront_rounded, size: 20), text: 'Mercados'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildListTab(isDark, cardColor, primaryColor, itemProvider),
                _buildComparatorTab(isDark, cardColor, primaryColor, itemProvider),
                _buildMarketsTab(isDark, cardColor, primaryColor),
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
    if (_marketRankings.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
  // --- ABA 1: LISTA DE PREÇOS (PRODUTOS) ---
  // ==========================================
  Widget _buildListTab(bool isDark, Color cardColor, Color primary, ItemProvider provider) {
    final categories = [
      'Todos',
      'Alimentos',
      'Mercearia',
      'Açougue e Frios',
      'Laticínios e Refrigerados',
      'Limpeza',
      'Higiene Pessoal',
      'Bebidas',
      'Hortifruti',
      'Outros',
    ];

    final query = _listSearchController.text.trim().toLowerCase();
    final filteredFeed = _recentFeed.where((item) {
      if (_selectedCategory != 'Todos') {
        final cat = item.category ?? 'Outros';
        if (cat.toLowerCase() != _selectedCategory.toLowerCase()) {
          return false;
        }
      }
      if (query.isNotEmpty) {
        if (!item.productName.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Barra de Pesquisa na Lista
        TextField(
          controller: _listSearchController,
          onChanged: (val) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Pesquise na lista de produtos...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _listSearchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _listSearchController.clear();
                      setState(() {});
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
        const SizedBox(height: 12),

        // Filtro horizontal de Categorias
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Header Informativo do Supermercados Guanabara
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE53935),
                radius: 18,
                child: Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Supermercados Guanabara • Niterói',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${filteredFeed.length} produtos monitorados • Centro, Niterói - RJ',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_done_rounded, color: Colors.green, size: 14),
                    SizedBox(width: 4),
                    Text('Ao Vivo', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (filteredFeed.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 54, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text('Nenhum produto encontrado para este filtro.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          ...filteredFeed.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                onTap: () {
                  _searchController.text = item.productName;
                  _onSearchChanged(item.productName);
                  _tabController.animateTo(1);
                },
                leading: CircleAvatar(
                  backgroundColor: primary.withValues(alpha: 0.12),
                  child: Icon(Icons.shopping_bag_outlined, color: primary, size: 20),
                ),
                title: Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.storefront_rounded, size: 13, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.supermarketName,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (item.category != null && item.category!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.category!,
                              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                            ),
                          ),
                        Text(
                          Utils.formatDate(item.createdAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        if (item.verifiedReceipt) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 12, color: Colors.blueAccent),
                          const Text(' NF', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Utils.formatCurrency(item.price),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        Text(
                          '/ ${item.unit ?? "un"}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
                  ],
                ),
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
    // 1. Extrai a lista de supermercados únicos disponíveis para o filtro
    final List<String> availableMarkets = ['Todos'];
    final Set<String> seenMarkets = {};
    for (var m in _marketRankings) {
      final name = m.supermarketName.trim();
      if (name.isNotEmpty && !seenMarkets.contains(name.toLowerCase())) {
        seenMarkets.add(name.toLowerCase());
        availableMarkets.add(name);
      }
    }
    for (var p in _recentFeed) {
      final name = p.supermarketName.trim();
      if (name.isNotEmpty && !seenMarkets.contains(name.toLowerCase())) {
        seenMarkets.add(name.toLowerCase());
        availableMarkets.add(name);
      }
    }
    if (!seenMarkets.contains(CommunityPriceService.defaultStoreName.toLowerCase())) {
      availableMarkets.add(CommunityPriceService.defaultStoreName);
    }

    // 2. Filtra os produtos comparados pelo supermercado selecionado
    final filteredByMarket = _selectedMarketFilter == 'Todos'
        ? _allComparisons
        : _allComparisons.where((c) {
            final filter = _selectedMarketFilter.toLowerCase();
            return c.cheapestMarket.toLowerCase() == filter ||
                   c.prices.any((p) => p.supermarketName.toLowerCase() == filter);
          }).toList();

    // 3. Filtra pelo texto de pesquisa
    final query = _searchController.text.trim().toLowerCase();
    final displayedComparisons = query.isEmpty
        ? filteredByMarket
        : filteredByMarket.where((c) => c.productName.toLowerCase().contains(query)).toList();

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
        const SizedBox(height: 14),

        // Filtro por Supermercados
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: availableMarkets.map((market) {
              final isSelected = _selectedMarketFilter == market;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: Icon(
                    market == 'Todos' ? Icons.store_mall_directory_outlined : Icons.storefront_rounded,
                    size: 16,
                    color: isSelected ? Colors.white : primary,
                  ),
                  label: Text(market == 'Todos' ? 'Todos os Mercados' : market),
                  selected: isSelected,
                  selectedColor: primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedMarketFilter = selected ? market : 'Todos';
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),

        // Se nenhum produto foi selecionado ainda, mostra um card explicativo amigável
        if (_searchedProduct == null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded, color: primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compare os Preços dos Mercados',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Toque em qualquer produto abaixo para abrir a comparação detalhada de preços entre os supermercados.',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // Card do Produto Selecionado
        if (_searchedProduct != null) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primary.withValues(alpha: 0.35), width: 1.5),
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
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Fechar detalhes',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _searchedProduct = null;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _searchedProduct!.maxSavingsPercent > 0
                        ? 'Economia de até ${_searchedProduct!.maxSavingsPercent.toStringAsFixed(0)}%'
                        : 'Melhor Preço Registrado',
                    style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildStatBox('Média', Utils.formatCurrency(_searchedProduct!.averagePrice), Colors.blueAccent),
                    const SizedBox(width: 8),
                    _buildStatBox('Menor Preço', Utils.formatCurrency(_searchedProduct!.minPrice), Colors.green),
                    const SizedBox(width: 8),
                    _buildStatBox('Maior Preço', Utils.formatCurrency(_searchedProduct!.maxPrice), Colors.redAccent),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '💡 Mais vantajoso em: ${_searchedProduct!.cheapestMarket}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Preços por Supermercado:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // Agrupamento por supermercado único (elimina repetições absurdas!)
          ..._buildGroupedMarketCards(_searchedProduct!, cardColor),
          const SizedBox(height: 20),
        ],

        // --- LISTA DE PRODUTOS COMPARADOS ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedMarketFilter == 'Todos'
                  ? 'Todos os Produtos Comparados'
                  : 'Produtos em $_selectedMarketFilter',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${displayedComparisons.length} itens',
                style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ...displayedComparisons.map((comp) {
          final isSelected = _searchedProduct?.productName.toLowerCase() == comp.productName.toLowerCase();
          return InkWell(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _searchedProduct = null;
                } else {
                  _searchedProduct = comp;
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: isSelected ? Border.all(color: primary, width: 2) : null,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isSelected ? primary.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.12),
                    child: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.compare_arrows_rounded,
                      color: isSelected ? primary : Colors.grey[700],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comp.productName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: isSelected ? primary : null,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '💡 ${comp.cheapestMarket}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Utils.formatCurrency(comp.minPrice),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                      ),
                      if (comp.totalQuotes > 1)
                        Text(
                          'Média: ${Utils.formatCurrency(comp.averagePrice)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }

  List<Widget> _buildGroupedMarketCards(ProductComparison prod, Color cardColor) {
    final Map<String, List<CommunityPrice>> marketGroups = {};
    for (var p in prod.prices) {
      final mName = p.supermarketName.trim();
      if (mName.isNotEmpty) {
        marketGroups.putIfAbsent(mName, () => []).add(p);
      }
    }

    if (marketGroups.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Nenhum supermercado registrado com preço para este produto.', style: TextStyle(color: Colors.grey)),
        ),
      ];
    }

    final List<Widget> widgets = [];
    for (var entry in marketGroups.entries) {
      final marketName = entry.key;
      final quotes = entry.value;

      quotes.sort((a, b) => a.price.compareTo(b.price));
      final lowest = quotes.first;
      final highest = quotes.last;
      final isBest = lowest.price <= prod.minPrice;
      final hasVariation = quotes.length > 1 && (highest.price - lowest.price).abs() > 0.01;

      quotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final latest = quotes.first;

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: isBest ? Border.all(color: Colors.green, width: 1.5) : null,
          ),
          child: Row(
            children: [
              Icon(
                isBest ? Icons.check_circle_rounded : Icons.store_rounded,
                color: isBest ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marketName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (latest.formattedDistance.isNotEmpty)
                          Text('📍 ${latest.formattedDistance} • ', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                        Text(
                          quotes.length > 1
                              ? '${quotes.length} compras registradas'
                              : Utils.formatDate(latest.createdAt),
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                        if (quotes.any((q) => q.verifiedReceipt)) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 12, color: Colors.blueAccent),
                          const Text(' NF', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                    if (hasVariation) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Variação: ${Utils.formatCurrency(lowest.price)} a ${Utils.formatCurrency(highest.price)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 10.5, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Utils.formatCurrency(lowest.price),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isBest ? Colors.green : null,
                    ),
                  ),
                  Text(
                    quotes.length > 1 ? 'menor preço' : '/ ${lowest.unit ?? "un"}',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
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
  // --- MODAL DE COLABORAÇÃO DE PREÇO ---
  // ==========================================
  void _showAddPriceDialog(BuildContext context, ItemProvider provider) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final marketCtrl = TextEditingController(
      text: provider.detectedSupermarket?['name'] ?? provider.selectedSupermarketFilter ?? CommunityPriceService.defaultStoreName,
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
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/community_price.dart';
import '../services/community_price_service.dart';
import '../services/location_service.dart';
import '../services/utils.dart';
import '../services/default_supermarkets.dart';

class MarketMapScreen extends StatefulWidget {
  final double? initialUserLat;
  final double? initialUserLng;
  final double initialRadiusKm;
  final String? initialFocusMarket;

  const MarketMapScreen({
    super.key,
    this.initialUserLat,
    this.initialUserLng,
    this.initialRadiusKm = 15.0,
    this.initialFocusMarket,
  });

  @override
  State<MarketMapScreen> createState() => _MarketMapScreenState();
}

class _MarketMapScreenState extends State<MarketMapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late PageController _cardsPageController;

  double _radiusKm = 15.0;
  bool _isLoading = true;
  LatLng _userPosition = const LatLng(CommunityPriceService.defaultStoreLat, CommunityPriceService.defaultStoreLng);
  bool _hasRealGps = false;

  List<MarketComparison> _markets = [];
  MarketComparison? _selectedMarket;
  List<CommunityPrice> _selectedMarketDeals = [];
  bool _isLoadingDeals = false;

  bool _showRadiusCircle = true;

  @override
  void initState() {
    super.initState();
    _radiusKm = widget.initialRadiusKm;
    _cardsPageController = PageController(viewportFraction: 0.86);

    if (widget.initialUserLat != null && widget.initialUserLng != null) {
      _userPosition = LatLng(widget.initialUserLat!, widget.initialUserLng!);
      _hasRealGps = true;
    }

    _initMapAndLoadData();
  }

  @override
  void dispose() {
    _cardsPageController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initMapAndLoadData() async {
    setState(() => _isLoading = true);

    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos != null) {
        _userPosition = LatLng(pos.latitude, pos.longitude);
        _hasRealGps = true;
      }
    } catch (_) {}

    await _loadMarkets();

    if (mounted) {
      setState(() => _isLoading = false);

      // Se havia um mercado inicial especificado, foca nele
      if (widget.initialFocusMarket != null) {
        final match = _markets.firstWhere(
          (m) => m.supermarketName.toLowerCase() == widget.initialFocusMarket!.toLowerCase(),
          orElse: () => _markets.first,
        );
        _selectMarket(match);
      } else if (_markets.isNotEmpty) {
        // Encontra o mais barato ou centraliza no usuário
        _centerOnUser();
      }
    }
  }

  Future<void> _loadMarkets() async {
    final list = await CommunityPriceService.instance.getCheapestMarketsNearby(
      userLat: _userPosition.latitude,
      userLng: _userPosition.longitude,
      radiusKm: _radiusKm,
    );

    // Filtra apenas aqueles que possuem coordenadas válidas
    final withCoords = list.where((m) => m.latitude != null && m.longitude != null).toList();

    if (mounted) {
      setState(() {
        _markets = withCoords;
      });
    }
  }

  void _centerOnUser() {
    _mapController.move(_userPosition, 14.0);
  }

  void _selectMarket(MarketComparison market) {
    setState(() {
      _selectedMarket = market;
    });

    if (market.latitude != null && market.longitude != null) {
      _mapController.move(LatLng(market.latitude!, market.longitude!), 15.5);
    }

    final index = _markets.indexOf(market);
    if (index != -1 && _cardsPageController.hasClients) {
      _cardsPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    _loadDealsForMarket(market.supermarketName);
    _showMarketBottomSheet(market);
  }

  Future<void> _loadDealsForMarket(String marketName) async {
    setState(() => _isLoadingDeals = true);
    final deals = await CommunityPriceService.instance.getTopDealsForMarket(
      marketName,
      limit: 6,
      userLat: _userPosition.latitude,
      userLng: _userPosition.longitude,
    );
    if (mounted) {
      setState(() {
        _selectedMarketDeals = deals;
        _isLoadingDeals = false;
      });
    }
  }

  void _fitAllMarkers() {
    if (_markets.isEmpty) {
      _centerOnUser();
      return;
    }

    final points = <LatLng>[_userPosition];
    for (var m in _markets) {
      if (m.latitude != null && m.longitude != null) {
        points.add(LatLng(m.latitude!, m.longitude!));
      }
    }

    if (points.length == 1) {
      _mapController.move(points.first, 14.0);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.only(top: 120, bottom: 200, left: 40, right: 40),
      ),
    );
  }

  void _openSearchDialog() {
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).cardColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filterText = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _markets.where((m) {
              if (filterText.isEmpty) return true;
              return m.supermarketName.toLowerCase().contains(filterText.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 12,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar mercado, bairro (ex: Tribobó, Rio do Ouro, Inoã)...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: primary),
                      filled: true,
                      fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        filterText = val.trim();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${filtered.length} mercados encontrados',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('Nenhum supermercado encontrado com este termo.'),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final pre = DefaultSupermarketsData.findMatch(item.supermarketName);
                              final addr = pre?.address;
                              final distText = item.formattedDistance.isNotEmpty ? item.formattedDistance : '';
                              final sub = [if (distText.isNotEmpty) distText, if (addr != null && addr.isNotEmpty) addr].join(' • ');

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: primary.withValues(alpha: 0.15),
                                  child: Icon(Icons.storefront_rounded, color: primary),
                                ),
                                title: Text(
                                  item.supermarketName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Text(
                                  sub.isNotEmpty ? sub : 'Coordenadas salvas',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _selectMarket(item);
                                },
                              );
                            },
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

  Future<void> _openNavigation(double lat, double lng, String name) async {
    final Uri geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(name)})');
    final Uri webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o aplicativo de mapas.')),
      );
    }
  }

  void _showMarketBottomSheet(MarketComparison market) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final cardColor = Theme.of(context).cardColor;
    final isCheapest = market.isCheapest;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle indicator
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header do Mercado
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: isCheapest
                                ? const LinearGradient(
                                    colors: [Color(0xFFFFA000), Color(0xFFFF6F00)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : LinearGradient(
                                    colors: [primary, primary.withValues(alpha: 0.8)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: (isCheapest ? const Color(0xFFFFA000) : primary).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            isCheapest ? Icons.workspace_premium_rounded : Icons.storefront_rounded,
                            color: Colors.white,
                            size: 28,
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
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCheapest)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFA000).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFFA000), width: 1),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('👑 ', style: TextStyle(fontSize: 10)),
                                          Text(
                                            'Mais Barato',
                                            style: TextStyle(
                                              color: Color(0xFFE65100),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (market.formattedDistance.isNotEmpty) ...[
                                    Icon(Icons.near_me_rounded, size: 13, color: primary),
                                    const SizedBox(width: 3),
                                    Text(
                                      market.formattedDistance,
                                      style: TextStyle(fontSize: 13, color: primary, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  if (market.itemsCount > 0)
                                    Text(
                                      '• ${market.itemsCount} produtos monitorados',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    )
                                  else
                                    Text(
                                      '• Mercado cadastrado',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                ],
                              ),
                              if (DefaultSupermarketsData.findMatch(market.supermarketName)?.address != null) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade500),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        DefaultSupermarketsData.findMatch(market.supermarketName)!.address!,
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, indent: 20, endIndent: 20),

                  // Preço Médio e Estatísticas
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Preço Médio', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  market.averageItemPrice > 0 ? Utils.formatCurrency(market.averageItemPrice) : '--',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isCheapest ? Colors.green.shade700 : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Itens Campeões', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  '${market.cheapestCount} menores preços',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Ofertas em Destaque no Mercado
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Preços Registrados',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (_isLoadingDeals)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),

                  // Lista de Ofertas
                  Expanded(
                    child: _isLoadingDeals
                        ? const Center(child: CircularProgressIndicator())
                        : _selectedMarketDeals.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Nenhum preço individual cadastrado recentemente para este mercado.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: _selectedMarketDeals.length,
                                itemBuilder: (ctx, idx) {
                                  final deal = _selectedMarketDeals[idx];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.shopping_bag_outlined, size: 18, color: primary),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            deal.productName,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          Utils.formatCurrency(deal.price),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),

                  // Botões de Ação
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                // Fecha o mapa e retorna com o mercado selecionado para o Radar
                                Navigator.pop(context, market.supermarketName);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.radar_rounded, size: 20),
                              label: const Text('Ver no Radar', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (market.latitude != null && market.longitude != null) {
                                  _openNavigation(market.latitude!, market.longitude!, market.supermarketName);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.directions_rounded, size: 20),
                              label: const Text('Como Chegar', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final cardColor = Theme.of(context).cardColor;

    final markers = <Marker>[];

    // 1. Marcador do Usuário (GPS)
    markers.add(
      Marker(
        point: _userPosition,
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.22),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade600,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.navigation_rounded, size: 13, color: Colors.white),
            ),
          ],
        ),
      ),
    );

    // 2. Marcadores dos Mercados
    for (var market in _markets) {
      if (market.latitude == null || market.longitude == null) continue;

      final isCheapest = market.isCheapest;
      final isSelected = _selectedMarket?.supermarketName == market.supermarketName;

      markers.add(
        Marker(
          point: LatLng(market.latitude!, market.longitude!),
          width: 140,
          height: 72,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _selectMarket(market),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Etiqueta com Nome e Preço
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCheapest
                        ? const Color(0xFFFFA000)
                        : (isSelected ? primary : cardColor),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCheapest
                          ? Colors.amber.shade200
                          : (isSelected ? Colors.white : primary.withValues(alpha: 0.3)),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCheapest) ...[
                        const Text('👑 ', style: TextStyle(fontSize: 11)),
                      ],
                      Flexible(
                        child: Text(
                          market.supermarketName,
                          style: TextStyle(
                            color: (isCheapest || isSelected)
                                ? Colors.white
                                : (isDark ? Colors.white : Colors.black87),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (market.averageItemPrice > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          Utils.formatCurrency(market.averageItemPrice),
                          style: TextStyle(
                            color: (isCheapest || isSelected) ? Colors.white70 : Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 2),

                // Ícone do Pin (ponto inferior)
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isCheapest
                        ? const Color(0xFFFF8F00)
                        : (isSelected ? primary : primary.withValues(alpha: 0.9)),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isCheapest ? Icons.workspace_premium_rounded : Icons.store_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Camada de Círculos (Raio de Busca no GPS)
    final circles = <CircleMarker>[];
    if (_showRadiusCircle) {
      circles.add(
        CircleMarker(
          point: _userPosition,
          radius: _radiusKm * 1000,
          useRadiusInMeter: true,
          color: primary.withValues(alpha: 0.08),
          borderColor: primary.withValues(alpha: 0.35),
          borderStrokeWidth: 2,
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 🗺️ MAPA INTERATIVO (OPENSTREETMAP)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPosition,
              initialZoom: 13.5,
              minZoom: 4,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: isDark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.lista_compras',
              ),
              CircleLayer(circles: circles),
              MarkerLayer(markers: markers),
            ],
          ),

          // 🔝 BARRA SUPERIOR (HEADER) FLUTUANTE
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Voltar',
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.radar_rounded, size: 18, color: Colors.redAccent),
                                  SizedBox(width: 6),
                                  Text(
                                    'Mapa dos Mercados',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                              Text(
                                '${_markets.length} mercados encontrados no raio',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search_rounded),
                          tooltip: 'Buscar supermercado ou bairro',
                          onPressed: _openSearchDialog,
                        ),
                        IconButton(
                          icon: Icon(
                            _showRadiusCircle ? Icons.adjust_rounded : Icons.circle_outlined,
                            color: _showRadiusCircle ? primary : Colors.grey,
                          ),
                          tooltip: 'Alternar visualização do raio',
                          onPressed: () {
                            setState(() => _showRadiusCircle = !_showRadiusCircle);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Atualizar',
                          onPressed: _initMapAndLoadData,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Chips de Raio (5km, 10km, 15km, 25km, 50km)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [5.0, 10.0, 15.0, 25.0, 50.0].map((r) {
                        final isSelected = _radiusKm == r;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            selected: isSelected,
                            showCheckmark: false,
                            label: Text(
                              '${r.toInt()} km',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                            backgroundColor: cardColor.withValues(alpha: 0.9),
                            selectedColor: primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? primary : Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _radiusKm = r);
                                _loadMarkets();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔘 BOTÕES FLUTUANTES LATERAIS (GPS & FIT)
          Positioned(
            right: 16,
            bottom: _markets.isNotEmpty ? 140 : 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'fab_fit_bounds',
                  backgroundColor: cardColor,
                  foregroundColor: primary,
                  tooltip: 'Ver todos os mercados',
                  onPressed: _fitAllMarkers,
                  child: const Icon(Icons.zoom_out_map_rounded),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'fab_my_gps',
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  tooltip: 'Minha Localização (GPS)',
                  onPressed: _centerOnUser,
                  child: Icon(_hasRealGps ? Icons.my_location_rounded : Icons.location_searching_rounded),
                ),
              ],
            ),
          ),

          // 🎠 CARROSSEL HORIZONTAL DE MERCADOS NO RODAPÉ
          if (_markets.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              height: 110,
              child: PageView.builder(
                controller: _cardsPageController,
                itemCount: _markets.length,
                onPageChanged: (idx) {
                  final m = _markets[idx];
                  setState(() => _selectedMarket = m);
                  if (m.latitude != null && m.longitude != null) {
                    _mapController.move(LatLng(m.latitude!, m.longitude!), 15.0);
                  }
                },
                itemBuilder: (ctx, idx) {
                  final m = _markets[idx];
                  final isCheapest = m.isCheapest;
                  return GestureDetector(
                    onTap: () => _selectMarket(m),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(18),
                        border: isCheapest
                            ? Border.all(color: const Color(0xFFFFA000), width: 1.8)
                            : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isCheapest
                                  ? const Color(0xFFFFA000).withValues(alpha: 0.15)
                                  : primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isCheapest ? Icons.workspace_premium_rounded : Icons.storefront_rounded,
                              color: isCheapest ? const Color(0xFFFFA000) : primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        m.supermarketName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isCheapest)
                                      const Text('👑', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (m.formattedDistance.isNotEmpty) ...[
                                      Icon(Icons.near_me_outlined, size: 12, color: primary),
                                      const SizedBox(width: 2),
                                      Text(
                                        m.formattedDistance,
                                        style: TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (m.averageItemPrice > 0)
                                      Text(
                                        'Média: ${Utils.formatCurrency(m.averageItemPrice)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isCheapest ? Colors.green.shade700 : Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Indicador de Carregamento Inicial
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Carregando mapa dos mercados...', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

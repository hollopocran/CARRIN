import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/item_provider.dart';
import '../services/utils.dart';
import '../services/location_service.dart';

/// Horizontal bar showing Month Purpose badge, Supermarket Filter Chips, and GPS trigger.
class SupermarketChipBar extends StatelessWidget {
  final ItemProvider provider;
  final VoidCallback onOpenPurpose;
  final VoidCallback onOpenRateio;

  const SupermarketChipBar({
    super.key,
    required this.provider,
    required this.onOpenPurpose,
    required this.onOpenRateio,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpose = provider.currentMonthPurpose;

    // Collect all unique supermarket names present in the current items
    final Set<String> itemMarkets = {};
    for (var it in provider.items) {
      if (it.supermarket != null && it.supermarket!.trim().isNotEmpty) {
        itemMarkets.add(it.supermarket!.trim());
      }
    }
    // Also include saved markets
    for (var m in provider.supermarkets) {
      final name = m['name']?.toString().trim();
      if (name != null && name.isNotEmpty) {
        itemMarkets.add(name);
      }
    }

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Purpose Badge
          InkWell(
            onTap: onOpenPurpose,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _getPurposeColor(purpose).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getPurposeColor(purpose).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getPurposeIcon(purpose), size: 14, color: _getPurposeColor(purpose)),
                  const SizedBox(width: 4),
                  Text(
                    _getPurposeLabel(purpose),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getPurposeColor(purpose),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // If purpose is Churrasco, show quick Rateio button
          if (purpose == 'churrasco')
            InkWell(
              onTap: onOpenRateio,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.groups_rounded, size: 14, color: Colors.deepOrange),
                    SizedBox(width: 4),
                    Text(
                      'Rateio',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                    ),
                  ],
                ),
              ),
            ),

          // "Todos" Filter Chip
          FilterChip(
            selected: provider.selectedSupermarketFilter == null,
            label: const Text('Todos Mercados', style: TextStyle(fontSize: 12)),
            onSelected: (_) => provider.clearSupermarketFilter(),
            backgroundColor: isDark ? Colors.grey[850] : Colors.grey[100],
            selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
            showCheckmark: false,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          const SizedBox(width: 6),

          // Chips for each market
          ...itemMarkets.map((market) {
            final isSelected = provider.selectedSupermarketFilter == market;
            final count = provider.items.where((it) => it.supermarket == market).length;

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                selected: isSelected,
                avatar: const Icon(Icons.storefront_outlined, size: 14),
                label: Text(
                  count > 0 ? '$market ($count)' : market,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onSelected: (val) {
                  if (isSelected) {
                    provider.clearSupermarketFilter();
                  } else {
                    provider.setSupermarketFilter(market);
                  }
                },
                backgroundColor: isDark ? Colors.grey[850] : Colors.grey[100],
                selectedColor: Colors.blue.withValues(alpha: 0.2),
                showCheckmark: false,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            );
          }),

          // Button to detect GPS / save current location
          ActionChip(
            avatar: provider.isDetectingLocation
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded, size: 14, color: Colors.blue),
            label: const Text('Detectar GPS', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
            onPressed: () => _handleGpsTap(context, provider),
            backgroundColor: Colors.blue.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ],
      ),
    );
  }

  static void _handleGpsTap(BuildContext context, ItemProvider provider) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Consultando GPS do celular...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    await provider.detectNearbySupermarket(notify: true);

    if (context.mounted) {
      if (provider.detectedSupermarket != null) {
        final name = provider.detectedSupermarket!['name'];
        final dist = provider.detectedSupermarket!['formatted_distance'] ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green[800],
            content: Text('📍 Mercado detectado: $name ($dist)! Lista filtrada.'),
          ),
        );
        provider.setSupermarketFilter(name);
      } else {
        // Offer to save current location as a new market
        showDialog(
          context: context,
          builder: (ctx) => SaveCurrentMarketDialog(provider: provider),
        );
      }
    }
  }

  static IconData _getPurposeIcon(String purpose) {
    switch (purpose) {
      case 'abastecimento':
        return Icons.inventory_2_outlined;
      case 'conveniencia':
        return Icons.bolt_rounded;
      case 'churrasco':
        return Icons.outdoor_grill_rounded;
      default:
        return Icons.shopping_cart_outlined;
    }
  }

  static String _getPurposeLabel(String purpose) {
    switch (purpose) {
      case 'abastecimento':
        return 'Abastecimento (Mês)';
      case 'conveniencia':
        return 'Reposição Rápida';
      case 'churrasco':
        return 'Churrasco & Evento';
      default:
        return 'Finalidade Geral';
    }
  }

  static Color _getPurposeColor(String purpose) {
    switch (purpose) {
      case 'abastecimento':
        return Colors.teal;
      case 'conveniencia':
        return Colors.amber[800] ?? Colors.amber;
      case 'churrasco':
        return Colors.deepOrange;
      default:
        return Colors.indigo;
    }
  }
}

/// Dialog to save the current GPS location as a new supermarket
class SaveCurrentMarketDialog extends StatefulWidget {
  final ItemProvider provider;

  const SaveCurrentMarketDialog({super.key, required this.provider});

  @override
  State<SaveCurrentMarketDialog> createState() => _SaveCurrentMarketDialogState();
}

class _SaveCurrentMarketDialogState extends State<SaveCurrentMarketDialog> {
  final _nameController = TextEditingController();
  bool _isLoading = true;
  double? _lat;
  double? _lng;
  String? _suggestedName;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null) {
      _lat = pos.latitude;
      _lng = pos.longitude;
      _suggestedName = await LocationService.instance.identifyPlaceName(pos.latitude, pos.longitude);
      if (_suggestedName != null && mounted) {
        _nameController.text = _suggestedName!;
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.add_location_alt_rounded, color: Colors.blue),
          SizedBox(width: 8),
          Text('Salvar Mercado por GPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ],
      ),
      content: _isLoading
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Obtendo coordenadas do local...', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dê um nome para este supermercado ou comércio. Nas próximas vezes, o CARRIN o reconhecerá automaticamente quando você estiver aqui.',
                  style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Nome do Supermercado',
                    hintText: 'Ex: Supermercados Guanabara, Açougue...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                if (_lat != null && _lng != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '📍 Coordenadas: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)} (Raio: 150m)',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;

                  await widget.provider.addOrUpdateSupermarket(
                    name: name,
                    latitude: _lat,
                    longitude: _lng,
                    radiusMeters: 150.0,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    widget.provider.setSupermarketFilter(name);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green,
                        content: Text('Mercado "$name" salvo com sucesso!'),
                      ),
                    );
                  }
                },
          child: const Text('Salvar Local', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// Dialog to calculate cost per person for Barbecue / Events (Rateio)
class RateioDialog extends StatefulWidget {
  final double totalSpent;
  final String listTitle;

  const RateioDialog({
    super.key,
    required this.totalSpent,
    required this.listTitle,
  });

  @override
  State<RateioDialog> createState() => _RateioDialogState();
}

class _RateioDialogState extends State<RateioDialog> {
  int _personCount = 6;
  final _pixKeyController = TextEditingController();

  @override
  void dispose() {
    _pixKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double costPerPerson = _personCount > 0 ? (widget.totalSpent / _personCount) : 0.0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Row(
        children: [
          Icon(Icons.outdoor_grill_rounded, color: Colors.deepOrange),
          SizedBox(width: 10),
          Text('Rateio do Evento', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total das Compras:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Text(Utils.formatCurrency(widget.totalSpent), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Valor por Pessoa:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(
                        Utils.formatCurrency(costPerPerson),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.deepOrange),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Número de Participantes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.remove),
                  onPressed: _personCount > 2 ? () => setState(() => _personCount--) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '$_personCount pessoas',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => _personCount++),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pixKeyController,
              decoration: InputDecoration(
                labelText: 'Sua Chave Pix (Opcional)',
                hintText: 'Ex: telefone, CPF ou e-mail',
                prefixIcon: const Icon(Icons.pix, size: 20, color: Colors.teal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.share, size: 18),
          label: const Text('Compartilhar Rateio', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            final pix = _pixKeyController.text.trim();
            final buffer = StringBuffer();
            buffer.writeln('🍖 *Rateio - ${widget.listTitle}*');
            buffer.writeln('💰 Total: ${Utils.formatCurrency(widget.totalSpent)}');
            buffer.writeln('👥 Participantes: $_personCount pessoas');
            buffer.writeln('👉 *Valor por pessoa: ${Utils.formatCurrency(costPerPerson)}*');
            if (pix.isNotEmpty) {
              buffer.writeln('\n🔑 Chave Pix: $pix');
            }
            buffer.writeln('\n_Calculado pelo CARRIN_');

            Share.share(buffer.toString());
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

/// Dialog to select Month Purpose and manage Category Budget Caps
class PurposeAndCapsDialog extends StatefulWidget {
  final ItemProvider provider;

  const PurposeAndCapsDialog({super.key, required this.provider});

  @override
  State<PurposeAndCapsDialog> createState() => _PurposeAndCapsDialogState();
}

class _PurposeAndCapsDialogState extends State<PurposeAndCapsDialog> {
  late String _selectedPurpose;
  final Map<String, TextEditingController> _capControllers = {};

  final List<Map<String, dynamic>> _purposeOptions = [
    {
      'id': 'geral',
      'title': 'Geral / Padrão',
      'desc': 'Modo padrão do CARRIN para qualquer compra.',
      'icon': Icons.shopping_cart_outlined,
      'color': Colors.indigo,
    },
    {
      'id': 'abastecimento',
      'title': 'Abastecimento do Mês',
      'desc': 'Atacarejo, foco no peso (kg) e fardos.',
      'icon': Icons.inventory_2_outlined,
      'color': Colors.teal,
    },
    {
      'id': 'conveniencia',
      'title': 'Reposição Rápida',
      'desc': 'Listas curtas, padaria, hortifrúti e caixa express.',
      'icon': Icons.bolt_rounded,
      'color': Colors.amber[800] ?? Colors.amber,
    },
    {
      'id': 'churrasco',
      'title': 'Churrasco & Eventos',
      'desc': 'Carnes, bebidas e calculadora de divisão por pessoa.',
      'icon': Icons.outdoor_grill_rounded,
      'color': Colors.deepOrange,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedPurpose = widget.provider.currentMonthPurpose;

    // Prepopulate controllers with existing category caps
    final currentCaps = widget.provider.categoryCaps;
    for (var cat in ItemProvider.categories) {
      final existing = currentCaps[cat];
      _capControllers[cat] = TextEditingController(
        text: existing != null && existing > 0 ? Utils.formatCurrencyInput(existing) : '',
      );
    }
  }

  @override
  void dispose() {
    for (var c in _capControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('Finalidade & Metas', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('FINALIDADE DA COMPRA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              ..._purposeOptions.map((opt) {
                final isSelected = _selectedPurpose == opt['id'];
                final color = opt['color'] as Color;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedPurpose = opt['id']),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? color : Colors.grey.withValues(alpha: 0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(opt['icon'] as IconData, color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(opt['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(opt['desc'], style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                          if (isSelected) Icon(Icons.check_circle, color: color, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              const Text('TRAVAS POR CATEGORIA (OPCIONAL)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(
                'Defina um teto máximo (R\$) para categorias sensíveis. O CARRIN avisará caso você passe do limite.',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              ...ItemProvider.categories.take(6).map((cat) {
                final controller = _capControllers[cat]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(cat, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          inputFormatters: [CurrencyInputFormatter()],
                          decoration: InputDecoration(
                            hintText: 'Sem limite',
                            prefixText: 'R\$ ',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () async {
            final month = widget.provider.currentMonth;
            await widget.provider.setMonthPurpose(month, _selectedPurpose);

            for (var entry in _capControllers.entries) {
              final cat = entry.key;
              final text = entry.value.text.trim();
              final amount = Utils.parseCurrency(text);
              if (amount > 0) {
                await widget.provider.setCategoryCap(month, cat, amount);
              } else {
                await widget.provider.removeCategoryCap(month, cat);
              }
            }

            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Colors.green,
                  content: Text('Finalidade e metas atualizadas com sucesso!'),
                ),
              );
            }
          },
          child: const Text('Salvar Metas', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

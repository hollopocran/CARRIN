import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
import '../widgets/counting_text.dart';
import '../services/utils.dart';

class ItemSearchDelegate extends SearchDelegate<Item?> {
  final ItemProvider provider;
  final Function(Item) onEdit;
  final Function(int) onDelete; // Recebe o index
  final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  ItemSearchDelegate(this.provider, {required this.onEdit, required this.onDelete});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  String formatNum(double val) {
    return val == val.toInt() ? val.toInt().toString() : val.toString().replaceAll('.', ',');
  }

  Widget _buildList(BuildContext context) {
    final normalizedQuery = Utils.normalize(query);
    final tokens = normalizedQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    
    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final results = provider.items.where((item) {
          if (tokens.isEmpty) return true;
          final normName = Utils.normalize(item.name);
          final normCategory = Utils.normalize(item.category);
          final barcodeStr = (item.barcode ?? '').toLowerCase().trim();

          return tokens.every((token) => 
            normName.contains(token) || 
            normCategory.contains(token) || 
            barcodeStr.contains(token)
          );
        }).toList();

        if (results.isEmpty) {
          return const Center(child: Text('Nenhum produto encontrado.'));
        }

        return ListView.builder(
          itemCount: results.length,
          addAutomaticKeepAlives: true,
          itemBuilder: (context, index) {
            final item = results[index];
            return _SearchItemTile(
              key: ValueKey('search_item_${item.index}'),
              item: item,
              provider: provider,
              onEdit: onEdit,
              onDelete: onDelete,
              currencyFormat: currencyFormat,
              formatNum: formatNum,
            );
          },
        );
      },
    );
  }
}

// Widget extraído para renderização granular e performance
class _SearchItemTile extends StatelessWidget {
  final Item item;
  final ItemProvider provider;
  final Function(Item) onEdit;
  final Function(int) onDelete;
  final NumberFormat currencyFormat;
  final String Function(double) formatNum;

  const _SearchItemTile({
    super.key,
    required this.item,
    required this.provider,
    required this.onEdit,
    required this.onDelete,
    required this.currencyFormat,
    required this.formatNum,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onEdit(item),
        child: Opacity(
          opacity: item.isBought ? 0.5 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Checkbox(
                  value: item.isBought,
                  onChanged: (val) => provider.toggleBought(item),
                  activeColor: Colors.green,
                ),
                title: Text(
                  item.name, 
                  style: TextStyle(
                    decoration: item.isBought ? TextDecoration.lineThrough : null, 
                    fontWeight: FontWeight.bold
                  )
                ),
                subtitle: Text('${item.category} • ${formatNum(item.quantity)}${item.isKg ? "kg" : " un"} x ${currencyFormat.format(item.unitPrice)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CountingText(
                      key: ValueKey('total_${item.index}_${item.totalPrice}'),
                      value: item.totalPrice,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => onDelete(item.index!),
                    ),
                  ],
                ),
              ),
              _buildPriceHistoryPreview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceHistoryPreview() {
    final history = provider.getPriceHistorySync(item.name, barcode: item.barcode);
    if (history.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(left: 72, bottom: 12, right: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: history.take(3).map((entry) {
          final price = entry['price'] as double;
          final month = (entry['month'] as String).split(' ').first;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$month: ${currencyFormat.format(price)}',
              style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          );
        }).toList(),
      ),
    );
  }
}


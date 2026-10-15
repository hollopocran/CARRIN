import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:vibration/vibration.dart';
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
  String? get searchFieldLabel => 'Buscar produto, categoria...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return theme.copyWith(
      scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
      appBarTheme: theme.appBarTheme.copyWith(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: theme.iconTheme,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: isDark ? Colors.white54 : Colors.black45,
          fontSize: 16,
        ),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: query.isNotEmpty ? 1.0 : 0.0,
        child: IconButton(
          tooltip: 'Limpar',
          icon: const Icon(Icons.close_rounded),
          onPressed: query.isEmpty ? null : () => query = '',
        ),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Voltar',
      icon: const Icon(Icons.arrow_back_rounded),
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

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: results.isEmpty
              ? _buildEmptyState(context, tokens.isEmpty)
              : _buildResultsList(context, results),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isInitial) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      key: ValueKey('empty_state_${isInitial ? "initial" : "not_found"}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, val, child) {
            return Transform.scale(
              scale: 0.9 + (0.1 * val),
              child: Opacity(
                opacity: val,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.05) 
                      : theme.primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isInitial ? Icons.search_rounded : Icons.search_off_rounded,
                  size: 36,
                  color: isDark ? Colors.white60 : theme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isInitial ? 'Pesquise seus itens' : 'Nenhum produto encontrado',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isInitial 
                    ? 'Digite o nome do produto, categoria ou código de barras.'
                    : 'Não encontramos nenhum item para "$query". Tente outro termo.',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, List<Item> results) {
    return AnimationLimiter(
      key: ValueKey('search_limiter_${query.trim()}_${results.length}'),
      child: ListView.builder(
        key: ValueKey('search_list_${query.trim()}'),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: results.length,
        addAutomaticKeepAlives: true,
        itemBuilder: (context, index) {
          final item = results[index];
          final itemKeyStr = item.index != null ? 'search_item_${item.index}' : 'search_item_${item.name}';
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 260),
            delay: const Duration(milliseconds: 20),
            child: SlideAnimation(
              verticalOffset: 20.0,
              curve: Curves.easeOutCubic,
              child: FadeInAnimation(
                curve: Curves.easeOutCubic,
                child: _SearchItemTile(
                  key: ValueKey(itemKeyStr),
                  item: item,
                  provider: provider,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  currencyFormat: currencyFormat,
                  formatNum: formatNum,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Widget de item de busca estilizado e com micro-animações fluidas
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final badgeInfo = provider.getPriceBadgeInfo(item);
    final String status = badgeInfo['status'] as String? ?? 'Novo';
    final Color statusColor = badgeInfo['color'] as Color? ?? Colors.blueGrey;
    final bool showBadge = status != 'N/A' && status != 'Novo';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        opacity: item.isBought ? 0.55 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: item.isBought
                ? (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02))
                : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isBought
                  ? Colors.transparent
                  : (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)),
              width: 1,
            ),
            boxShadow: item.isBought
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onEdit(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Checkbox com haptic feedback e animação suave
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: Checkbox(
                            value: item.isBought,
                            onChanged: (val) {
                              Vibration.vibrate(duration: 35);
                              provider.toggleBought(item);
                            },
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            activeColor: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Dados do Item: Nome com texto animado, Categoria e Detalhes
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: item.isBought
                                      ? Colors.grey
                                      : (theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black87)),
                                  decoration: item.isBought ? TextDecoration.lineThrough : TextDecoration.none,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                child: Text(item.name),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  // Categoria pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.category,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      '${formatNum(item.quantity)}${item.isKg ? "kg" : " un"} x ${currencyFormat.format(item.unitPrice)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white54 : Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Total e Status Badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            CountingText(
                              key: ValueKey('search_total_${item.index}_${item.totalPrice}'),
                              value: item.totalPrice,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (showBadge) ...[
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(width: 6),

                        // Botão Excluir com feedback tátil
                        IconButton(
                          tooltip: 'Excluir',
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          splashRadius: 20,
                          onPressed: () {
                            Vibration.vibrate(duration: 40);
                            if (item.index != null) {
                              onDelete(item.index!);
                            }
                          },
                        ),
                      ],
                    ),

                    // Histórico de preços elegante
                    _buildPriceHistoryPreview(isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceHistoryPreview(bool isDark) {
    final history = provider.getPriceHistorySync(item.name, barcode: item.barcode);
    if (history.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 42, top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: history.take(3).map((entry) {
          final price = entry['price'] as double;
          final month = (entry['month'] as String).split(' ').first;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$month: ${currencyFormat.format(price)}',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white60 : Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

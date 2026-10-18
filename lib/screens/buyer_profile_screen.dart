import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/item_provider.dart';
import '../services/utils.dart';
import '../widgets/supermarket_avatar.dart';

/// Screen displaying the intelligent "Perfil de Comprador" (Buyer Profile)
/// analyzing shopping habits, archetype, metrics, top categories, and personalized insights.
class BuyerProfileScreen extends StatefulWidget {
  const BuyerProfileScreen({super.key});

  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ItemProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Financial summaries across all months
    final months = provider.months;
    final summaries = provider.cachedSummary;

    double totalSpent = 0.0;
    double totalBudget = 0.0;
    double totalSavings = 0.0;
    int listsCount = 0;
    double totalBoughtItemsCount = 0.0;
    double totalAllItemsCount = 0.0;

    for (var m in months) {
      final s = summaries[m];
      if (s != null) {
        final spent = s['total'] ?? 0.0;
        final budget = s['budget'] ?? 0.0;
        final bought = s['boughtItems'] ?? 0.0;
        final allItems = s['totalItems'] ?? 0.0;

        if (spent > 0 || budget > 0) {
          totalSpent += spent;
          totalBudget += budget;
          listsCount++;
          if (budget > spent) {
            totalSavings += (budget - spent);
          }
          totalBoughtItemsCount += bought;
          totalAllItemsCount += allItems;
        }
      }
    }

    final double avgTicket = listsCount > 0 ? (totalSpent / listsCount) : 0.0;
    final double completionRate = totalAllItemsCount > 0 ? ((totalBoughtItemsCount / totalAllItemsCount) * 100).clamp(0.0, 100.0) : 100.0;

    // Determine Archetype
    String archetypeTitle;
    String archetypeSubtitle;
    IconData archetypeIcon;
    Color archetypeColor;

    if (listsCount < 2) {
      archetypeTitle = 'Explorador Iniciante';
      archetypeSubtitle = 'Seu perfil de compras está sendo calibrado à medida que você adiciona mais listas no CARRIN.';
      archetypeIcon = Icons.explore_rounded;
      archetypeColor = Colors.cyan;
    } else {
      final double budgetRatio = totalBudget > 0 ? (totalSpent / totalBudget) : 1.0;
      if (budgetRatio <= 0.85) {
        archetypeTitle = 'Poupador Consciente';
        archetypeSubtitle = 'Você compra com precisão, mantém os pés no freio e fecha a maioria dos meses com economia significativa.';
        archetypeIcon = Icons.savings_rounded;
        archetypeColor = Colors.greenAccent[700] ?? Colors.green;
      } else if (budgetRatio <= 1.0) {
        archetypeTitle = 'Planejador Rigoroso';
        archetypeSubtitle = 'Você equilibra perfeitamente suas necessidades ao orçamento estipulado, atingindo alta eficiência financeira.';
        archetypeIcon = Icons.track_changes_rounded;
        archetypeColor = Theme.of(context).colorScheme.primary;
      } else {
        archetypeTitle = 'Comprador Entusiasta';
        archetypeSubtitle = 'Você valoriza a despensa cheia e costuma aproveitar oportunidades no supermercado, mesmo acima do teto inicial.';
        archetypeIcon = Icons.local_fire_department_rounded;
        archetypeColor = Colors.orangeAccent;
      }
    }

    // Category breakdown from price history
    final history = provider.priceHistoryCache;
    final Map<String, double> categorySpent = {};
    final Map<String, int> categoryItemCount = {};
    final Map<String, int> itemFrequency = {};

    for (var entry in history.entries) {
      final itemName = entry.key;
      for (var record in entry.value) {
        final cat = record['category']?.toString() ?? 'Outros';
        final price = (record['price'] as num?)?.toDouble() ?? 0.0;
        categorySpent[cat] = (categorySpent[cat] ?? 0.0) + price;
        categoryItemCount[cat] = (categoryItemCount[cat] ?? 0) + 1;
        itemFrequency[itemName] = (itemFrequency[itemName] ?? 0) + 1;
      }
    }

    final sortedCategories = categorySpent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final double totalCatSpent = categorySpent.values.fold(0.0, (s, v) => s + v);

    final sortedItems = itemFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topItems = sortedItems.take(5).toList();

    return Scaffold(
      backgroundColor: isDark ? null : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Perfil de Comprador', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            physics: const BouncingScrollPhysics(),
            children: [
              // User Card with Archetype
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SupermarketAvatarWidget(
                          photoUrl: provider.activeUserPhotoUrl,
                          displayName: provider.activeUserDisplayName,
                          radius: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.activeUserDisplayName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                provider.isActiveUserOffline
                                    ? 'Perfil Local Offline'
                                    : (provider.activeUserEmail ?? 'Convidado'),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: archetypeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(archetypeIcon, size: 16, color: archetypeColor),
                              const SizedBox(width: 4),
                              Text(
                                archetypeTitle.split(' ').first,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: archetypeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    // Archetype Details Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: archetypeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: archetypeColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: archetypeColor.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(archetypeIcon, color: archetypeColor, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  archetypeTitle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  archetypeSubtitle,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Key Shopping Metrics Grid
              const Text(
                'MÉTRICAS DO COMPRADOR',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Ticket Médio',
                      Utils.formatCurrency(avgTicket),
                      Icons.receipt_long_rounded,
                      Colors.blueAccent,
                      cardColor,
                      textColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'Economia Total',
                      Utils.formatCurrency(totalSavings),
                      Icons.account_balance_wallet_rounded,
                      Colors.green,
                      cardColor,
                      textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Listas Realizadas',
                      '$listsCount carrinhos',
                      Icons.shopping_basket_rounded,
                      primaryColor,
                      cardColor,
                      textColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'Aproveitamento',
                      '${completionRate.toStringAsFixed(0)}% comprados',
                      Icons.done_all_rounded,
                      Colors.purpleAccent,
                      cardColor,
                      textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Top Categories Section
              const Text(
                'ONDE VOCÊ MAIS GASTA (CATEGORIAS)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: sortedCategories.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'Nenhum histórico de itens para analisar categorias.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ),
                      )
                    : Column(
                        children: sortedCategories.take(5).map((entry) {
                          final catName = entry.key;
                          final spent = entry.value;
                          final pct = totalCatSpent > 0 ? (spent / totalCatSpent) : 0.0;
                          final emoji = ItemProvider.categoryEmojis[catName] ?? '📦';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(emoji, style: const TextStyle(fontSize: 16)),
                                        const SizedBox(width: 8),
                                        Text(
                                          catName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${(pct * 100).toStringAsFixed(1)}% (${Utils.formatCurrency(spent)})',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 8,
                                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 24),

              // Frequent Items
              if (topItems.isNotEmpty) ...[
                const Text(
                  'ITENS MAIS RECORRENTES',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: topItems.map((item) {
                      final name = item.key;
                      final count = item.value;
                      final capitalized = name.isNotEmpty ? (name[0].toUpperCase() + name.substring(1)) : name;

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: primaryColor.withValues(alpha: 0.15),
                          child: Icon(Icons.star_rounded, size: 18, color: primaryColor),
                        ),
                        title: Text(capitalized, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count listas',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Smart Insights & Tips
              const Text(
                'INSIGHTS DO ASSISTENTE CARRIN',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
              ),
              const SizedBox(height: 12),
              _buildInsightCard(
                Icons.lightbulb_outline_rounded,
                'Economia Inteligente',
                totalSavings > 0
                    ? 'Você economizou um total de ${Utils.formatCurrency(totalSavings)} ao longo das suas compras. Continue mantendo metas de orçamento antes de ir ao mercado!'
                    : 'Defina orçamentos mensais para suas listas no CARRIN para visualizar o valor economizado e receber alertas de freio a 90%.',
                Colors.amber,
                cardColor,
                textColor,
                isDark,
              ),
              const SizedBox(height: 10),
              _buildInsightCard(
                Icons.checklist_rounded,
                'Precisão da Lista',
                completionRate >= 80
                    ? 'Sua taxa de aproveitamento está em ${completionRate.toStringAsFixed(0)}%! Isso indica compras altamente focadas com baixíssimo desperdício.'
                    : 'Você costuma deixar cerca de ${(100 - completionRate).toStringAsFixed(0)}% dos itens para a próxima ida. Considere usar o recurso de itens essenciais.',
                Colors.blueAccent,
                cardColor,
                textColor,
                isDark,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(IconData icon, String title, String body, Color accentColor, Color cardColor, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

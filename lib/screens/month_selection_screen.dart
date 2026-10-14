import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../providers/item_provider.dart';
import '../theme/app_themes.dart';
import '../widgets/cart_loading_indicator.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/counting_text.dart';
import '../services/utils.dart';
import 'shopping_list_screen.dart';
import 'receipt_scanner_screen.dart';

class MonthSelectionScreen extends StatefulWidget {
  const MonthSelectionScreen({super.key});

  @override
  State<MonthSelectionScreen> createState() => _MonthSelectionScreenState();
}

class _MonthSelectionScreenState extends State<MonthSelectionScreen> with AutomaticKeepAliveClientMixin {
  bool _readyToRefresh = false;
  bool _manualLoading = false;
  
  bool _shouldShowContent = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = Provider.of<ItemProvider>(context, listen: false);
    
    if (provider.months.isNotEmpty && provider.cachedSummary.isNotEmpty) {
      if (mounted) setState(() { _shouldShowContent = true; });
    }

    await provider.loadMonths();
    await provider.getAllMonthsSummary();
    
    if (mounted) setState(() { _shouldShowContent = true; });
  }

  void _showAnimatedDialog(BuildContext context, Widget dialog) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => dialog,
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: curve,
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = Provider.of<ItemProvider>(context);
    final bool showLoader = provider.isMonthsLoading || _manualLoading;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool hasData = provider.months.isNotEmpty;
    final bool useAnimations = provider.animationSettings['list_animations'] ?? true;

    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = constraints.maxWidth < 600 ? 1 : (constraints.maxWidth < 900 ? 2 : 3);
        final double padding = constraints.maxWidth < 600 ? 16 : 40;

        return Scaffold(
          backgroundColor: isDarkMode ? null : const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text('Meus Carrinhos', style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadData())
            ],
            bottom: showLoader ? PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(AppThemes.primaryNavy.withOpacity(0.5)),
                minHeight: 2,
              ),
            ) : null,
          ),
          body: AnimatedSwitcher(
            duration: useAnimations ? const Duration(milliseconds: 400) : Duration.zero,
            child: !_shouldShowContent && !hasData && provider.isMonthsLoading
                ? Center(child: CartLoadingIndicator(key: const ValueKey('carrinhos_loader'), message: 'Buscando seus carrinhos...'))
                : provider.months.isEmpty
                    ? Center(child: const Text('Nenhum carrinho ainda. Crie um carrinho para começar.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                    : Stack(
                        children: [
                          NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollEndNotification) {
                                if (_readyToRefresh && !showLoader) {
                                  setState(() => _manualLoading = true);
                                  provider.loadMonths().then((_) { if (mounted) setState(() => _manualLoading = false); });
                                  _readyToRefresh = false;
                                }
                              }
                              if (notification is ScrollUpdateNotification) { if (notification.metrics.pixels < -50) _readyToRefresh = true; }
                              return false;
                            },
                            child: AnimationLimiter(
                              key: const ValueKey('carrinhos_limiter_once'),
                              child: GridView.builder(
                                key: const ValueKey('carrinhos_grid'),
                                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                padding: EdgeInsets.fromLTRB(padding, 8, padding, 100),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  mainAxisExtent: 140,
                                ),
                                itemCount: provider.months.length,
                                itemBuilder: (context, index) {
                                  final monthTitle = provider.months[index];
                                  final summary = provider.getCachedSummaryForMonth(monthTitle);
                                  final card = _buildMonthCard(context, monthTitle, summary, provider);
                                  if (!useAnimations) return card;
                                  return AnimationConfiguration.staggeredGrid(
                                    position: index,
                                    duration: const Duration(milliseconds: 600),
                                    delay: const Duration(milliseconds: 50),
                                    columnCount: crossAxisCount,
                                    child: SlideAnimation(verticalOffset: 30.0, child: FadeInAnimation(child: card)),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreateMonthDialog(context),
            label: const Text('Novo Carrinho', style: TextStyle(fontWeight: FontWeight.bold)),
            icon: const Icon(Icons.add_shopping_cart),
            backgroundColor: AppThemes.primaryNavy,
            foregroundColor: Colors.white,
          ),
        );
      },
    );
  }

  Widget _buildMonthCard(BuildContext context, String title, Map<String, double>? summary, ItemProvider provider) {
    final bool isDataReady = summary != null;
    final budget = summary?['budget'] ?? 0.0;
    final total = summary?['total'] ?? 0.0;
    final balance = budget - total;
    final percent = budget > 0 ? (total / budget).clamp(0.0, 1.1) : 0.0;
    final double boughtItems = summary?['boughtItems'] ?? 0.0;
    Color statusColor = balance < 0 ? Colors.redAccent : (balance < 100 ? Colors.orangeAccent : Colors.green);
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, 
        borderRadius: BorderRadius.circular(24), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () { provider.switchMonth(title); Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListScreen())); },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8), 
                            decoration: BoxDecoration(
                              color: provider.isMonthFinalized(title)
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.blueAccent.withValues(alpha: 0.1), 
                              shape: BoxShape.circle
                            ), 
                            child: Icon(
                              provider.isMonthFinalized(title) ? Icons.lock : Icons.calendar_month, 
                              color: provider.isMonthFinalized(title) ? Colors.green : Colors.blueAccent, 
                              size: 20
                            )
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    title, 
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), 
                                    overflow: TextOverflow.ellipsis
                                  ),
                                ),
                                if (provider.isMonthFinalized(title)) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'CONCLUÍDO', 
                                      style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold)
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildMoreMenu(context, title, provider),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniMetric('Gasto', total, Colors.blueAccent, Icons.shopping_cart_outlined, isLoading: !isDataReady),
                    _buildMiniMetric(balance < 0 ? 'Excedido' : 'Saldo', balance.abs(), statusColor, balance < 0 ? Icons.trending_up : Icons.trending_down, isLoading: !isDataReady),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end, 
                      children: [
                        Text(
                          (boughtItems.ceil() == 1) ? '1 item' : '${boughtItems.ceil()} itens', 
                          style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                        ), 
                        const SizedBox(height: 2),
                        if (!isDataReady)
                          const SkeletonLoader(width: 32, height: 32, borderRadius: 16)
                        else
                          Stack(
                            alignment: Alignment.center, 
                            children: [
                              SizedBox(width: 32, height: 32, child: CircularProgressIndicator(value: percent > 1.0 ? 1.0 : percent, strokeWidth: 4, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(statusColor))), 
                              Text('${(percent * 100).toInt()}%', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold))
                            ]
                          )
                      ]
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, double value, Color color, IconData icon, {bool isLoading = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Row(children: [Icon(icon, size: 10, color: Colors.grey), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10))]), 
        const SizedBox(height: 2), 
        if (isLoading) const SkeletonLoader(width: 60, height: 16, borderRadius: 4)
        else CountingText(value: value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color))
      ]
    );
  }

  Widget _buildMoreMenu(BuildContext context, String title, ItemProvider provider) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
      padding: EdgeInsets.zero,
      onSelected: (value) async { 
        if (value == 'edit') {
          _showRenameMonthDialog(context, title, provider); 
        } else if (value == 'delete') {
          _confirmDeleteMonth(context, title, provider);
        } else if (value == 'receipt') {
          await provider.switchMonth(title);
          if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()));
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'receipt', child: ListTile(leading: Icon(Icons.receipt_long_outlined), title: Text('Escanear Nota'), dense: true)),
        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar Nome'), dense: true)), 
        const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Excluir', style: TextStyle(color: Colors.red)), dense: true))
      ],
    );
  }

  void _showRenameMonthDialog(BuildContext context, String oldTitle, ItemProvider provider) {
    final controller = TextEditingController(text: oldTitle);
    _showAnimatedDialog(
      context,
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Renomear Carrinho', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Digite o novo nome:'),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Novo nome', border: UnderlineInputBorder()),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: AppThemes.primaryNavy,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty && newTitle != oldTitle) {
                try {
                  await provider.renameMonth(oldTitle, newTitle);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao renomear na nuvem: $e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Renomear', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _confirmDeleteMonth(BuildContext context, String title, ItemProvider provider) {
    _showAnimatedDialog(
      context,
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Excluir Carrinho', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Deseja excluir o carrinho "$title"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              try {
                await provider.deleteMonth(title);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao excluir na nuvem: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _showCreateMonthDialog(BuildContext context) {
    final titleController = TextEditingController();
    final provider = Provider.of<ItemProvider>(context, listen: false);
    final budgetController = TextEditingController(
      text: provider.defaultBudget > 0 ? Utils.formatNumber(provider.defaultBudget) : '',
    );
    _showAnimatedDialog(context, AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), title: const Text('Novo Carrinho', style: TextStyle(fontWeight: FontWeight.bold)), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Nome do carrinho:'), TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(hintText: 'Ex: Ranho Mensal', border: UnderlineInputBorder())), const SizedBox(height: 20), const Text('Orçamento (Opcional):'), TextField(controller: budgetController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '0,00', prefixText: 'R\$ ', prefixStyle: TextStyle(fontSize: 16), floatingLabelBehavior: FloatingLabelBehavior.always, border: UnderlineInputBorder()))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))), ElevatedButton(onPressed: () async { final title = titleController.text.trim(); if (title.isEmpty) return; double? initialBudget = double.tryParse(budgetController.text.replaceAll(',', '.')); Navigator.pop(context); _askTemplateOption(context, title, provider, initialBudget); }, child: const Text('Próximo', style: TextStyle(fontWeight: FontWeight.bold)))]));
  }


  void _askTemplateOption(BuildContext context, String title, ItemProvider provider, double? initialBudget) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color textColor = isDark ? Colors.white : primaryColor;

    _showAnimatedDialog(
      context, 
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), 
        title: const Text('Configuração Inicial', style: TextStyle(fontWeight: FontWeight.bold)), 
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            const Text('Como deseja iniciar este novo carrinho?'), 
            const SizedBox(height: 24), 
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async { 
                      Navigator.of(context).pop(); 
                      try { 
                        await provider.createNewMonth(title, false, initialBudget: initialBudget); 
                        await provider.importEssentials(); 
                        if (context.mounted) { 
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShoppingListScreen())); 
                        } 
                      } catch (e) { 
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao criar carrinho: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      } 
                    }, 
                    icon: Icon(Icons.auto_awesome_outlined, size: 18, color: textColor), 
                    label: Text('Importar Essenciais', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)), 
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12), 
                      side: BorderSide(color: primaryColor, width: 1.5),
                      backgroundColor: isDark ? primaryColor.withOpacity(0.1) : Colors.transparent,
                    )
                  )
                )
              ]
            )
          ]
        ), 
        actions: [
          TextButton(
            onPressed: () async { 
              Navigator.of(context).pop(); 
              try { 
                await provider.createNewMonth(title, false, initialBudget: initialBudget); 
                if (context.mounted) { 
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShoppingListScreen())); 
                } 
              } catch (e) { 
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao criar carrinho: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } 
            }, 
            child: const Text('Em Branco', style: TextStyle(color: Colors.grey))
          ), 
          ElevatedButton(
            onPressed: () async { 
              Navigator.of(context).pop(); 
              try { 
                await provider.createNewMonth(title, true, initialBudget: initialBudget); 
                if (context.mounted) { 
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShoppingListScreen())); 
                } 
              } catch (e) { 
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao criar carrinho: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } 
            }, 
            child: const Text('Usar Itens Atual', style: TextStyle(fontWeight: FontWeight.bold))
          )
        ]
      )
    );
  }
}

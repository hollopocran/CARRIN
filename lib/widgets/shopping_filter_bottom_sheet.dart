import 'package:flutter/material.dart';
import '../providers/item_provider.dart';
import '../theme/app_themes.dart';

enum SortOption { name, quantity, price, category }

/// Bottom sheet dialog for filtering and sorting the shopping list items.
class ShoppingFilterBottomSheet extends StatefulWidget {
  final bool isAscending;
  final bool hideZeroQuantity;
  final SortOption currentSort;
  final List<String> selectedCategories;
  final ValueChanged<bool> onAscendingChanged;
  final ValueChanged<bool> onHideZeroQuantityChanged;
  final ValueChanged<SortOption> onSortChanged;
  final ValueChanged<List<String>> onCategoriesChanged;

  const ShoppingFilterBottomSheet({
    super.key,
    required this.isAscending,
    required this.hideZeroQuantity,
    required this.currentSort,
    required this.selectedCategories,
    required this.onAscendingChanged,
    required this.onHideZeroQuantityChanged,
    required this.onSortChanged,
    required this.onCategoriesChanged,
  });

  /// Displays the filter bottom sheet modal.
  static Future<void> show(
    BuildContext context, {
    required bool isAscending,
    required bool hideZeroQuantity,
    required SortOption currentSort,
    required List<String> selectedCategories,
    required ValueChanged<bool> onAscendingChanged,
    required ValueChanged<bool> onHideZeroQuantityChanged,
    required ValueChanged<SortOption> onSortChanged,
    required ValueChanged<List<String>> onCategoriesChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => ShoppingFilterBottomSheet(
        isAscending: isAscending,
        hideZeroQuantity: hideZeroQuantity,
        currentSort: currentSort,
        selectedCategories: selectedCategories,
        onAscendingChanged: onAscendingChanged,
        onHideZeroQuantityChanged: onHideZeroQuantityChanged,
        onSortChanged: onSortChanged,
        onCategoriesChanged: onCategoriesChanged,
      ),
    );
  }

  @override
  State<ShoppingFilterBottomSheet> createState() => _ShoppingFilterBottomSheetState();
}

class _ShoppingFilterBottomSheetState extends State<ShoppingFilterBottomSheet> {
  late bool _isAscending;
  late bool _hideZeroQuantity;
  late SortOption _currentSort;
  late List<String> _selectedCategories;

  @override
  void initState() {
    super.initState();
    _isAscending = widget.isAscending;
    _hideZeroQuantity = widget.hideZeroQuantity;
    _currentSort = widget.currentSort;
    _selectedCategories = List<String>.from(widget.selectedCategories);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.all(28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtros e Ordenação',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(
                    _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isDark ? Colors.white70 : AppThemes.primaryNavy,
                  ),
                  onPressed: () {
                    setState(() {
                      _isAscending = !_isAscending;
                    });
                    widget.onAscendingChanged(_isAscending);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Ocultar itens sem quantidade',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              value: _hideZeroQuantity,
              onChanged: (val) {
                setState(() {
                  _hideZeroQuantity = val;
                });
                widget.onHideZeroQuantityChanged(val);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'ORDENAR POR',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(
                    'Categorias',
                    style: TextStyle(
                      color: _currentSort == SortOption.category ? Colors.white : null,
                    ),
                  ),
                  selected: _currentSort == SortOption.category,
                  onSelected: (val) {
                    setState(() {
                      _currentSort = SortOption.category;
                    });
                    widget.onSortChanged(SortOption.category);
                  },
                  selectedColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                ChoiceChip(
                  label: Text(
                    'Nome',
                    style: TextStyle(
                      color: _currentSort == SortOption.name ? Colors.white : null,
                    ),
                  ),
                  selected: _currentSort == SortOption.name,
                  onSelected: (val) {
                    setState(() {
                      _currentSort = SortOption.name;
                    });
                    widget.onSortChanged(SortOption.name);
                  },
                  selectedColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                ChoiceChip(
                  label: Text(
                    'Preço',
                    style: TextStyle(
                      color: _currentSort == SortOption.price ? Colors.white : null,
                    ),
                  ),
                  selected: _currentSort == SortOption.price,
                  onSelected: (val) {
                    setState(() {
                      _currentSort = SortOption.price;
                    });
                    widget.onSortChanged(SortOption.price);
                  },
                  selectedColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'FILTRAR CATEGORIA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(
                    'Todas',
                    style: TextStyle(
                      color: _selectedCategories.isEmpty ? Colors.white : null,
                    ),
                  ),
                  selected: _selectedCategories.isEmpty,
                  onSelected: (val) {
                    setState(() {
                      _selectedCategories.clear();
                    });
                    widget.onCategoriesChanged([]);
                  },
                  selectedColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                ...ItemProvider.categories.map((category) {
                  final emoji = ItemProvider.categoryEmojis[category] ?? '📦';
                  final isSelected = _selectedCategories.contains(category);
                  return ChoiceChip(
                    label: Text(
                      '$emoji $category',
                      style: TextStyle(color: isSelected ? Colors.white : null),
                    ),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedCategories.add(category);
                        } else {
                          _selectedCategories.remove(category);
                        }
                      });
                      widget.onCategoriesChanged(List<String>.from(_selectedCategories));
                    },
                    selectedColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

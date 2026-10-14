import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SupermarketAvatar {
  final String id;
  final IconData icon;
  final List<Color> gradientColors;
  final String label;

  const SupermarketAvatar({
    required this.id,
    required this.icon,
    required this.gradientColors,
    required this.label,
  });
}

// Keep supermarketAvatars for backward compatibility and fallback list
final List<SupermarketAvatar> supermarketAvatars = [
  const SupermarketAvatar(
    id: 'supermarket_cart',
    icon: Icons.shopping_cart_rounded,
    gradientColors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
    label: 'Carrinho',
  ),
  const SupermarketAvatar(
    id: 'supermarket_basket',
    icon: Icons.shopping_basket_rounded,
    gradientColors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
    label: 'Cesta',
  ),
  const SupermarketAvatar(
    id: 'supermarket_bag',
    icon: Icons.shopping_bag_rounded,
    gradientColors: [Color(0xFFF7971E), Color(0xFFFFD200)],
    label: 'Sacola',
  ),
  const SupermarketAvatar(
    id: 'supermarket_store',
    icon: Icons.storefront_rounded,
    gradientColors: [Color(0xFF11998e), Color(0xFF38ef7d)],
    label: 'Mercado',
  ),
  const SupermarketAvatar(
    id: 'supermarket_apple',
    icon: Icons.apple_rounded,
    gradientColors: [Color(0xFFe52d27), Color(0xFFb31217)],
    label: 'Fruta',
  ),
  const SupermarketAvatar(
    id: 'supermarket_receipt',
    icon: Icons.receipt_long_rounded,
    gradientColors: [Color(0xFF654ea3), Color(0xFFeaafc8)],
    label: 'Cupom',
  ),
  const SupermarketAvatar(
    id: 'supermarket_wallet',
    icon: Icons.account_balance_wallet_rounded,
    gradientColors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
    label: 'Carteira',
  ),
  const SupermarketAvatar(
    id: 'supermarket_delivery',
    icon: Icons.local_shipping_rounded,
    gradientColors: [Color(0xFF3a7bd5), Color(0xFF3a6073)],
    label: 'Entrega',
  ),
];

final Map<String, IconData> supermarketIcons = {
  'cart': Icons.shopping_cart_rounded,
  'basket': Icons.shopping_basket_rounded,
  'bag': Icons.shopping_bag_rounded,
  'store': Icons.storefront_rounded,
  'apple': Icons.apple_rounded,
  'receipt': Icons.receipt_long_rounded,
  'wallet': Icons.account_balance_wallet_rounded,
  'delivery': Icons.local_shipping_rounded,
  'android': Icons.android_rounded,
};

final Map<String, String> supermarketIconLabels = {
  'cart': 'Carrinho',
  'basket': 'Cesta',
  'bag': 'Sacola',
  'store': 'Mercado',
  'apple': 'Fruta',
  'receipt': 'Cupom',
  'wallet': 'Carteira',
  'delivery': 'Entrega',
  'android': 'Android',
};

class SupermarketTheme {
  final String id;
  final List<Color> colors;
  final String label;

  const SupermarketTheme({
    required this.id,
    required this.colors,
    required this.label,
  });
}

final List<SupermarketTheme> supermarketThemes = [
  const SupermarketTheme(
    id: 'ocean',
    colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
    label: 'Oceano',
  ),
  const SupermarketTheme(
    id: 'sunset',
    colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
    label: 'Pôr do Sol',
  ),
  const SupermarketTheme(
    id: 'sunny',
    colors: [Color(0xFFF7971E), Color(0xFFFFD200)],
    label: 'Ensolarado',
  ),
  const SupermarketTheme(
    id: 'mint',
    colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
    label: 'Hortelã',
  ),
  const SupermarketTheme(
    id: 'cherry',
    colors: [Color(0xFFe52d27), Color(0xFFb31217)],
    label: 'Cereja',
  ),
  const SupermarketTheme(
    id: 'grape',
    colors: [Color(0xFF654ea3), Color(0xFFeaafc8)],
    label: 'Uva',
  ),
  const SupermarketTheme(
    id: 'galaxy',
    colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
    label: 'Galáxia',
  ),
  const SupermarketTheme(
    id: 'slate',
    colors: [Color(0xFF3a7bd5), Color(0xFF3a6073)],
    label: 'Grafite',
  ),
];

SupermarketTheme _getDefaultThemeForIcon(String iconId) {
  switch (iconId) {
    case 'cart': return supermarketThemes[0];
    case 'basket': return supermarketThemes[1];
    case 'bag': return supermarketThemes[2];
    case 'store': return supermarketThemes[3];
    case 'apple': return supermarketThemes[4];
    case 'receipt': return supermarketThemes[5];
    case 'wallet': return supermarketThemes[6];
    case 'delivery': return supermarketThemes[7];
    case 'android': return supermarketThemes[3]; // Mint
    default: return supermarketThemes[0];
  }
}

SupermarketAvatar? getSupermarketAvatar(String id) {
  if (!id.startsWith('supermarket_')) return null;

  final parts = id.split('_');
  if (parts.length < 2) return null;

  final iconId = parts[1];
  
  if (parts.length >= 3) {
    final themeId = parts[2];
    final icon = supermarketIcons[iconId];
    if (icon != null) {
      SupermarketTheme? theme;
      for (var t in supermarketThemes) {
        if (t.id == themeId) {
          theme = t;
          break;
        }
      }
      theme ??= _getDefaultThemeForIcon(iconId);
      return SupermarketAvatar(
        id: id,
        icon: icon,
        gradientColors: theme.colors,
        label: supermarketIconLabels[iconId] ?? 'Avatar',
      );
    }
  }

  final icon = supermarketIcons[iconId];
  if (icon != null) {
    final theme = _getDefaultThemeForIcon(iconId);
    return SupermarketAvatar(
      id: id,
      icon: icon,
      gradientColors: theme.colors,
      label: supermarketIconLabels[iconId] ?? 'Avatar',
    );
  }

  return null;
}

class SupermarketAvatarWidget extends StatelessWidget {
  final String photoUrl;
  final String displayName;
  final double radius;
  final bool isDark;

  const SupermarketAvatarWidget({
    super.key,
    required this.photoUrl,
    required this.displayName,
    this.radius = 20,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl.startsWith('supermarket_')) {
      final avatarData = getSupermarketAvatar(photoUrl);
      if (avatarData != null) {
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: avatarData.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: avatarData.gradientColors.first.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            avatarData.icon,
            color: Colors.white,
            size: radius * 1.1,
          ),
        );
      }
    }

    final isUrl = photoUrl.startsWith('http://') || photoUrl.startsWith('https://');
    final isLocalFile = photoUrl.isNotEmpty && !photoUrl.startsWith('supermarket_') && !isUrl;

    return CircleAvatar(
      radius: radius,
      backgroundImage: isUrl 
          ? NetworkImage(photoUrl) 
          : (isLocalFile ? FileImage(File(photoUrl)) as ImageProvider : null),
      backgroundColor: Theme.of(context).primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
      child: (!isUrl && !isLocalFile || photoUrl.isEmpty)
          ? Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: TextStyle(
                color: isDark ? Colors.white : Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.9,
              ),
            )
          : null,
    );
  }
}

class SupermarketAvatarSelector extends StatefulWidget {
  final String selectedId;
  final ValueChanged<String> onSelected;

  const SupermarketAvatarSelector({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  State<SupermarketAvatarSelector> createState() => _SupermarketAvatarSelectorState();
}

class _SupermarketAvatarSelectorState extends State<SupermarketAvatarSelector> {
  late String _selectedIconId;
  late String _selectedThemeId;
  bool _isCustomPhoto = false;
  String _customPhotoPath = '';

  @override
  void initState() {
    super.initState();
    _parseSelectedId(widget.selectedId);
  }

  @override
  void didUpdateWidget(covariant SupermarketAvatarSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      _parseSelectedId(widget.selectedId);
    }
  }

  void _parseSelectedId(String id) {
    if (id.startsWith('supermarket_')) {
      _isCustomPhoto = false;
      final parts = id.split('_');
      if (parts.length >= 2) {
        _selectedIconId = parts[1];
        _selectedThemeId = parts.length >= 3 ? parts[2] : _getDefaultThemeIdForIcon(_selectedIconId);
        return;
      }
    } else if (id.isNotEmpty) {
      _isCustomPhoto = true;
      _customPhotoPath = id;
      _selectedIconId = 'cart';
      _selectedThemeId = 'ocean';
      return;
    }
    _isCustomPhoto = false;
    _selectedIconId = 'cart';
    _selectedThemeId = 'ocean';
  }

  String _getDefaultThemeIdForIcon(String iconId) {
    switch (iconId) {
      case 'cart': return 'ocean';
      case 'basket': return 'sunset';
      case 'bag': return 'sunny';
      case 'store': return 'mint';
      case 'apple': return 'cherry';
      case 'receipt': return 'grape';
      case 'wallet': return 'galaxy';
      case 'delivery': return 'slate';
      case 'android': return 'mint';
      default: return 'ocean';
    }
  }

  void _updateSelection() {
    final newId = _isCustomPhoto ? _customPhotoPath : 'supermarket_${_selectedIconId}_$_selectedThemeId';
    widget.onSelected(newId);
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _isCustomPhoto = true;
          _customPhotoPath = image.path;
        });
        _updateSelection();
      }
    } catch (e) {
      debugPrint('Erro ao selecionar imagem: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentAvatarId = _isCustomPhoto ? _customPhotoPath : 'supermarket_${_selectedIconId}_$_selectedThemeId';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Column(
            children: [
              const Text(
                'Visualização do Avatar',
                style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600, letterSpacing: 1.1),
              ),
              const SizedBox(height: 8),
              SupermarketAvatarWidget(
                photoUrl: currentAvatarId,
                displayName: '',
                radius: 32,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickImageFromGallery,
                icon: const Icon(Icons.photo_library_rounded, size: 16),
                label: const Text('Escolher da Galeria', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Selecione o Ícone:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: supermarketIcons.keys.map((iconId) {
            final icon = supermarketIcons[iconId]!;
            final label = supermarketIconLabels[iconId] ?? '';
            final isSelected = !_isCustomPhoto && iconId == _selectedIconId;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _isCustomPhoto = false;
                  _selectedIconId = iconId;
                });
                _updateSelection();
              },
              child: Tooltip(
                message: label,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected 
                        ? Theme.of(context).primaryColor.withValues(alpha: isDark ? 0.25 : 0.1) 
                        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                    border: Border.all(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                      width: 2.0,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected 
                        ? Theme.of(context).primaryColor 
                        : (isDark ? Colors.white70 : Colors.black54),
                    size: 22,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Text(
          'Selecione a Cor:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: supermarketThemes.map((theme) {
            final isSelected = !_isCustomPhoto && theme.id == _selectedThemeId;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _isCustomPhoto = false;
                  _selectedThemeId = theme.id;
                });
                _updateSelection();
              },
              child: Tooltip(
                message: theme.label,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: theme.colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: theme.colors.first.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

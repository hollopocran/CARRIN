import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
import '../services/receipt_parser.dart';
import '../services/utils.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  
  bool _isProcessing = false;
  List<Item> _extractedItems = [];
  String _statusMessage = 'Tire uma foto ou escolha da galeria.';

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  double get _totalAmount => _extractedItems.fold(0.0, (sum, it) => sum + (it.unitPrice * it.quantity));

  Future<void> _processImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Lendo e analisando o cupom fiscal com IA...';
      });

      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      final foundItems = ReceiptParser.parse(recognizedText.text);

      setState(() {
        _extractedItems = foundItems;
        _isProcessing = false;
        if (foundItems.isEmpty) {
          _statusMessage = 'Não foi possível identificar itens ou preços claros neste cupom.';
        } else {
          _statusMessage = 'Encontrados ${_extractedItems.length} itens. Toque em um item para editar.';
        }
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'Erro ao processar imagem: $e';
        _isProcessing = false;
      });
    }
  }

  void _editItemDialog(int index) {
    final item = _extractedItems[index];
    final nameCtrl = TextEditingController(text: item.name);
    final qtyCtrl = TextEditingController(text: Utils.formatNumber(item.quantity));
    final priceCtrl = TextEditingController(text: item.unitPrice.toStringAsFixed(2).replaceAll('.', ','));
    String selectedCategory = item.category;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Item do Cupom'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome do Produto'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        decoration: const InputDecoration(labelText: 'Qtd'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        decoration: const InputDecoration(labelText: 'Preço (R\$)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: ItemProvider.categories.contains(selectedCategory) ? selectedCategory : 'Outros',
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: ItemProvider.categories.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text('${ItemProvider.categoryEmojis[c] ?? '📦'} $c'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedCategory = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameCtrl.text.trim();
                final newQty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 1.0;
                final newPrice = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? item.unitPrice;

                if (newName.isNotEmpty) {
                  setState(() {
                    _extractedItems[index] = item.copyWith(
                      name: newName,
                      quantity: newQty,
                      unitPrice: newPrice,
                      category: selectedCategory,
                    );
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveItems() async {
    final provider = Provider.of<ItemProvider>(context, listen: false);
    for (var item in _extractedItems) {
      final existingIndex = provider.items.indexWhere((it) => it.name.toLowerCase() == item.name.toLowerCase());
      if (existingIndex != -1) {
        final existingItem = provider.items[existingIndex];
        existingItem.unitPrice = item.unitPrice;
        existingItem.quantity = item.quantity;
        existingItem.isBought = true;
        await provider.updateItem(existingItem);
      } else {
        await provider.addItem(item);
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_extractedItems.length} itens salvos com sucesso na lista!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Nota Fiscal'),
        actions: [
          if (_extractedItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Escanear outro cupom',
              onPressed: () {
                setState(() {
                  _extractedItems = [];
                  _statusMessage = 'Tire uma foto ou escolha da galeria.';
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isProcessing)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analisando documento (IA)...', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            )
          else if (_extractedItems.isNotEmpty)
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(80),
                      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_extractedItems.length} produtos identificados',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Total: ${Utils.formatCurrency(_totalAmount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _extractedItems.length,
                      itemBuilder: (context, index) {
                        final item = _extractedItems[index];
                        final subtotal = item.unitPrice * item.quantity;
                        return Dismissible(
                          key: Key('item_${item.name}_$index'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            setState(() {
                              _extractedItems.removeAt(index);
                            });
                          },
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Text(
                                ItemProvider.categoryEmojis[item.category] ?? '📦',
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${Utils.formatNumber(item.quantity)}x ${Utils.formatCurrency(item.unitPrice)} • ${item.category}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  Utils.formatCurrency(subtotal),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                                  onPressed: () {
                                    setState(() {
                                      _extractedItems.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                            onTap: () => _editItemDialog(index),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _saveItems,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          'Salvar ${_extractedItems.length} Itens na Lista',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            )
          else
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, size: 80, color: Theme.of(context).colorScheme.primary.withAlpha(150)),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _processImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Câmera'),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: () => _processImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galeria'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}

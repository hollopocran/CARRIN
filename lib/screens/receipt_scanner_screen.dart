import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';

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

  Future<void> _processImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Lendo o cupom fiscal...';
        _extractedItems = [];
      });

      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      _parseReceiptText(recognizedText.text);

    } catch (e) {
      setState(() {
        _statusMessage = 'Erro ao processar imagem: $e';
        _isProcessing = false;
      });
    }
  }

  void _parseReceiptText(String text) {
    // Parsing básico para identificar produtos e preços.
    // Em um cupom típico: "NOME DO PRODUTO  1 UN x 5,99  5,99" ou algo na mesma linha.
    // Vamos procurar linhas que contenham formato de preço (ex: 10,50 ou 10.50).
    
    final lines = text.split('\n');
    List<Item> foundItems = [];
    final priceRegex = RegExp(r'(\d+)[.,](\d{2})(?:\s|[^0-9]|$)*$');

    for (var line in lines) {
      final matches = priceRegex.allMatches(line);
      if (matches.isNotEmpty) {
        // Encontrou um preço na linha
        final lastMatch = matches.last;
        String priceStr = '${lastMatch.group(1)}.${lastMatch.group(2)}';
        double price = double.tryParse(priceStr) ?? 0.0;
        
        // O nome do produto seria o restante da linha antes do preço
        String rawName = line.substring(0, lastMatch.start).trim();
        
        // Remove códigos numéricos do início da linha (ex: "789123 Omo" -> "Omo")
        rawName = rawName.replaceFirst(RegExp(r'^\d{3,}\s+'), '');
        
        // Limpar possíveis lixos de OCR, mas mantendo letras, números (ex: 1kg, 350g), espaços e acentos
        rawName = rawName.replaceAll(RegExp(r'[^a-zA-Z0-9À-ÿ\s]'), '').trim();
        
        if (rawName.isNotEmpty && rawName.length > 2 && price > 0) {
          // Capitalize first letter
          String name = rawName[0].toUpperCase() + rawName.substring(1).toLowerCase();
          
          foundItems.add(Item(
            name: name,
            quantity: 1.0, // Assumimos 1 por padrão para simplificar
            unitPrice: price,
            category: ItemProvider.suggestCategoryForName(name),
            isBought: true, // Já que está no cupom, já foi comprado
          ));
        }
      }
    }

    setState(() {
      _extractedItems = foundItems;
      _isProcessing = false;
      if (foundItems.isEmpty) {
        _statusMessage = 'Não foi possível encontrar itens ou preços claros neste cupom.';
      } else {
        _statusMessage = 'Encontrados ${_extractedItems.length} itens. Verifique antes de salvar.';
      }
    });
  }

  void _saveItems() async {
    final provider = Provider.of<ItemProvider>(context, listen: false);
    for (var item in _extractedItems) {
      // Verifica se o item já existe para não duplicar cegamente
      final existingIndex = provider.items.indexWhere((it) => it.name.toLowerCase() == item.name.toLowerCase());
      if (existingIndex != -1) {
        // Atualiza preço se já existe
        final existingItem = provider.items[existingIndex];
        existingItem.unitPrice = item.unitPrice;
        existingItem.isBought = true;
        await provider.updateItem(existingItem);
      } else {
        // Adiciona novo item
        await provider.addItem(item);
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_extractedItems.length} itens salvos com sucesso!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Nota Fiscal'),
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
                    Text('Analisando documento (IA)...'),
                  ],
                ),
              ),
            )
          else if (_extractedItems.isNotEmpty)
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _extractedItems.length,
                      itemBuilder: (context, index) {
                        final item = _extractedItems[index];
                        return ListTile(
                          leading: Text(ItemProvider.categoryEmojis[item.category] ?? '📦', style: const TextStyle(fontSize: 24)),
                          title: Text(item.name),
                          subtitle: Text(item.category),
                          trailing: Text('R\$ ${item.unitPrice.toStringAsFixed(2).replaceAll('.', ',')}'),
                          onLongPress: () {
                            setState(() {
                              _extractedItems.removeAt(index);
                            });
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveItems,
                            child: const Text('Salvar Itens na Lista', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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
                      const Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _processImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Câmera'),
                          ),
                          ElevatedButton.icon(
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

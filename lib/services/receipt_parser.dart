import '../models/item.dart';
import '../providers/item_provider.dart';

/// Utilitário para processamento e extração inteligente de itens e preços de notas/cupons fiscais.
class ReceiptParser {
  // Palavras-chave fiscais e de rodapé que nunca devem ser tratadas como produtos
  static final Set<String> _ignoredKeywords = {
    'total',
    'subtotal',
    'valor a pagar',
    'valor total',
    'total a pagar',
    'valor pago',
    'pagamento',
    'dinheiro',
    'cartao',
    'credito',
    'debito',
    'pix',
    'troco',
    'desconto',
    'acrescimo',
    'tributos',
    'valor aprox',
    'imposto',
    'icms',
    'procon',
    'chave de acesso',
    'cnpj',
    'inscricao',
    'extrato',
    'nfc-e',
    'nfce',
    'sat',
    'danfe',
    'consumidor',
    'emissao',
    'protocolo',
    'via consumidor',
    'via cliente',
    'obrigado',
    'volte sempre',
    'descricao',
    'vl unit',
    'vl total',
    'documento auxiliar',
  };

  /// Analisa o texto bruto OCR de um cupom e extrai a lista de itens.
  static List<Item> parse(String text) {
    final rawLines = text.split('\n');
    final List<String> lines = [];
    for (var l in rawLines) {
      final trimmed = l.trim();
      if (trimmed.isNotEmpty) {
        lines.add(trimmed);
      }
    }

    final List<Item> items = [];
    final priceRegex = RegExp(r'(\d+)[.,](\d{2})(?:\s|[^0-9]|$)*$');
    final qtyUnitPriceRegex = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:un|cx|pc|kg|lt|pct)?\s*[xX*]\s*(\d+[.,]\d{2})',
      caseSensitive: false,
    );

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      // Ignora se for linha fiscal ou rodapé conhecido
      if (_isIgnoredLine(line)) {
        i++;
        continue;
      }

      // Procura formato de preço na linha atual
      final priceMatches = priceRegex.allMatches(line);

      if (priceMatches.isNotEmpty) {
        final lastMatch = priceMatches.last;
        final priceStr = '${lastMatch.group(1)}.${lastMatch.group(2)}';
        final linePrice = double.tryParse(priceStr) ?? 0.0;

        String rawName = line.substring(0, lastMatch.start).trim();

        // Se a linha antes do preço estiver vazia ou for só quantidade (ex: "1 UN X"),
        // pode ser que a linha anterior continha o nome do produto (formato de 2 linhas)
        if (_isOnlyQuantityOrShort(rawName) && i > 0) {
          final previousLine = lines[i - 1];
          if (!_isIgnoredLine(previousLine) && !priceRegex.hasMatch(previousLine)) {
            rawName = previousLine;
          }
        }

        // Tentar extrair quantidade e valor unitário se presentes na linha
        double quantity = 1.0;
        double unitPrice = linePrice;

        final qtyMatch = qtyUnitPriceRegex.firstMatch(line);
        if (qtyMatch != null) {
          final qStr = qtyMatch.group(1)!.replaceAll(',', '.');
          final uStr = qtyMatch.group(2)!.replaceAll(',', '.');
          final parsedQty = double.tryParse(qStr);
          final parsedUnit = double.tryParse(uStr);
          if (parsedQty != null && parsedQty > 0) {
            quantity = parsedQty;
          }
          if (parsedUnit != null && parsedUnit > 0) {
            unitPrice = parsedUnit;
          }
        }

        // Limpeza do nome do produto
        final cleanName = _cleanProductName(rawName);

        if (cleanName.length >= 2 && unitPrice > 0 && !_isIgnoredKeyword(cleanName)) {
          // Capitaliza primeira letra
          final formattedName = cleanName[0].toUpperCase() + cleanName.substring(1).toLowerCase();

          items.add(Item(
            name: formattedName,
            quantity: quantity,
            unitPrice: unitPrice,
            category: ItemProvider.suggestCategoryForName(formattedName),
            isBought: true,
          ));
        }
      }

      i++;
    }

    return items;
  }

  /// Limpa códigos de barras, prefixos numéricos e lixos do OCR no nome do produto
  static String _cleanProductName(String rawName) {
    var name = rawName;

    // Remove códigos numéricos do início (ex: "001 789123456 Sabonete" -> "Sabonete")
    name = name.replaceFirst(RegExp(r'^\d{2,}\s+'), '');
    name = name.replaceFirst(RegExp(r'^\d{2,}\s+'), ''); // repete caso haja item + codigo de barras

    // Remove padrões como "1 UN X 29,90", "1 UN X", "2 CX * 5,00", "0,5 KG X"
    name = name.replaceAll(
      RegExp(r'\b\d+(?:[.,]\d+)?\s*(?:un|cx|pc|kg|lt|pct)?\s*[xX*]\s*(?:\d+[.,]\d{2})?\s*', caseSensitive: false),
      '',
    );

    // Remove caracteres especiais irrelevantes, mantendo letras, acentos e dígitos úteis (ex: 500g, 1L)
    name = name.replaceAll(RegExp(r'[^a-zA-Z0-9À-ÿ\s-]'), ' ');

    // Normaliza múltiplos espaços
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    return name;
  }

  static bool _isOnlyQuantityOrShort(String text) {
    final trimmed = text.trim();
    if (trimmed.length <= 2) return true;
    // Se contém apenas quantidade, unidade e/ou valor unitário (sem descrição de produto)
    final qtyOnlyPattern = RegExp(
      r'^(?:\d+(?:[.,]\d+)?\s*(?:un|cx|pc|kg|lt|pct)?\s*[xX*]\s*)?(?:\d+[.,]\d{2})?\s*$',
      caseSensitive: false,
    );
    return qtyOnlyPattern.hasMatch(trimmed);
  }

  static bool _isIgnoredLine(String line) {
    final lower = line.toLowerCase();
    for (final kw in _ignoredKeywords) {
      if (lower.startsWith(kw) || lower.contains(' $kw') || lower.contains('$kw ')) {
        return true;
      }
    }
    return false;
  }

  static bool _isIgnoredKeyword(String name) {
    final lower = name.toLowerCase();
    for (final kw in _ignoredKeywords) {
      if (lower == kw || lower.startsWith('$kw ') || lower.endsWith(' $kw')) {
        return true;
      }
    }
    return false;
  }
}

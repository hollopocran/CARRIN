import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import '../models/item.dart';
import 'auth_service.dart';
import 'utils.dart';

/// Service responsible for direct communication with Google Sheets API via user's account.
class UserSheetsService {
  String? _spreadsheetId;
  late String _currentSheetTitle;
  double _budget = 0.0;
  double _totalFromSheet = 0.0;
  String? _activeUserEmail;

  UserSheetsService() {
    _currentSheetTitle = _getRealCurrentMonthName();
  }

  void setActiveUserEmail(String? email) {
    if (_activeUserEmail?.toLowerCase() != email?.toLowerCase()) {
      _activeUserEmail = email;
      _spreadsheetId = null;
    }
  }

  String get _spreadsheetName {
    final googleEmail = AuthService().currentUser?.email.toLowerCase();
    final localEmail = _activeUserEmail?.toLowerCase();
    if (localEmail == null) {
      return 'CARRIN_Lista_Compras';
    }
    if (googleEmail != null && localEmail == googleEmail) {
      return 'CARRIN_Lista_Compras';
    }
    final safeEmail = localEmail.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return 'CARRIN_Lista_Compras_$safeEmail';
  }

  String _getRealCurrentMonthName() {
    final now = DateTime.now();
    final monthsPt = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${monthsPt[now.month - 1]} ${now.year}';
  }

  sheets.SheetsApi? get _sheetsApi {
    final client = AuthService().authClient;
    if (client == null) return null;
    return sheets.SheetsApi(client);
  }

  drive.DriveApi? get _driveApi {
    final client = AuthService().authClient;
    if (client == null) return null;
    return drive.DriveApi(client);
  }

  void reset() {
    _spreadsheetId = null;
    _budget = 0.0;
    _totalFromSheet = 0.0;
    _currentSheetTitle = _getRealCurrentMonthName();
  }

  void setCurrentTitle(String title) {
    _currentSheetTitle = title;
  }

  Future<void> init({String? title}) async {
    if (title != null) _currentSheetTitle = title;
    await _ensureSpreadsheetExists();
  }

  Future<void> _ensureSpreadsheetExists() async {
    if (_spreadsheetId != null) return;
    final driveApi = _driveApi;
    final sheetsApi = _sheetsApi;
    if (driveApi == null || sheetsApi == null) throw Exception('Usuário não autenticado');

    final response = await driveApi.files.list(
      q: "name = '$_spreadsheetName' and mimeType = 'application/vnd.google-apps.spreadsheet'",
      spaces: 'drive',
    );

    if (response.files != null && response.files!.isNotEmpty) {
      _spreadsheetId = response.files!.first.id;
    } else {
      var file = drive.File()
        ..name = _spreadsheetName
        ..mimeType = 'application/vnd.google-apps.spreadsheet';
      final created = await driveApi.files.create(file);
      _spreadsheetId = created.id;

      // REMOVIDO: Não criamos mais o mês automaticamente. 
      // O usuário deve criar sua primeira lista manualmente no app.
    }
  }

  Future<Map<String, Map<String, double>>> getBatchSummaries(List<String> titles) async {
    final Map<String, Map<String, double>> summaries = {};
    if (_spreadsheetId == null) await _ensureSpreadsheetExists();
    final api = _sheetsApi;
    if (api == null) return summaries;

    try {
      final ranges = titles.map((t) => "'$t'!A2:I2").toList();
      final response = await api.spreadsheets.values.batchGet(_spreadsheetId!, ranges: ranges);
      
      for (int i = 0; i < titles.length; i++) {
        final title = titles[i];
        final values = response.valueRanges?[i].values;
        if (values != null && values.isNotEmpty) {
          final row2 = values.first;
          double total = row2.length > 2 ? _parseBrazilianNumber(row2[2].toString()) : 0.0;
          double totalItems = row2.length > 4 ? _parseBrazilianNumber(row2[4].toString()) : 0.0;
          double boughtItems = row2.length > 5 ? _parseBrazilianNumber(row2[5].toString()) : 0.0;
          double balance = row2.length > 6 ? _parseBrazilianNumber(row2[6].toString()) : 0.0;
          double budget = row2.length > 7 ? _parseBrazilianNumber(row2[7].toString()) : 0.0;
          bool isFinalized = row2.length > 8 ? (
            row2[8] == true ||
            row2[8].toString().trim().toLowerCase() == 'true' ||
            row2[8].toString().trim().toLowerCase() == 'verdadeiro' ||
            row2[8].toString().trim() == '1'
          ) : false;

          summaries[title] = {
            'budget': budget, 
            'total': total, 
            'balance': balance,
            'totalItems': totalItems,
            'boughtItems': boughtItems,
            'isFinalized': isFinalized ? 1.0 : 0.0,
          };
        } else {
          summaries[title] = {'budget': 0.0, 'total': 0.0, 'balance': 0.0, 'totalItems': 0.0, 'boughtItems': 0.0, 'isFinalized': 0.0};
        }
      }
    } catch (e) {
      debugPrint('Erro no Batch Summaries: $e');
      rethrow;
    }
    return summaries;
  }

  Future<Map<String, double>> getSummaryOnly(String title) async {
    final res = await getBatchSummaries([title]);
    return res[title] ?? {'budget': 0.0, 'total': 0.0, 'balance': 0.0, 'totalItems': 0.0, 'boughtItems': 0.0, 'isFinalized': 0.0};
  }

  Future<List<String>> getAvailableMonths() async {
    if (_spreadsheetId == null) await _ensureSpreadsheetExists();
    final api = _sheetsApi;
    if (api == null) return [];

    try {
      final ss = await api.spreadsheets.get(_spreadsheetId!);
      final list = ss.sheets?.map((s) => s.properties?.title ?? '').where((t) => t.isNotEmpty).toList() ?? [];
      return list.where((t) {
        final lower = t.toLowerCase();
        return lower != 'página1' && lower != 'página 1' && lower != 'sheet1' && lower != 'sheet 1' && lower != 'pagina1' && lower != 'pagina 1';
      }).toList();
    } catch (e) {
      debugPrint('Erro ao obter meses disponíveis: $e');
      rethrow;
    }
  }

  Future<void> updateBudget(double newBudget) async {
    if (_spreadsheetId == null) await _ensureSpreadsheetExists();
    final api = _sheetsApi;
    if (api == null) return;

    try {
      final vr = sheets.ValueRange()..values = [[newBudget]];
      await api.spreadsheets.values.update(
        vr, _spreadsheetId!, "'$_currentSheetTitle'!H2",
        valueInputOption: 'USER_ENTERED'
      );
      _budget = newBudget;
    } catch (e) {
      if (e.toString().contains('Unable to parse range')) {
        try {
          debugPrint('Aba "$_currentSheetTitle" não encontrada ao atualizar orçamento. Criando automaticamente...');
          await createNewMonth(_currentSheetTitle, false);
          final vr = sheets.ValueRange()..values = [[newBudget]];
          await api.spreadsheets.values.update(
            vr, _spreadsheetId!, "'$_currentSheetTitle'!H2",
            valueInputOption: 'USER_ENTERED'
          );
          _budget = newBudget;
          return;
        } catch (retryError) {
          debugPrint('Erro ao atualizar orçamento após auto-criação: $retryError');
        }
      }
      debugPrint('Erro ao atualizar orçamento: $e');
      rethrow;
    }
  }

  Future<void> updateSummary(String title, double total, double balance, {int? totalItems, int? boughtItems, bool? isFinalized}) async {
    if (_spreadsheetId == null) await _ensureSpreadsheetExists();
    final api = _sheetsApi;
    if (api == null) return;

    try {
      if (totalItems != null && boughtItems != null) {
        final vr = sheets.ValueRange()..values = [[total.toStringAsFixed(2).replaceAll('.', ','), '', totalItems, boughtItems, balance.toStringAsFixed(2).replaceAll('.', ',')]];
        await api.spreadsheets.values.update(
          vr, _spreadsheetId!, "'$title'!C2:G2",
          valueInputOption: 'USER_ENTERED'
        );
      }
      
      if (isFinalized != null) {
        final vrFinal = sheets.ValueRange()..values = [[isFinalized ? 'TRUE' : 'FALSE']];
        await api.spreadsheets.values.update(
          vrFinal, _spreadsheetId!, "'$title'!I2",
          valueInputOption: 'USER_ENTERED'
        );
      }
    } catch (e) {
      if (e.toString().contains('Unable to parse range')) {
        try {
          debugPrint('Aba "$title" não encontrada ao atualizar resumo. Criando automaticamente...');
          await createNewMonth(title, false);
          if (totalItems != null && boughtItems != null) {
            final vr = sheets.ValueRange()..values = [[total.toStringAsFixed(2).replaceAll('.', ','), '', totalItems, boughtItems, balance.toStringAsFixed(2).replaceAll('.', ',')]];
            await api.spreadsheets.values.update(
              vr, _spreadsheetId!, "'$title'!C2:G2",
              valueInputOption: 'USER_ENTERED'
            );
          }
          if (isFinalized != null) {
            final vrFinal = sheets.ValueRange()..values = [[isFinalized ? 'TRUE' : 'FALSE']];
            await api.spreadsheets.values.update(
              vrFinal, _spreadsheetId!, "'$title'!I2",
              valueInputOption: 'USER_ENTERED'
            );
          }
          return;
        } catch (retryError) {
          debugPrint('Erro ao atualizar resumo após auto-criação: $retryError');
        }
      }
      debugPrint('Erro ao atualizar resumo: $e');
      rethrow;
    }
  }

  Future<void> overwriteAllItems(String monthTitle, List<Item> localItems) async {
    if (_spreadsheetId == null) await _ensureSpreadsheetExists();
    final api = _sheetsApi;
    if (api == null) return;

    try {
      // Clear existing
      await api.spreadsheets.values.clear(sheets.ClearValuesRequest(), _spreadsheetId!, "'$monthTitle'!B7:H");

      // Insert new
      if (localItems.isNotEmpty) {
        final List<List<dynamic>> matrix = localItems.map((item) => item.toList()).toList();
        final vr = sheets.ValueRange()..values = matrix;
        await api.spreadsheets.values.update(
          vr, _spreadsheetId!, "'$monthTitle'!B7",
          valueInputOption: 'USER_ENTERED'
        );
      }
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('unable to parse range') || err.contains('not found') || err.contains('cannot find sheet')) {
        try {
          debugPrint('Aba "$monthTitle" não encontrada ao sobrescrever. Criando automaticamente...');
          await createNewMonth(monthTitle, false);
          await api.spreadsheets.values.clear(sheets.ClearValuesRequest(), _spreadsheetId!, "'$monthTitle'!B7:H");
          if (localItems.isNotEmpty) {
            final List<List<dynamic>> matrix = localItems.map((item) => item.toList()).toList();
            final vr = sheets.ValueRange()..values = matrix;
            await api.spreadsheets.values.update(
              vr, _spreadsheetId!, "'$monthTitle'!B7",
              valueInputOption: 'USER_ENTERED'
            );
          }
          return;
        } catch (retryError) {
          debugPrint('Erro ao sobrescrever após auto-criação: $retryError');
        }
      }
      debugPrint('Erro ao sobrescrever itens: $e');
      rethrow;
    }
  }

  Future<void> createNewMonth(String newTitle, bool useTemplate, {double? initialBudget, String? sourceMonth}) async {
    if (_spreadsheetId == null) await _ensureSpreadsheetExists();
    final api = _sheetsApi;
    if (api == null) return;

    try {
      // Verify if sheet already exists
      final ss = await api.spreadsheets.get(_spreadsheetId!);
      final exists = ss.sheets?.any((s) => s.properties?.title == newTitle) ?? false;
      
      if (!exists) {
        // Create the sheet
        final addSheetReq = sheets.Request()
          ..addSheet = (sheets.AddSheetRequest()
            ..properties = (sheets.SheetProperties()..title = newTitle));
        await api.spreadsheets.batchUpdate(
          sheets.BatchUpdateSpreadsheetRequest()..requests = [addSheetReq],
          _spreadsheetId!
        );
      }

      // Setup Headers
      final vr = sheets.ValueRange()
        ..values = [
          ['Lista de Compras', '', 'Total Gasto', '', 'Qtd Itens', 'Comprados', '', 'Orçamento', 'Finalizado'],
          ['', '', '=SUMIF(G7:G; "true"; E7:E)', '', '=SUM(B7:B)', '=SUMIF(G7:G; "true"; B7:B)', '=H2-C2', initialBudget ?? 0, 'FALSE'],
          ['', '', '', '', '', '', '', '', ''],
          ['', '', '', '', '', '', '', '', ''],
          ['', '', '', '', '', '', '', '', ''],
          ['', 'Qtd', 'Produto', 'Preço Unit.', 'Total', 'Categoria', 'Comprado', 'Barcode', '']
        ];
      
      await api.spreadsheets.values.update(
        vr, _spreadsheetId!, "'$newTitle'!A1",
        valueInputOption: 'USER_ENTERED'
      );

      // Copy template
      if (useTemplate) {
        try {
          final src = sourceMonth ?? _currentSheetTitle;
          final srcData = await api.spreadsheets.values.get(_spreadsheetId!, "'$src'!B7:H");
          if (srcData.values != null) {
            List<List<dynamic>> templateItems = [];
            for (var row in srcData.values!) {
              if (row.length >= 2 && row[1].toString().trim().isNotEmpty) {
                templateItems.add([
                  '0', 
                  row[1], 
                  '0', 
                  '0', 
                  row.length > 4 ? row[4] : 'Outros', 
                  'false',
                  row.length > 6 ? row[6] : '',
                ]);
              }
            }
            if (templateItems.isNotEmpty) {
              final vrTemplate = sheets.ValueRange()..values = templateItems;
              await api.spreadsheets.values.update(
                vrTemplate, _spreadsheetId!, "'$newTitle'!B7",
                valueInputOption: 'USER_ENTERED'
              );
            }
          }
        } catch (templateError) {
          debugPrint('Aviso: Falha ao copiar template do mês anterior "$sourceMonth" (aba origem pode não existir): $templateError');
          // Não relançar erro para permitir que o mês seja criado com sucesso mesmo sem template
        }
      }
      
      _currentSheetTitle = newTitle;
      _budget = initialBudget ?? 0.0;
      _totalFromSheet = 0.0;
    } catch (e) {
      debugPrint('Erro ao criar novo mês: $e');
      rethrow;
    }
  }

  String get currentMonthTitle => _currentSheetTitle;
  double get budget => _budget;
  double get totalFromSheet => _totalFromSheet;

  double _parseBrazilianNumber(String value) {
    if (value.isEmpty || value == 'null') return 0.0;
    String clean = value.replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (clean.startsWith('(') && clean.endsWith(')')) clean = clean.substring(1, clean.length - 1);
    if (clean.contains(',')) clean = clean.replaceAll('.', '').replaceAll(',', '.');
    clean = clean.replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  Future<List<Item>> getItems({String? title}) async {
    final targetTitle = title ?? _currentSheetTitle;
    if (_spreadsheetId == null) await _ensureSpreadsheetExists();
    final api = _sheetsApi;
    if (api == null) return [];

    try {
      final response = await api.spreadsheets.values.get(_spreadsheetId!, "'$targetTitle'!B2:H");
      final allValues = response.values ?? [];

      if (allValues.isNotEmpty) {
        final row2 = allValues[0];
        if (title == null || title == _currentSheetTitle) {
          if (row2.length > 1) _totalFromSheet = _parseBrazilianNumber(row2[1].toString());
          if (row2.length > 6) _budget = _parseBrazilianNumber(row2[6].toString());
        }
      }

      List<Item> items = [];
      if (allValues.length >= 6) {
        for (var i = 5; i < allValues.length; i++) {
          if (allValues[i].any((cell) => cell.toString().trim().isNotEmpty)) {
            items.add(Item.fromList(allValues[i], i + 2)); // row index starting from 1 (row 7 is allValues[5])
          }
        }
      }
      return items;
    } catch (e) {
      if (e.toString().contains('Unable to parse range')) {
        try {
          debugPrint('Aba "$targetTitle" não encontrada ao carregar itens. Criando automaticamente...');
          await createNewMonth(targetTitle, false);
          final response = await api.spreadsheets.values.get(_spreadsheetId!, "'$targetTitle'!B2:H");
          final allValues = response.values ?? [];

          if (allValues.isNotEmpty) {
            final row2 = allValues[0];
            if (title == null || title == _currentSheetTitle) {
              if (row2.length > 1) _totalFromSheet = _parseBrazilianNumber(row2[1].toString());
              if (row2.length > 6) _budget = _parseBrazilianNumber(row2[6].toString());
            }
          }

          List<Item> items = [];
          if (allValues.length >= 6) {
            for (var i = 5; i < allValues.length; i++) {
              if (allValues[i].any((cell) => cell.toString().trim().isNotEmpty)) {
                items.add(Item.fromList(allValues[i], i + 2)); // row index starting from 1 (row 7 is allValues[5])
              }
            }
          }
          return items;
        } catch (retryError) {
          debugPrint('Erro ao buscar itens após auto-criação da aba: $retryError');
        }
      }
      debugPrint('Erro crítico ao buscar itens: $e');
      rethrow;
    }
  }

  Future<void> switchMonth(String month) async {
    await init(title: month);
  }

  Future<void> addItem(Item item) async {
    if (_spreadsheetId == null) await _ensureSpreadsheetExists();
    final api = _sheetsApi;
    if (api == null) return;

    try {
      final vr = sheets.ValueRange()..values = [item.toList()];
      await api.spreadsheets.values.append(
        vr, _spreadsheetId!, "'$_currentSheetTitle'!B7",
        valueInputOption: 'USER_ENTERED'
      );
    } catch (e) {
      debugPrint('Erro ao adicionar item: $e');
      rethrow;
    }
  }

  Future<void> updateItem(Item item) async {
    if (_spreadsheetId == null) await _ensureSpreadsheetExists();
    final api = _sheetsApi;
    if (api == null || item.index == null) return;

    try {
      final vr = sheets.ValueRange()..values = [item.toList()];
      await api.spreadsheets.values.update(
        vr, _spreadsheetId!, "'$_currentSheetTitle'!B${item.index}:H${item.index}",
        valueInputOption: 'USER_ENTERED'
      );
    } catch (e) {
      debugPrint('Erro ao atualizar item: $e');
      rethrow;
    }
  }

  Future<void> removeItem(int index) async {
    if (_spreadsheetId == null) await _ensureSpreadsheetExists();
    final api = _sheetsApi;
    if (api == null) return;

    try {
      // Sheets API delete row requires the sheet ID (number), not the name.
      final ss = await api.spreadsheets.get(_spreadsheetId!);
      // Use where(...).firstOrNull to avoid StateError if sheet is missing
      final sheetsList = ss.sheets?.where((s) => s.properties?.title == _currentSheetTitle).toList();
      final sheet = (sheetsList != null && sheetsList.isNotEmpty) ? sheetsList.first : null;
      
      if (sheet != null) {
        final sheetId = sheet.properties?.sheetId;
        final req = sheets.Request()
          ..deleteDimension = (sheets.DeleteDimensionRequest()
            ..range = (sheets.DimensionRange()
              ..sheetId = sheetId
              ..dimension = 'ROWS'
              ..startIndex = index - 1
              ..endIndex = index));
        await api.spreadsheets.batchUpdate(
          sheets.BatchUpdateSpreadsheetRequest()..requests = [req],
          _spreadsheetId!
        );
      }
    } catch (e) {
      debugPrint('Erro ao remover item: $e');
      rethrow;
    }
  }

  Future<void> deleteMonth(String title) async {
    if (_spreadsheetId == null) await _ensureSpreadsheetExists();
    final api = _sheetsApi;
    if (api == null) return;

    try {
      final ss = await api.spreadsheets.get(_spreadsheetId!);
      
      // Se houver apenas 1 aba ativa no Google Sheets, não podemos deletá-la diretamente
      // (a API do Sheets exige no mínimo 1 aba). Portanto, criamos a "Página 1" antes de excluir.
      final totalSheets = ss.sheets?.length ?? 0;
      if (totalSheets <= 1) {
        final addSheetReq = sheets.Request()
          ..addSheet = (sheets.AddSheetRequest()
            ..properties = (sheets.SheetProperties()..title = 'Página 1'));
        await api.spreadsheets.batchUpdate(
          sheets.BatchUpdateSpreadsheetRequest()..requests = [addSheetReq],
          _spreadsheetId!
        );
      }

      final sheetsList = ss.sheets?.where((s) => s.properties?.title == title).toList();
      final sheet = (sheetsList != null && sheetsList.isNotEmpty) ? sheetsList.first : null;
      
      if (sheet != null) {
        final sheetId = sheet.properties?.sheetId;
        final req = sheets.Request()
          ..deleteSheet = (sheets.DeleteSheetRequest()..sheetId = sheetId);
        await api.spreadsheets.batchUpdate(
          sheets.BatchUpdateSpreadsheetRequest()..requests = [req],
          _spreadsheetId!
        );
      }
    } catch (e) {
      debugPrint('Erro ao deletar mês: $e');
      rethrow;
    }
  }

  Future<void> renameMonth(String oldTitle, String newTitle) async {
    if (_spreadsheetId == null) await _ensureSpreadsheetExists();
    final api = _sheetsApi;
    if (api == null) return;

    try {
      final ss = await api.spreadsheets.get(_spreadsheetId!);
      // Use where(...).firstOrNull to avoid StateError
      final sheetsList = ss.sheets?.where((s) => s.properties?.title == oldTitle).toList();
      final sheet = (sheetsList != null && sheetsList.isNotEmpty) ? sheetsList.first : null;
      
      if (sheet != null) {
        final sheetId = sheet.properties?.sheetId;
        final req = sheets.Request()
          ..updateSheetProperties = (sheets.UpdateSheetPropertiesRequest()
            ..properties = (sheets.SheetProperties()..sheetId = sheetId..title = newTitle)
            ..fields = 'title');
        await api.spreadsheets.batchUpdate(
          sheets.BatchUpdateSpreadsheetRequest()..requests = [req],
          _spreadsheetId!
        );
        if (_currentSheetTitle == oldTitle) _currentSheetTitle = newTitle;
      }
    } catch (e) {
      debugPrint('Erro ao renomear mês: $e');
      rethrow;
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> getFullPriceHistory() async {
    final Map<String, List<Map<String, dynamic>>> history = {};
    if (_spreadsheetId == null) await _ensureSpreadsheetExists();
    final api = _sheetsApi;
    if (api == null) return history;

    void addRowToHistory(dynamic row, String month) {
      if (row is List && row.length >= 2 && row[1].toString().trim().isNotEmpty) {
        final rawName = row[1].toString().trim();
        final normalized = Utils.normalize(rawName);
        final price = row.length >= 3 ? _parseBrazilianNumber(row[2].toString()) : 0.0;
        final rawBarcode = row.length > 6 ? row[6].toString().trim() : '';
        final barcode = Item.parseBarcode(rawBarcode) ?? '';
        final category = row.length > 4 ? row[4].toString().trim() : 'Outros';

        if (price > 0 || barcode.isNotEmpty) {
          final list = history.putIfAbsent(normalized, () => []);
          final existingIdx = list.indexWhere((e) => e['month'] == month);
          final entryData = {
            'name': rawName,
            'month': month,
            'price': price,
            'category': category,
            'barcode': barcode,
          };
          if (existingIdx != -1) {
            if ((entryData['barcode'] as String).isEmpty && (list[existingIdx]['barcode'] as String? ?? '').isNotEmpty) {
              entryData['barcode'] = list[existingIdx]['barcode'];
            }
            if (entryData['price'] == 0 && (list[existingIdx]['price'] as num? ?? 0) > 0) {
              entryData['price'] = list[existingIdx]['price'];
            }
            list[existingIdx] = entryData;
          } else {
            list.add(entryData);
          }
        }
      }
    }

    try {
      final months = await getAvailableMonths();
      if (months.isEmpty) return history;

      // 1. Tenta buscar todos os meses em lote (batchGet) em uma única requisição HTTP
      try {
        final ranges = months.map((m) => "'${m.replaceAll("'", "''")}'!B7:H").toList();
        final response = await api.spreadsheets.values.batchGet(_spreadsheetId!, ranges: ranges);
        final valueRanges = response.valueRanges ?? [];

        for (int i = 0; i < months.length && i < valueRanges.length; i++) {
          final month = months[i];
          final rows = valueRanges[i].values;
          if (rows != null) {
            for (var row in rows) {
              addRowToHistory(row, month);
            }
          }
        }
      } catch (batchErr) {
        debugPrint('Aviso: batchGet de histórico de preços falhou ($batchErr). Tentando buscar abas individualmente...');
        // Fallback resiliente: busca abas individualmente caso batchGet falhe
        for (var month in months) {
          try {
            final response = await api.spreadsheets.values.get(_spreadsheetId!, "'${month.replaceAll("'", "''")}'!B7:H");
            if (response.values != null) {
              for (var row in response.values!) {
                addRowToHistory(row, month);
              }
            }
          } catch (singleErr) {
            debugPrint('Erro ao buscar histórico da aba $month: $singleErr');
          }
        }
      }
    } catch (e) {
      debugPrint('Erro geral ao buscar histórico total da nuvem: $e');
    }
    return history;
  }
}

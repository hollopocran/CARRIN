import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item.dart';
import '../models/sync_operation.dart';
import '../models/community_price.dart';
import 'utils.dart';
import 'default_supermarkets.dart';

class DatabaseHelper {
  static const _databaseVersion = 4;
  static String _currentDatabaseName = "carrin_database_guest.db";

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static String get currentDatabaseName => _currentDatabaseName;

  static Future<String> getCurrentDatabasePath() async {
    final databasesPath = await getDatabasesPath();
    return join(databasesPath, _currentDatabaseName);
  }

  static Database? _database;

  static void changeUser(String? email) {
    if (email == null || email.trim().isEmpty) {
      _currentDatabaseName = "carrin_database_guest.db";
    } else {
      final safeEmail = email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      _currentDatabaseName = "carrin_database_$safeEmail.db";
    }
    // Synchronously null _database first so the next access opens the correct DB.
    // Then close the old reference in the background.
    final oldDb = _database;
    _database = null;
    if (oldDb != null) {
      oldDb.close().catchError((_) {});
    }
  }

  static Future<void> closeDatabase() async {
    if (_database != null) {
      try {
        await _database!.close().timeout(
          const Duration(milliseconds: 300),
          onTimeout: () {
            debugPrint('⚠️ DatabaseHelper: Fechamento do banco de dados expirou (timeout).');
          },
        );
      } catch (e) {
        // Ignora erros ao fechar
      }
      _database = null;
    }
  }

  static Future<void> deleteUserDatabase(String email) async {
    final safeEmail = email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final dbName = "carrin_database_$safeEmail.db";
    
    // Se for o banco ativo, fecha primeiro
    if (_currentDatabaseName == dbName) {
      await closeDatabase();
    }
    
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, dbName);
      
      debugPrint('🗑️ DatabaseHelper: Iniciando exclusão direta dos arquivos do banco de dados: $dbName');
      
      // Deleta os arquivos diretamente via File (dart:io) sem usar o deleteDatabase do sqflite.
      // Isso é 100% livre de deadlock/travamentos porque não bloqueia na thread nativa do SQLite/sqflite.
      final fileExtensions = ['', '-journal', '-wal', '-shm'];
      for (final ext in fileExtensions) {
        try {
          final file = File('$path$ext');
          if (await file.exists()) {
            await file.delete();
            debugPrint('🗑️ DatabaseHelper: Arquivo deletado com sucesso: $path$ext');
          }
        } catch (fileErr) {
          debugPrint('⚠️ DatabaseHelper: Erro ao deletar arquivo $path$ext via File: $fileErr');
        }
      }
    } catch (e) {
      debugPrint('⚠️ DatabaseHelper: Erro geral ao deletar banco de dados: $e');
    }
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _currentDatabaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute("PRAGMA foreign_keys = ON");
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE months ADD COLUMN is_finalized INTEGER NOT NULL DEFAULT 0;");
      } catch (e) {
        // Ignora se a coluna já existir por algum motivo
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS supermarkets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            latitude REAL,
            longitude REAL,
            radius_meters REAL NOT NULL DEFAULT 150.0,
            icon TEXT DEFAULT 'store',
            color_hex TEXT DEFAULT '#1E88E5',
            created_at TEXT
          );
        ''');
      } catch (e) {
        debugPrint('Aviso ao criar tabela supermarkets no upgrade: $e');
      }
      try {
        await db.execute("ALTER TABLE items ADD COLUMN supermarket TEXT;");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE months ADD COLUMN purpose TEXT NOT NULL DEFAULT 'geral';");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE months ADD COLUMN category_caps TEXT;");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE months ADD COLUMN workspace TEXT NOT NULL DEFAULT 'personal';");
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS community_prices_cache (
            id TEXT PRIMARY KEY,
            product_name TEXT NOT NULL,
            category TEXT,
            unit TEXT,
            price REAL NOT NULL,
            supermarket_name TEXT NOT NULL,
            latitude REAL,
            longitude REAL,
            submitted_by TEXT,
            verified_receipt INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
          );
        ''');
      } catch (e) {
        debugPrint('Aviso ao criar tabela community_prices_cache no upgrade: $e');
      }
    }
  }

  Future _onCreate(Database db, int version) async {
    // Tabela de Meses (Carrinhos)
    await db.execute('''
      CREATE TABLE months (
        title TEXT PRIMARY KEY,
        budget REAL NOT NULL DEFAULT 0.0,
        total REAL NOT NULL DEFAULT 0.0,
        balance REAL NOT NULL DEFAULT 0.0,
        totalItems REAL NOT NULL DEFAULT 0.0,
        boughtItems REAL NOT NULL DEFAULT 0.0,
        is_finalized INTEGER NOT NULL DEFAULT 0,
        purpose TEXT NOT NULL DEFAULT 'geral',
        category_caps TEXT,
        workspace TEXT NOT NULL DEFAULT 'personal'
      )
    ''');

    // Tabela de Itens da Lista
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_title TEXT NOT NULL,
        index_in_sheet INTEGER,
        name TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 0.0,
        unit_price REAL NOT NULL DEFAULT 0.0,
        is_kg INTEGER NOT NULL DEFAULT 0,
        category TEXT NOT NULL DEFAULT 'Outros',
        is_bought INTEGER NOT NULL DEFAULT 0,
        barcode TEXT,
        supermarket TEXT,
        FOREIGN KEY (month_title) REFERENCES months (title) ON DELETE CASCADE
      )
    ''');

    // Tabela da Fila de Sincronização
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        month TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');

    // Tabela de Mercados Locais
    await db.execute('''
      CREATE TABLE supermarkets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        latitude REAL,
        longitude REAL,
        radius_meters REAL NOT NULL DEFAULT 150.0,
        icon TEXT DEFAULT 'store',
        color_hex TEXT DEFAULT '#1E88E5',
        created_at TEXT
      )
    ''');

    // Tabela de Preços Compartilhados da Comunidade (Cache Local)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS community_prices_cache (
        id TEXT PRIMARY KEY,
        product_name TEXT NOT NULL,
        category TEXT,
        unit TEXT,
        price REAL NOT NULL,
        supermarket_name TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        submitted_by TEXT,
        verified_receipt INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // --- Operações de meses ---
  Future<List<String>> getMonthsList() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('months', columns: ['title'], orderBy: 'rowid ASC');
    return maps.map((m) => m['title'] as String).toList();
  }

  Future<void> saveMonthsList(List<String> months) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var month in months) {
        batch.insert(
          'months',
          {
            'title': month,
            'budget': 0.0,
            'total': 0.0,
            'balance': 0.0,
            'totalItems': 0.0,
            'boughtItems': 0.0,
            'is_finalized': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> insertMonth(
    String title, {
    double budget = 0.0,
    double total = 0.0,
    double balance = 0.0,
    double totalItems = 0.0,
    double boughtItems = 0.0,
    int isFinalized = 0,
    String purpose = 'geral',
    String workspace = 'personal',
  }) async {
    final db = await database;
    // Use IGNORE to prevent ON DELETE CASCADE from deleting items when month already exists
    final rowsAffected = await db.insert(
      'months',
      {
        'title': title,
        'budget': budget,
        'total': total,
        'balance': balance,
        'totalItems': totalItems,
        'boughtItems': boughtItems,
        'is_finalized': isFinalized,
        'purpose': purpose,
        'workspace': workspace,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    // If month already existed (insert was ignored), update its values
    if (rowsAffected == 0) {
      await db.update(
        'months',
        {
          'budget': budget,
          'total': total,
          'balance': balance,
          'totalItems': totalItems,
          'boughtItems': boughtItems,
          'is_finalized': isFinalized,
        },
        where: 'title = ?',
        whereArgs: [title],
      );
    }
  }

  Future<void> renameMonth(String oldTitle, String newTitle) async {
    final db = await database;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> existing = await txn.query(
        'months',
        where: 'title = ?',
        whereArgs: [oldTitle],
      );
      if (existing.isNotEmpty) {
        final oldMonthData = Map<String, dynamic>.from(existing.first);
        oldMonthData['title'] = newTitle;
        await txn.insert('months', oldMonthData, conflictAlgorithm: ConflictAlgorithm.replace);
        
        await txn.update(
          'items',
          {'month_title': newTitle},
          where: 'month_title = ?',
          whereArgs: [oldTitle],
        );
        
        await txn.delete('months', where: 'title = ?', whereArgs: [oldTitle]);
      }
    });
  }

  Future<void> deleteMonth(String title) async {
    final db = await database;
    await db.delete('months', where: 'title = ?', whereArgs: [title]);
  }

  Future<void> updateMonthSummary(String title, Map<String, double> summary) async {
    final db = await database;
    // Use UPDATE to avoid DELETE CASCADE that INSERT...REPLACE triggers
    final rowsAffected = await db.update(
      'months',
      {
        'budget': summary['budget'] ?? 0.0,
        'total': summary['total'] ?? 0.0,
        'balance': summary['balance'] ?? 0.0,
        'totalItems': summary['totalItems'] ?? 0.0,
        'boughtItems': summary['boughtItems'] ?? 0.0,
        'is_finalized': (summary['isFinalized'] ?? 0.0) == 1.0 ? 1 : 0,
      },
      where: 'title = ?',
      whereArgs: [title],
    );
    // If the month doesn't exist yet, insert it
    if (rowsAffected == 0) {
      await db.insert(
        'months',
        {
          'title': title,
          'budget': summary['budget'] ?? 0.0,
          'total': summary['total'] ?? 0.0,
          'balance': summary['balance'] ?? 0.0,
          'totalItems': summary['totalItems'] ?? 0.0,
          'boughtItems': summary['boughtItems'] ?? 0.0,
          'is_finalized': (summary['isFinalized'] ?? 0.0) == 1.0 ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<Map<String, Map<String, double>>> getMonthsSummaries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('months', orderBy: 'rowid ASC');
    final Map<String, Map<String, double>> result = {};
    for (var row in maps) {
      result[row['title'] as String] = {
        'budget': (row['budget'] as num).toDouble(),
        'total': (row['total'] as num).toDouble(),
        'balance': (row['balance'] as num).toDouble(),
        'totalItems': (row['totalItems'] as num).toDouble(),
        'boughtItems': (row['boughtItems'] as num).toDouble(),
        'isFinalized': ((row['is_finalized'] ?? 0) as num).toDouble(),
      };
    }
    return result;
  }

  // --- Operações de itens ---
  Future<List<Item>> getItems(String monthTitle) async {
    final db = await database;
    final cleanTitle = monthTitle.trim();
    final normTitle = Utils.normalize(cleanTitle);

    debugPrint('🔍 DB.getItems: db="$_currentDatabaseName", query month_title="$cleanTitle"');

    // 1. Tenta correspondência exata
    List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: 'month_title = ?',
      whereArgs: [cleanTitle],
      orderBy: 'index_in_sheet ASC',
    );

    // 2. Se vazio, tenta busca case-insensitive e sem espaços extras
    if (maps.isEmpty) {
      maps = await db.query(
        'items',
        where: 'TRIM(LOWER(month_title)) = ?',
        whereArgs: [cleanTitle.toLowerCase()],
        orderBy: 'index_in_sheet ASC',
      );
    }

    // 3. Se ainda vazio, busca por normalização (ignora acentos)
    if (maps.isEmpty) {
      final allRows = await db.query('items', orderBy: 'index_in_sheet ASC');
      final matched = allRows.where((row) {
        final mTitle = (row['month_title'] as String? ?? '').trim();
        final norm = Utils.normalize(mTitle);
        return norm == normTitle || norm.startsWith(normTitle) || normTitle.startsWith(norm);
      }).toList();
      if (matched.isNotEmpty) {
        maps = matched;
        debugPrint('🔍 DB.getItems: Encontrados ${maps.length} itens por normalização para "$cleanTitle"');
      }
    }

    // 4. Se ainda vazio, busca em outros arquivos de banco locais (ex: carrin_database_guest.db)
    if (maps.isEmpty) {
      try {
        final databasesPath = await getDatabasesPath();
        final dir = Directory(databasesPath);
        if (await dir.exists()) {
          final dbFiles = dir.listSync().whereType<File>().where(
            (f) => f.path.endsWith('.db') && !f.path.endsWith(_currentDatabaseName),
          );
          for (var otherFile in dbFiles) {
            try {
              final otherDb = await openDatabase(otherFile.path);
              var otherMaps = await otherDb.query(
                'items',
                where: 'month_title = ?',
                whereArgs: [cleanTitle],
                orderBy: 'index_in_sheet ASC',
              );
              if (otherMaps.isEmpty) {
                otherMaps = await otherDb.query(
                  'items',
                  where: 'TRIM(LOWER(month_title)) = ?',
                  whereArgs: [cleanTitle.toLowerCase()],
                  orderBy: 'index_in_sheet ASC',
                );
              }
              if (otherMaps.isEmpty) {
                final otherRows = await otherDb.query('items', orderBy: 'index_in_sheet ASC');
                otherMaps = otherRows.where((row) {
                  final mTitle = (row['month_title'] as String? ?? '').trim();
                  final norm = Utils.normalize(mTitle);
                  return norm == normTitle || norm.startsWith(normTitle) || normTitle.startsWith(norm);
                }).toList();
              }

              if (otherMaps.isNotEmpty) {
                debugPrint('🔍 DB.getItems: Recuperados ${otherMaps.length} itens do banco alternativo "${basename(otherFile.path)}" para "$cleanTitle"');
                maps = otherMaps;

                // Restaura permanentemente no banco ativo
                final recoveredItems = otherMaps.map((map) {
                  return Item(
                    index: map['index_in_sheet'] as int?,
                    name: (map['name'] as String?) ?? '',
                    quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
                    unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
                    isKg: map['is_kg'] == 1,
                    category: (map['category'] as String?) ?? 'Outros',
                    isBought: map['is_bought'] == 1,
                    barcode: map['barcode'] as String?,
                    supermarket: map['supermarket'] as String?,
                  );
                }).toList();
                await saveItems(cleanTitle, recoveredItems);
                await otherDb.close();
                break;
              }
              await otherDb.close();
            } catch (err) {
              debugPrint('Aviso ao consultar banco alternativo ${otherFile.path}: $err');
            }
          }
        }
      } catch (e) {
        debugPrint('Erro ao varrer bancos alternativos: $e');
      }
    }

    debugPrint('🔍 DB.getItems: retornou ${maps.length} registros para "$cleanTitle"');
    if (maps.isEmpty) {
      final allMonths = await db.rawQuery('SELECT DISTINCT month_title FROM items');
      debugPrint('🔍 DB.getItems: month_titles existentes na tabela items: ${allMonths.map((m) => m['month_title']).toList()}');
    }
    return maps.map((map) {
      return Item(
        index: map['index_in_sheet'] as int?,
        name: (map['name'] as String?) ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
        isKg: map['is_kg'] == 1,
        category: (map['category'] as String?) ?? 'Outros',
        isBought: map['is_bought'] == 1,
        barcode: map['barcode'] as String?,
        supermarket: map['supermarket'] as String?,
      );
    }).toList();
  }

  Future<void> saveItems(String monthTitle, List<Item> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'months',
        {
          'title': monthTitle,
          'budget': 0.0,
          'total': 0.0,
          'balance': 0.0,
          'totalItems': 0.0,
          'boughtItems': 0.0,
          'is_finalized': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      await txn.delete('items', where: 'month_title = ?', whereArgs: [monthTitle]);

      final batch = txn.batch();
      for (var item in items) {
        batch.insert('items', {
          'month_title': monthTitle,
          'index_in_sheet': item.index,
          'name': item.name,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'is_kg': item.isKg ? 1 : 0,
          'category': item.category,
          'is_bought': item.isBought ? 1 : 0,
          'barcode': item.barcode,
          'supermarket': item.supermarket,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  /// Retorna o histórico consolidado de preços e barcodes de todos os itens cadastrados localmente
  Future<Map<String, List<Map<String, dynamic>>>> getAllPriceHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      columns: ['month_title', 'name', 'unit_price', 'category', 'barcode', 'supermarket'],
      where: "name IS NOT NULL AND TRIM(name) != '' AND (unit_price > 0 OR (barcode IS NOT NULL AND TRIM(barcode) != ''))",
      orderBy: 'id ASC',
    );

    final Map<String, List<Map<String, dynamic>>> history = {};
    for (var row in maps) {
      final rawName = (row['name'] as String? ?? '').trim();
      if (rawName.isEmpty) continue;
      final normalized = Utils.normalize(rawName);
      final month = row['month_title'] as String? ?? '';
      final price = (row['unit_price'] as num?)?.toDouble() ?? 0.0;
      final rawBarcode = row['barcode'] as String? ?? '';
      final barcode = Item.parseBarcode(rawBarcode) ?? rawBarcode.trim();
      final category = row['category'] as String? ?? 'Outros';
      final supermarket = row['supermarket'] as String?;

      final list = history.putIfAbsent(normalized, () => []);
      final existingIdx = list.indexWhere((e) => e['month'] == month);
      final entryData = {
        'name': rawName,
        'month': month,
        'price': price,
        'category': category,
        'barcode': barcode,
        'supermarket': supermarket,
      };
      if (existingIdx != -1) {
        if ((entryData['barcode'] as String).isEmpty && (list[existingIdx]['barcode'] as String? ?? '').isNotEmpty) {
          entryData['barcode'] = list[existingIdx]['barcode'];
        }
        if (entryData['price'] == 0 && (list[existingIdx]['price'] as num? ?? 0) > 0) {
          entryData['price'] = list[existingIdx]['price'];
        }
        if (entryData['supermarket'] == null && list[existingIdx]['supermarket'] != null) {
          entryData['supermarket'] = list[existingIdx]['supermarket'];
        }
        list[existingIdx] = entryData;
      } else {
        list.add(entryData);
      }
    }
    return history;
  }

  // --- Operações de fila de sincronização ---
  Future<List<SyncOperation>> getSyncQueue() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sync_queue');
    return maps.map((map) {
      return SyncOperation(
        id: map['id'],
        type: map['type'],
        month: map['month'],
        payload: jsonDecode(map['payload']),
      );
    }).toList();
  }

  Future<void> saveSyncQueue(List<SyncOperation> queue) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sync_queue');
      final batch = txn.batch();
      for (var op in queue) {
        batch.insert('sync_queue', {
          'id': op.id,
          'type': op.type,
          'month': op.month,
          'payload': jsonEncode(op.payload),
        });
      }
      await batch.commit(noResult: true);
    });
  }

  // --- Operações de Mercados Locais (Supermarkets) ---
  Future<List<Map<String, dynamic>>> getSupermarkets() async {
    final db = await database;
    try {
      return await db.query(
        'supermarkets',
        where: "LOWER(name) NOT IN ('supermercado local', 'supermercado')",
        orderBy: 'name ASC',
      );
    } catch (e) {
      debugPrint('Aviso ao consultar supermercados: $e');
      return [];
    }
  }

  Future<int> saveSupermarket({
    required String name,
    double? latitude,
    double? longitude,
    double radiusMeters = 150.0,
    String icon = 'store',
    String colorHex = '#1E88E5',
  }) async {
    final db = await database;
    final cleanName = name.trim();
    if (cleanName.isEmpty) return -1;

    final existing = await db.query(
      'supermarkets',
      where: 'LOWER(name) = ?',
      whereArgs: [cleanName.toLowerCase()],
    );

    final values = {
      'name': cleanName,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'icon': icon,
      'color_hex': colorHex,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      await db.update('supermarkets', values, where: 'id = ?', whereArgs: [id]);
      return id;
    } else {
      return await db.insert('supermarkets', values);
    }
  }

  Future<void> deleteSupermarket(int id) async {
    final db = await database;
    await db.delete('supermarkets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSupermarketByName(String name) async {
    final db = await database;
    await db.delete('supermarkets', where: 'LOWER(name) = ?', whereArgs: [name.trim().toLowerCase()]);
  }

  // --- Operações de Metadados de Meses (Purpose, Category Caps, Workspace) ---
  Future<Map<String, dynamic>?> getMonthDetails(String title) async {
    final db = await database;
    final maps = await db.query('months', where: 'title = ?', whereArgs: [title]);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<void> updateMonthMetadata(
    String title, {
    String? purpose,
    String? categoryCaps,
    String? workspace,
  }) async {
    final db = await database;
    final Map<String, dynamic> values = {};
    if (purpose != null) values['purpose'] = purpose;
    if (categoryCaps != null) values['category_caps'] = categoryCaps;
    if (workspace != null) values['workspace'] = workspace;

    if (values.isNotEmpty) {
      await db.update(
        'months',
        values,
        where: 'title = ?',
        whereArgs: [title],
      );
    }
  }

  Future<List<String>> getMonthsByWorkspace(String workspace) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'months',
        columns: ['title'],
        where: 'workspace = ?',
        whereArgs: [workspace],
        orderBy: 'rowid ASC',
      );
      return maps.map((m) => m['title'] as String).toList();
    } catch (_) {
      return await getMonthsList();
    }
  }

  // --- Operações de Preços da Comunidade (Cache Local) ---

  Future<void> saveCommunityPrice(CommunityPrice price) async {
    final db = await database;
    try {
      await db.insert(
        'community_prices_cache',
        price.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Erro ao salvar preço da comunidade no SQLite: $e');
    }
  }

  Future<void> saveCommunityPrices(List<CommunityPrice> prices) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var p in prices) {
          batch.insert(
            'community_prices_cache',
            p.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      debugPrint('Erro ao salvar lote de preços da comunidade no SQLite: $e');
    }
  }

  Future<List<CommunityPrice>> getCachedCommunityPrices({
    String? query, 
    String? supermarket,
    double? userLat,
    double? userLng,
  }) async {
    final db = await database;
    try {
      final List<String> conditions = [];
      final List<dynamic> whereArgs = [];

      if (query != null && query.trim().isNotEmpty) {
        conditions.add('product_name LIKE ?');
        whereArgs.add('%${query.trim()}%');
      }

      if (supermarket != null && supermarket.trim().isNotEmpty) {
        conditions.add('supermarket_name = ?');
        whereArgs.add(supermarket.trim());
      }

      conditions.add("LOWER(supermarket_name) NOT IN ('carrefour', 'atacadão', 'atacadao', 'assaí atacadista', 'assai atacadista')");
      conditions.add("submitted_by NOT LIKE 'Teste%'");
      conditions.add("submitted_by != 'Comunidade CARRIN'");
      conditions.add("id NOT LIKE 'seed_%'");

      final where = conditions.join(' AND ');

      final List<Map<String, dynamic>> maps = await db.query(
        'community_prices_cache',
        where: where,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'created_at DESC',
        limit: 500,
      );

      return maps.map((m) => CommunityPrice.fromMap(m, userLat: userLat, userLng: userLng)).toList();
    } catch (e) {
      debugPrint('Erro ao carregar preços da comunidade do SQLite: $e');
      return [];
    }
  }

  /// Popula o cache local da comunidade imediatamente a partir das compras do próprio usuário
  Future<int> seedCommunityPricesFromUserPurchases() async {
    final db = await database;
    try {
      final userItems = await getAllUserPurchasedProducts();
      if (userItems.isEmpty) return 0;

      int inserted = 0;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var row in userItems) {
          final name = (row['name'] as String? ?? '').trim();
          final price = (row['unit_price'] as num?)?.toDouble() ?? 0.0;
          if (name.isEmpty || price <= 0) continue;

          String market = (row['supermarket'] as String? ?? '').trim();
          if (market.isEmpty || market.toLowerCase() == 'supermercado local' || market.toLowerCase() == 'supermercado') {
            market = 'Supermercados Guanabara';
          }

          final id = 'local_${name.toLowerCase()}_${market.toLowerCase()}';
          batch.insert(
            'community_prices_cache',
            {
              'id': id,
              'product_name': name,
              'category': row['category'] as String? ?? 'Outros',
              'unit': row['is_kg'] == 1 ? 'kg' : 'un',
              'price': price,
              'supermarket_name': market,
              'latitude': -22.88975,
              'longitude': -43.11515,
              'submitted_by': 'Cliente CARRIN',
              'verified_receipt': 0,
              'created_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          inserted++;
        }
        await batch.commit(noResult: true);
      });
      return inserted;
    } catch (e) {
      debugPrint('Erro ao semear preços locais da comunidade: $e');
      return 0;
    }
  }

  /// Atribui supermercado padrão a itens que não possuem mercado definido ou possuem supermercado de teste
  Future<int> assignDefaultSupermarket(String defaultMarket) async {
    final db = await database;
    try {
      final count = await db.rawUpdate('''
        UPDATE items
        SET supermarket = ?
        WHERE supermarket IS NULL 
           OR TRIM(supermarket) = '' 
           OR LOWER(supermarket) = 'supermercado local'
           OR LOWER(supermarket) = 'supermercado'
      ''', [defaultMarket.trim()]);
      if (count > 0) {
        debugPrint('🛒 $count itens migrados para o supermercado "$defaultMarket"');
      }
      return count;
    } catch (e) {
      debugPrint('Erro ao atribuir supermercado padrão aos itens: $e');
      return 0;
    }
  }

  /// Garante que todos os supermercados padrão de Niterói, São Gonçalo, Itaboraí e Rio de Janeiro estejam registrados no SQLite
  Future<void> ensureDefaultSupermarkets() async {
    final db = await database;
    try {
      for (final s in DefaultSupermarketsData.all) {
        final existing = await db.query(
          'supermarkets',
          where: 'LOWER(name) = ?',
          whereArgs: [s.name.toLowerCase().trim()],
        );
        if (existing.isEmpty) {
          await saveSupermarket(
            name: s.name,
            latitude: s.latitude,
            longitude: s.longitude,
            radiusMeters: s.radiusMeters,
            icon: s.icon,
            colorHex: s.colorHex,
          );
        } else {
          final row = existing.first;
          // Atualiza SEMPRE as coordenadas e raio para calibrar as localizações físicas reais
          await db.update(
            'supermarkets',
            {
              'latitude': s.latitude,
              'longitude': s.longitude,
              'radius_meters': s.radiusMeters,
              'color_hex': s.colorHex,
              'icon': s.icon,
            },
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
      debugPrint('📍 ${DefaultSupermarketsData.all.length} supermercados pré-cadastrados (Niterói, São Gonçalo, Maricá, Itaboraí e Rio) assegurados e calibrados no SQLite');
    } catch (e) {
      debugPrint('Erro ao assegurar mercados padrão: $e');
    }
  }

  /// Busca um supermercado pelo nome exato ou correspondência aproximada
  Future<Map<String, dynamic>?> findSupermarketByName(String name) async {
    final db = await database;
    try {
      final clean = name.trim().toLowerCase();
      if (clean.isEmpty) return null;

      // 1. Busca exata
      final exact = await db.query(
        'supermarkets',
        where: 'LOWER(name) = ?',
        whereArgs: [clean],
        limit: 1,
      );
      if (exact.isNotEmpty) return exact.first;

      // 2. Busca aproximada por LIKE
      final likeMatch = await db.query(
        'supermarkets',
        where: 'LOWER(name) LIKE ?',
        whereArgs: ['%$clean%'],
        limit: 1,
      );
      if (likeMatch.isNotEmpty) return likeMatch.first;

      return null;
    } catch (e) {
      debugPrint('Erro ao buscar supermercado por nome: $e');
      return null;
    }
  }

  /// Retorna todos os produtos registrados nas listas do usuário com preço > 0
  Future<List<Map<String, dynamic>>> getAllUserPurchasedProducts() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT 
          name, 
          unit_price, 
          is_kg, 
          category, 
          supermarket, 
          month_title
        FROM items
        WHERE unit_price > 0 
          AND name IS NOT NULL 
          AND TRIM(name) != ''
        ORDER BY id DESC
      ''');
      return results;
    } catch (e) {
      debugPrint('Erro ao obter produtos do usuário: $e');
      return [];
    }
  }

  Future<void> clearCommunityPrices() async {
    final db = await database;
    try {
      await db.delete('community_prices_cache');
    } catch (_) {}
  }

  Future<void> purgeSeedCommunityPrices() async {
    final db = await database;
    try {
      await db.delete(
        'community_prices_cache',
        where: "id LIKE 'seed_%' OR submitted_by = 'Comunidade CARRIN' OR submitted_by LIKE 'Teste%'",
      );
    } catch (_) {}
  }

  Future<void> cleanTestSupermarkets() async {
    final db = await database;
    try {
      await db.delete(
        'supermarkets',
        where: "LOWER(name) IN ('supermercado local', 'supermercado')",
      );
    } catch (_) {}
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('items');
      await txn.delete('months');
      await txn.delete('sync_queue');
      try {
        await txn.delete('supermarkets');
      } catch (_) {}
      try {
        await txn.delete('community_prices_cache');
      } catch (_) {}
    });
  }
}

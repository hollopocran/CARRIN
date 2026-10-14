import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item.dart';
import '../models/sync_operation.dart';
import 'utils.dart';

class DatabaseHelper {
  static const _databaseVersion = 2;
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
        is_finalized INTEGER NOT NULL DEFAULT 0
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

  Future<void> insertMonth(String title, {double budget = 0.0, double total = 0.0, double balance = 0.0, double totalItems = 0.0, double boughtItems = 0.0, int isFinalized = 0}) async {
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
    debugPrint('🔍 DB.getItems: db="$_currentDatabaseName", query month_title="$monthTitle"');
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: 'month_title = ?',
      whereArgs: [monthTitle],
      orderBy: 'index_in_sheet ASC',
    );
    debugPrint('🔍 DB.getItems: retornou ${maps.length} registros');
    if (maps.isEmpty) {
      // Debug: list all distinct month_titles in items table
      final allMonths = await db.rawQuery('SELECT DISTINCT month_title FROM items');
      debugPrint('🔍 DB.getItems: month_titles existentes na tabela items: ${allMonths.map((m) => m['month_title']).toList()}');
    }
    return maps.map((map) {
      return Item(
        index: map['index_in_sheet'],
        name: map['name'],
        quantity: (map['quantity'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
        isKg: map['is_kg'] == 1,
        category: map['category'],
        isBought: map['is_bought'] == 1,
        barcode: map['barcode'],
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
      columns: ['month_title', 'name', 'unit_price', 'category', 'barcode'],
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

  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('items');
      await txn.delete('months');
      await txn.delete('sync_queue');
    });
  }
}

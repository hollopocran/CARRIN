import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite_dev.dart';
import 'package:lista_compras/models/community_price.dart';
import 'package:lista_compras/services/community_price_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    setMockDatabaseFactory(sqfliteDatabaseFactoryDefault);

    // Mock SQLite MethodChannel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.tekartik.sqflite'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'openDatabase') {
          return {'id': 1};
        }
        if (methodCall.method == 'getDatabasesPath') {
          return '/fake/path';
        }
        if (methodCall.method == 'query' || methodCall.method == 'rawQuery') {
          return <Map<String, dynamic>>[];
        }
        if (methodCall.method == 'insert' || methodCall.method == 'execute' || methodCall.method == 'batch') {
          return 1;
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.tekartik.sqflite'),
      null,
    );
  });

  group('CommunityPriceService Unit Tests', () {
    test('getSupabaseSetupSql includes hardened security constraints and RLS', () {
      final sql = CommunityPriceService.instance.getSupabaseSetupSql();

      // Verifica constraints de integridade
      expect(sql, contains('chk_community_price_positive'));
      expect(sql, contains('chk_community_latitude'));
      expect(sql, contains('chk_community_longitude'));
      expect(sql, contains('chk_community_name_length'));
      expect(sql, contains('chk_community_market_length'));

      // Verifica busca eficiente por substring com trigramas
      expect(sql, contains('pg_trgm'));
      expect(sql, contains('idx_community_product_gin_trgm'));
      expect(sql, contains('gin_trgm_ops'));

      // Verifica políticas RLS seguras
      expect(sql, contains('revoke all on table community_prices from anon, authenticated;'));
      expect(sql, contains('grant select, insert on table community_prices to anon, authenticated;'));
      expect(sql, contains('Permitir inserção anônima segura'));
      expect(sql, contains('verified_receipt is not true'));
    });

    test('publishPrice rejects invalid inputs before hitting network', () async {
      final service = CommunityPriceService.instance;

      // Nome vazio
      expect(
        await service.publishPrice(productName: '', price: 10.0, supermarketName: 'Guanabara'),
        isFalse,
      );

      // Preço zero ou negativo
      expect(
        await service.publishPrice(productName: 'Arroz', price: 0.0, supermarketName: 'Guanabara'),
        isFalse,
      );
      expect(
        await service.publishPrice(productName: 'Arroz', price: -5.0, supermarketName: 'Guanabara'),
        isFalse,
      );

      // Supermercado vazio
      expect(
        await service.publishPrice(productName: 'Arroz', price: 10.0, supermarketName: ''),
        isFalse,
      );
    });

    test('publishPricesBatch returns 0 when price list is empty', () async {
      final service = CommunityPriceService.instance;
      final count = await service.publishPricesBatch([]);
      expect(count, equals(0));
    });

    test('publishPricesBatch returns 0 on network/endpoint error instead of false count', () async {
      final service = CommunityPriceService.instance;
      // Configura uma URL inexistente para forçar erro de conexão/timeout
      await service.saveConfig('http://127.0.0.1:59999', 'fake_key');

      final samplePrices = [
        CommunityPrice(
          id: 'test_1',
          productName: 'Arroz Teste',
          price: 15.0,
          supermarketName: 'Mercado Teste',
          createdAt: DateTime.now(),
        ),
      ];

      // Deve falhar com segurança e retornar 0 (e não prices.length)
      final count = await service.publishPricesBatch(samplePrices);
      expect(count, equals(0));
    });

    test('publishPrice returns false on network/endpoint error', () async {
      final service = CommunityPriceService.instance;
      await service.saveConfig('http://127.0.0.1:59999', 'fake_key');

      final success = await service.publishPrice(
        productName: 'Feijao Teste',
        price: 8.50,
        supermarketName: 'Mercado Teste',
      );

      expect(success, isFalse);
    });
  });
}

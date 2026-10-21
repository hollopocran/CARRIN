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

  group('CommunityPriceService Unit Tests (v1.3.578)', () {
    test('getSupabaseSetupSql includes idempotency column, unique index and RLS', () {
      final sql = CommunityPriceService.instance.getSupabaseSetupSql();

      // Verifica coluna e índice de idempotência
      expect(sql, contains('event_id'));
      expect(sql, contains('idx_community_prices_event_id_unique'));

      // Verifica constraints de integridade
      expect(sql, contains('chk_community_price_positive'));
      expect(sql, contains('chk_community_coords_valid'));
      expect(sql, contains('chk_community_name_length'));
      expect(sql, contains('chk_community_market_length'));
      expect(sql, contains('chk_community_unit_valid'));

      // Verifica busca eficiente por substring com trigramas
      expect(sql, contains('pg_trgm'));
      expect(sql, contains('idx_community_product_trgm'));
      expect(sql, contains('gin_trgm_ops'));

      // Verifica políticas RLS seguras
      expect(sql, contains('REVOKE ALL ON TABLE public.community_prices FROM PUBLIC, anon, authenticated;'));
      expect(sql, contains('GRANT SELECT, INSERT ON TABLE public.community_prices TO anon, authenticated;'));
      expect(sql, contains('Permitir inserção pública'));
      expect(sql, contains('verified_receipt IS NOT TRUE'));
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
          id: 'purchase_device123_42',
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

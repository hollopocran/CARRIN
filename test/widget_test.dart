import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lista_compras/services/utils.dart';
import 'package:lista_compras/widgets/supermarket_avatar.dart';
import 'package:lista_compras/screens/main_screen.dart';
import 'package:lista_compras/screens/dashboard_screen.dart';
import 'package:lista_compras/providers/item_provider.dart';
import 'package:lista_compras/theme/app_themes.dart';
import 'package:lista_compras/services/receipt_parser.dart';
import 'package:lista_compras/services/auth_service.dart';
import 'package:lista_compras/services/quick_summary_service.dart';
import 'package:lista_compras/services/user_sheets_service.dart';
import 'package:lista_compras/widgets/shopping_filter_bottom_sheet.dart';
import 'package:lista_compras/widgets/weight_calculator_dialog.dart';
import 'package:lista_compras/models/item.dart';
import 'package:lista_compras/services/location_service.dart';
import 'package:lista_compras/widgets/market_and_purpose_widgets.dart';
import 'package:lista_compras/services/google_places_service.dart';
import 'package:lista_compras/models/community_price.dart';
import 'package:lista_compras/services/community_price_service.dart';
import 'package:lista_compras/screens/market_map_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  group('ReceiptParser Unit Tests', () {
    test('parses standard single line items with quantities and prices', () {
      const receipt = '''
      MERCADO EXEMPLO LTDA
      CNPJ: 12.345.678/0001-90
      001 7891000123456 ARROZ TIO JOAO 5KG 1 UN X 29,90  29,90
      002 7892000654321 FEIJAO CARIOCA 1KG 2 UN X 7,50   15,00
      TOTAL R\$ 44,90
      DINHEIRO 50,00
      TROCO 5,10
      ''';

      final items = ReceiptParser.parse(receipt);

      expect(items.length, equals(2));
      expect(items[0].name, contains('Arroz tio joao 5kg'));
      expect(items[0].quantity, equals(1.0));
      expect(items[0].unitPrice, equals(29.90));
      expect(items[0].isBought, isTrue);

      expect(items[1].name, contains('Feijao carioca 1kg'));
      expect(items[1].quantity, equals(2.0));
      expect(items[1].unitPrice, equals(7.50));
    });

    test('parses two-line item formats and ignores totals/taxes', () {
      const receipt = '''
      SUPERMERCADO CENTRAL
      001 BISCOITO OREO 90G
      2 UN X 4,50              9,00
      002 SABONETE DOVE
      3 UN X 3,20              9,60
      SUBTOTAL                18,60
      DESCONTO                 1,00
      VALOR A PAGAR           17,60
      CARTAO DE CREDITO       17,60
      TRIBUTOS APROX           3,50
      ''';

      final items = ReceiptParser.parse(receipt);

      expect(items.length, equals(2));
      expect(items[0].name, contains('Biscoito oreo 90g'));
      expect(items[0].quantity, equals(2.0));
      expect(items[0].unitPrice, equals(4.50));

      expect(items[1].name, contains('Sabonete dove'));
      expect(items[1].quantity, equals(3.0));
      expect(items[1].unitPrice, equals(3.20));
    });

    test('extracts store name, CNPJ and items with parseWithMetadata', () {
      const receipt = '''
      SUPERMERCADOS BH LTDA
      CNPJ: 12.345.678/0001-90
      001 7891000123456 LEITE INTEGRAL 1L 2 UN X 4,99 9,98
      TOTAL R\$ 9,98
      ''';

      final result = ReceiptParser.parseWithMetadata(receipt);

      expect(result.storeName, contains('Supermercados Bh'));
      expect(result.cnpj, equals('12.345.678/0001-90'));
      expect(result.items.length, equals(1));
      expect(result.items.first.name, contains('Leite integral 1l'));
      expect(result.items.first.unitPrice, equals(4.99));
    });

    test('parses NFC-e QR code URL and extracts 44-digit key, UF and CNPJ', () {
      const nfcUrl = 'https://portalsped.fazenda.mg.gov.br/portalnfce/sistema/qrcode.xhtml?p=31230512345678000195650010000123451000123456|2|1|1|HASH';

      final result = ReceiptParser.parseNfcUrl(nfcUrl);

      expect(result.nfcKey, equals('31230512345678000195650010000123451000123456'));
      expect(result.uf, equals('MG'));
      expect(result.cnpj, equals('12.345.678/0001-95'));
    });
  });

  group('Utils Unit Tests', () {
    test('normalize removes diacritics and converts to lowercase', () {
      expect(Utils.normalize('Café Moído'), equals('cafe moido'));
      expect(Utils.normalize('Maçã Verde'), equals('maca verde'));
      expect(Utils.normalize('  ARROZ '), equals('arroz'));
    });

    test('formatNumber formats doubles correctly', () {
      expect(Utils.formatNumber(10.0), equals('10'));
      expect(Utils.formatNumber(10.5), equals('10,5'));
    });

    test('formatCurrency formats currency correctly', () {
      // currencyFormat relies on pt_BR locale initialized in setUpAll
      final formatted = Utils.formatCurrency(15.99);
      expect(formatted, contains('15,99'));
    });
  });

  group('QuickSummaryService Tests', () {
    test('saves and retrieves quick summary correctly', () async {
      SharedPreferences.setMockInitialValues({});
      await QuickSummaryService.saveQuickSummary(
        month: 'Outubro 2026',
        totalSpent: 150.0,
        budget: 500.0,
        totalItems: 10,
        boughtItems: 6,
      );

      final summary = await QuickSummaryService.getQuickSummary();
      expect(summary, isNotNull);
      expect(summary!['month'], equals('Outubro 2026'));
      expect(summary['totalSpent'], equals(150.0));
      expect(summary['budget'], equals(500.0));
      expect(summary['balance'], equals(350.0));
      expect(summary['totalItems'], equals(10));
      expect(summary['boughtItems'], equals(6));
      expect(summary['pendingItems'], equals(4));
    });
  });

  group('SupermarketAvatarSelector Widget Tests', () {
    testWidgets('renders successfully and does not throw intrinsic layout exceptions', (WidgetTester tester) async {
      String selectedId = 'supermarket_cart_ocean';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SupermarketAvatarSelector(
                selectedId: selectedId,
                onSelected: (id) {
                  selectedId = id;
                },
              ),
            ),
          ),
        ),
      );

      // Verify that headers render
      expect(find.text('Visualização do Avatar'), findsOneWidget);
      expect(find.text('Selecione o Ícone:'), findsOneWidget);
      expect(find.text('Selecione a Cor:'), findsOneWidget);

      // Verify that the gallery picker button is rendered
      expect(find.text('Escolher da Galeria'), findsOneWidget);

      // Verify that no exceptions are thrown during rendering
      expect(tester.takeException(), isNull);
    });
  });

  group('MainScreen Navigation & Back Button Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      
      // Mock SQLite, Home Widget and Google Sign In method channels
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.tekartik.sqflite'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'openDatabase') {
            return {'id': 1};
          }
          if (methodCall.method == 'query') {
            return <Map<String, dynamic>>[];
          }
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        (MethodCall methodCall) async {
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/google_sign_in'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'init') return null;
          if (methodCall.method == 'signInSilently') return null;
          return null;
        },
      );
    });

    tearDown(() {
      // Clear method call handlers
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.tekartik.sqflite'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/google_sign_in'),
        null,
      );
    });

    testWidgets('MainScreen system back button navigates back to index 0 (Início)', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: AuthService()),
            ChangeNotifierProvider(create: (_) => ItemProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: const MaterialApp(
            home: MainScreen(),
          ),
        ),
      );

      // Wait for async init of MainScreen and providers
      await tester.pumpAndSettle();

      // Find the PageView
      final PageView pageView = tester.widget(find.byType(PageView));
      expect(pageView.controller!.page, 0.0);

      // Tap the second tab (Carrinhos, index 1)
      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();

      // Verify page is now index 1
      final PageView pageViewAfterTap = tester.widget(find.byType(PageView));
      expect(pageViewAfterTap.controller!.page, 1.0);

      // Simulate system back gesture / back button press
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      final didPop = await widgetsAppState.didPopRoute();

      // Ensure that didPop is true, meaning the pop gesture was handled (consumed) by our PopScope
      expect(didPop, isTrue);

      // Wait for tab switch animation to complete
      await tester.pumpAndSettle();

      // Verify the page is now back to Início (index 0)
      final PageView pageViewAfterBack = tester.widget(find.byType(PageView));
      expect(pageViewAfterBack.controller!.page, 0.0);

      // Now on page 0, back gesture should bubble up to the OS (meaning didPopRoute returns false)
      final didPopOnHome = await widgetsAppState.didPopRoute();
      expect(didPopOnHome, isFalse);
    });
  });

  group('WeightCalculatorDialog Widget Tests', () {
    testWidgets('calculates weight correctly when price and total paid are entered', (WidgetTester tester) async {
      String calculatedPrice = '';
      String calculatedWeight = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeightCalculatorDialog(
              initialPrice: '25,00',
              onApplied: (price, weight) {
                calculatedPrice = price;
                calculatedWeight = weight;
              },
            ),
          ),
        ),
      );

      // Verify initial price is set
      expect(find.text('Calculadora de Peso'), findsOneWidget);
      expect(find.text('25,00'), findsOneWidget);

      // Enter total paid: 50,00
      final totalPaidField = find.widgetWithText(TextField, 'Total Pago');
      expect(totalPaidField, findsOneWidget);
      await tester.enterText(totalPaidField, '50,00');
      await tester.pump();

      // Tap 'Aplicar Peso'
      await tester.tap(find.text('Aplicar Peso'));
      await tester.pumpAndSettle();

      // 50.0 / 25.0 = 2.000 kg
      expect(calculatedPrice, equals('25,00'));
      expect(calculatedWeight, equals('2,000'));
    });
  });

  group('ShoppingFilterBottomSheet Widget Tests', () {
    testWidgets('renders sort options and category filters and invokes callbacks', (WidgetTester tester) async {
      bool ascending = true;
      bool hideZero = false;
      SortOption sortOption = SortOption.category;
      List<String> categories = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShoppingFilterBottomSheet(
              isAscending: ascending,
              hideZeroQuantity: hideZero,
              currentSort: sortOption,
              selectedCategories: categories,
              onAscendingChanged: (val) => ascending = val,
              onHideZeroQuantityChanged: (val) => hideZero = val,
              onSortChanged: (val) => sortOption = val,
              onCategoriesChanged: (val) => categories = val,
            ),
          ),
        ),
      );

      expect(find.text('Filtros e Ordenação'), findsOneWidget);
      expect(find.text('Ocultar itens sem quantidade'), findsOneWidget);

      // Toggle ascending arrow
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      expect(ascending, isFalse);

      // Toggle hide zero switch
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(hideZero, isTrue);

      // Select 'Nome' sort chip
      await tester.tap(find.text('Nome'));
      await tester.pump();
      expect(sortOption, equals(SortOption.name));
    });
  });

  group('DashboardScreen Metric Cards Drag Tests', () {
    testWidgets('cards have rounded borders and 24px radius', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: AuthService()),
            ChangeNotifierProvider(create: (_) => ItemProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find 'saldo' card container
      final saldoCardFinder = find.byWidgetPredicate((w) => w is Container && w.key == const ValueKey('saldo'));
      expect(saldoCardFinder, findsOneWidget);

      // Verify that the card container has borderRadius of 24
      final Container container = tester.widget(saldoCardFinder);
      final BoxDecoration decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, equals(BorderRadius.circular(24)));
    });
  });

  group('Google Spreadsheet URL & Config Tests', () {
    test('extracts spreadsheet ID from full URL with gid', () {
      const url = 'https://docs.google.com/spreadsheets/d/1v1uSzdcZyo-U6IvZ4dYNYaDLIv9BdJNMPEa2W_EM6CM/edit?gid=2077412317#gid=2077412317';
      expect(UserSheetsService.extractSpreadsheetId(url), equals('1v1uSzdcZyo-U6IvZ4dYNYaDLIv9BdJNMPEa2W_EM6CM'));
    });

    test('extracts spreadsheet ID from simple /edit URL', () {
      const url = 'https://docs.google.com/spreadsheets/d/1v1uSzdcZyo-U6IvZ4dYNYaDLIv9BdJNMPEa2W_EM6CM/edit';
      expect(UserSheetsService.extractSpreadsheetId(url), equals('1v1uSzdcZyo-U6IvZ4dYNYaDLIv9BdJNMPEa2W_EM6CM'));
    });

    test('extracts spreadsheet ID from raw ID and trims whitespace', () {
      const rawId = '  1v1uSzdcZyo-U6IvZ4dYNYaDLIv9BdJNMPEa2W_EM6CM  ';
      expect(UserSheetsService.extractSpreadsheetId(rawId), equals('1v1uSzdcZyo-U6IvZ4dYNYaDLIv9BdJNMPEa2W_EM6CM'));
    });

    test('sets and gets custom spreadsheet ID in UserSheetsService and SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final service = UserSheetsService();

      expect(await service.getCustomSpreadsheetId(), isNull);

      await service.setCustomSpreadsheetId('https://docs.google.com/spreadsheets/d/1v1uSzdcZyo-U6IvZ4dYNYaDLIv9BdJNMPEa2W_EM6CM/edit');
      expect(await service.getCustomSpreadsheetId(), equals('1v1uSzdcZyo-U6IvZ4dYNYaDLIv9BdJNMPEa2W_EM6CM'));

      await service.setCustomSpreadsheetId(null);
      expect(await service.getCustomSpreadsheetId(), isNull);
    });
  });

  group('Accessibility, ColorBlindMode and FontScale Tests', () {
    test('ThemeProvider updates font scale and provides correct human labels', () async {
      SharedPreferences.setMockInitialValues({});
      final themeProvider = ThemeProvider();
      await themeProvider.init();

      expect(themeProvider.fontScale, equals(1.0));
      expect(themeProvider.fontScaleLabel, equals('Padrão (100%)'));

      await themeProvider.setFontScale(1.30);
      expect(themeProvider.fontScale, equals(1.30));
      expect(themeProvider.fontScaleLabel, equals('Grande (130%)'));

      await themeProvider.setFontScale(0.85);
      expect(themeProvider.fontScale, equals(0.85));
      expect(themeProvider.fontScaleLabel, equals('Pequeno (85%)'));
    });

    test('ThemeProvider adapts color palette and danger/success colors based on ColorBlindMode', () async {
      SharedPreferences.setMockInitialValues({});
      final themeProvider = ThemeProvider();
      await themeProvider.init();

      expect(themeProvider.colorBlindMode, equals(ColorBlindMode.none));

      await themeProvider.setColorBlindMode(ColorBlindMode.deuteranopia);
      expect(themeProvider.colorBlindMode, equals(ColorBlindMode.deuteranopia));
      expect(themeProvider.colorBlindModeLabel, contains('Deuteranopia'));
      // In deuteranopia, success is accessible blue (0xFF0072B2) and danger is vermillion (0xFFD55E00)
      expect(themeProvider.successColor, equals(const Color(0xFF0072B2)));
      expect(themeProvider.dangerColor, equals(const Color(0xFFD55E00)));

      await themeProvider.setColorBlindMode(ColorBlindMode.highContrast);
      expect(themeProvider.colorBlindMode, equals(ColorBlindMode.highContrast));
      expect(themeProvider.successColor, equals(const Color(0xFF00E676)));
      expect(themeProvider.dangerColor, equals(const Color(0xFFFF1744)));
    });
  });

  group('Supermarket & Location Tests', () {
    test('Item model handles supermarket property, toMap, fromMap and copyWith', () {
      final item = Item(
        name: 'Arroz Integral',
        quantity: 2.0,
        unitPrice: 15.50,
        supermarket: 'Assaí Atacadista',
      );

      expect(item.supermarket, equals('Assaí Atacadista'));

      final map = item.toMap();
      expect(map['supermarket'], equals('Assaí Atacadista'));

      final fromMap = Item.fromMap(map);
      expect(fromMap.supermarket, equals('Assaí Atacadista'));

      final copied = item.copyWith(supermarket: 'Carrefour');
      expect(copied.supermarket, equals('Carrefour'));
      expect(copied.name, equals('Arroz Integral'));
    });

    test('LocationService formats distance and calculates distance correctly', () {
      final service = LocationService.instance;

      expect(service.formatDistance(50.4), equals('50m'));
      expect(service.formatDistance(950), equals('950m'));
      expect(service.formatDistance(1500), equals('1.5km'));
      expect(service.formatDistance(3200), equals('3.2km'));

      // Distância entre Avenida Paulista e Praça da Sé (aprox 2.5 - 3 km)
      final distance = service.calculateDistance(-23.5614, -46.6559, -23.5505, -46.6333);
      expect(distance, greaterThan(2000));
      expect(distance, lessThan(4000));
    });

    test('ReceiptParser tags extracted items with storeName', () {
      const receipt = '''
      SUPERMERCADO DIA BRASIL
      CNPJ: 00.123.456/0001-78
      001 7891000123456 LEITE INTEGRAL 1L 3 UN X 4,50 13,50
      TOTAL R\$ 13,50
      ''';

      final result = ReceiptParser.parseWithMetadata(receipt);
      expect(result.items.isNotEmpty, isTrue);
      expect(result.storeName, contains('Supermercado Dia Brasil'));
      expect(result.items.first.supermarket, contains('Supermercado Dia Brasil'));
    });

    test('GooglePlacesService saves, loads and removes API key', () async {
      SharedPreferences.setMockInitialValues({});
      final service = GooglePlacesService.instance;
      await service.saveApiKey('test_key_abc_123');
      expect(await service.getApiKey(), equals('test_key_abc_123'));
      await service.saveApiKey(null);
      expect(await service.getApiKey(), isNull);
    });
  });

  group('RateioDialog Widget Tests', () {
    testWidgets('RateioDialog calculates and displays cost per person correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const RateioDialog(
                    totalSpent: 300.0,
                    listTitle: 'Churrasco Teste',
                  ),
                ),
                child: const Text('Abrir Rateio'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Rateio'));
      await tester.pumpAndSettle();

      expect(find.text('Rateio do Evento'), findsOneWidget);
      expect(find.text('6 pessoas'), findsOneWidget);
      // R$ 300 / 6 = R$ 50,00
      expect(find.textContaining('50,00'), findsOneWidget);

      // Incrementa para 7 pessoas
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('7 pessoas'), findsOneWidget);
    });
  });

  group('CommunityPrice and MarketComparison Unit Tests', () {
    test('CommunityPrice toMap and fromMap serialization with distance calculation', () {
      final now = DateTime(2026, 10, 16, 12, 0);
      final price = CommunityPrice(
        id: 'test_123',
        productName: 'Arroz Camil 5kg',
        category: 'Alimentos',
        unit: 'un',
        price: 24.90,
        supermarketName: 'Carrefour',
        latitude: -23.5614,
        longitude: -46.6559,
        submittedBy: 'Weverton',
        verifiedReceipt: true,
        createdAt: now,
        distanceMeters: 1200,
      );

      final map = price.toMap();
      expect(map['id'], equals('test_123'));
      expect(map['product_name'], equals('Arroz Camil 5kg'));
      expect(map['category'], equals('Alimentos'));
      expect(map['unit'], equals('un'));
      expect(map['price'], equals(24.90));
      expect(map['supermarket_name'], equals('Carrefour'));
      expect(map['latitude'], equals(-23.5614));
      expect(map['longitude'], equals(-46.6559));
      expect(map['submitted_by'], equals('Weverton'));
      expect(map['verified_receipt'], equals(1));
      expect(map['created_at'], equals(now.toIso8601String()));
      expect(price.formattedDistance, equals('1.2km'));

      // Deserialização com cálculo de distância do usuário
      final restored = CommunityPrice.fromMap(
        map,
        userLat: -23.5505,
        userLng: -46.6333,
      );
      expect(restored.id, equals('test_123'));
      expect(restored.productName, equals('Arroz Camil 5kg'));
      expect(restored.price, equals(24.90));
      expect(restored.verifiedReceipt, isTrue);
      expect(restored.distanceMeters, isNotNull);
      expect(restored.distanceMeters!, greaterThan(2000));
    });

    test('ProductComparison calculates maxSavingsPercent accurately', () {
      final now = DateTime.now();
      final p1 = CommunityPrice(
        id: '1',
        productName: 'Café Melitta 500g',
        price: 15.00,
        supermarketName: 'Atacadão',
        createdAt: now,
      );
      final p2 = CommunityPrice(
        id: '2',
        productName: 'Café Melitta 500g',
        price: 20.00,
        supermarketName: 'Pão de Açúcar',
        createdAt: now,
      );

      final comp = ProductComparison(
        productName: 'Café Melitta 500g',
        unit: 'un',
        averagePrice: 17.50,
        minPrice: 15.00,
        maxPrice: 20.00,
        cheapestMarket: 'Atacadão',
        cheapestMarketDistance: 800,
        mostExpensiveMarket: 'Pão de Açúcar',
        totalQuotes: 2,
        prices: [p1, p2],
      );

      // (20 - 15) / 20 * 100 = 25% economia
      expect(comp.maxSavingsPercent, equals(25.0));
      expect(comp.cheapestMarket, equals('Atacadão'));
      expect(comp.mostExpensiveMarket, equals('Pão de Açúcar'));
    });

    test('MarketComparison properties and formattedDistance', () {
      final market = MarketComparison(
        supermarketName: 'Assaí Atacadista',
        latitude: -23.5,
        longitude: -46.6,
        distanceMeters: 650,
        itemsCount: 15,
        averageItemPrice: 12.40,
        cheapestCount: 10,
        isCheapest: true,
      );

      expect(market.supermarketName, equals('Assaí Atacadista'));
      expect(market.isCheapest, isTrue);
      expect(market.formattedDistance, equals('650m'));
    });

    test('CommunityPriceService provides valid setup SQL and handles configuration', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CommunityPriceService.instance;

      final sql = service.getSupabaseSetupSql();
      expect(sql.toLowerCase(), contains('create table if not exists community_prices'));
      expect(sql.toLowerCase(), contains('enable row level security'));
      expect(sql.toLowerCase(), contains('create policy'));

      expect(service.isConfigured, isTrue);
      expect(service.supabaseUrl, contains('supabase.co'));
      await service.saveConfig('https://xyzcompany.supabase.co', 'anon_sample_key_456');
      expect(service.isConfigured, isTrue);
      expect(service.supabaseUrl, equals('https://xyzcompany.supabase.co'));
      expect(service.supabaseAnonKey, equals('anon_sample_key_456'));
    });

    test('CommunityPriceService default store constants reflect Supermercados Guanabara Niterói', () {
      expect(CommunityPriceService.defaultStoreName, equals('Supermercados Guanabara'));
      expect(CommunityPriceService.defaultStoreLat, closeTo(-22.88975, 0.0001));
      expect(CommunityPriceService.defaultStoreLng, closeTo(-43.11515, 0.0001));
    });

    test('MarketComparison handles null distance and coordinates gracefully', () {
      final market = MarketComparison(
        supermarketName: 'Supermercado Central',
        itemsCount: 5,
        averageItemPrice: 8.50,
        cheapestCount: 2,
      );

      expect(market.supermarketName, equals('Supermercado Central'));
      expect(market.latitude, isNull);
      expect(market.longitude, isNull);
      expect(market.distanceMeters, isNull);
      expect(market.formattedDistance, equals(''));
      expect(market.isCheapest, isFalse);
    });

    testWidgets('MarketMapScreen instantiates with default params without throwing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MarketMapScreen(
            initialUserLat: -22.88975,
            initialUserLng: -43.11515,
            initialRadiusKm: 15.0,
          ),
        ),
      );
      expect(find.byType(MarketMapScreen), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lista_compras/services/utils.dart';
import 'package:lista_compras/widgets/supermarket_avatar.dart';
import 'package:lista_compras/screens/main_screen.dart';
import 'package:lista_compras/providers/item_provider.dart';
import 'package:lista_compras/theme/app_themes.dart';
import 'package:lista_compras/services/receipt_parser.dart';
import 'package:lista_compras/services/auth_service.dart';
import 'package:lista_compras/services/quick_summary_service.dart';
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
}

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
import 'package:lista_compras/widgets/assistive_calculator_button.dart';
import 'package:lista_compras/widgets/market_lock_overlay.dart';
import 'package:lista_compras/widgets/item_search_delegate.dart';
import 'package:lista_compras/models/item.dart';
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

  group('AssistiveCalculatorButton Widget Tests', () {
    testWidgets('renders, drags and triggers callback on tap', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                AssistiveCalculatorButton(onTap: () => tapped = true),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(AssistiveCalculatorButton), findsOneWidget);
      expect(find.byIcon(Icons.calculate_rounded), findsOneWidget);

      // Tap on the button
      await tester.tap(find.byType(AssistiveCalculatorButton));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);

      // Drag the button across the screen to test snapping
      await tester.drag(find.byType(AssistiveCalculatorButton), const Offset(-300, -100));
      await tester.pumpAndSettle();

      expect(find.byType(AssistiveCalculatorButton), findsOneWidget);
    });
  });

  group('MarketLockOverlay Widget Tests', () {
    testWidgets('renders shopping metrics and lock state', (WidgetTester tester) async {
      bool unlocked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketLockOverlay(
              onUnlock: () => unlocked = true,
              totalCost: 154.50,
              boughtItemsCount: 8,
              totalItemsCount: 12,
            ),
          ),
        ),
      );

      expect(find.text('Modo Mercado Ativo'), findsOneWidget);
      expect(find.text('Segure para desbloquear'), findsOneWidget);
      expect(find.text('8 de 12'), findsOneWidget);
      expect(find.textContaining('154,50'), findsOneWidget);
      expect(find.text('Sair'), findsNothing); // Redundant button removed
      expect(unlocked, isFalse);
    });

    testWidgets('completing 1-second hold triggers onUnlock', (WidgetTester tester) async {
      bool unlocked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketLockOverlay(
              onUnlock: () => unlocked = true,
              totalCost: 50.0,
              boughtItemsCount: 2,
              totalItemsCount: 5,
            ),
          ),
        ),
      );

      final lockFinder = find.byIcon(Icons.lock_outline_rounded);
      expect(lockFinder, findsOneWidget);

      // Press and hold for 1.2 seconds
      final gesture = await tester.startGesture(tester.getCenter(lockFinder));
      await tester.pump(const Duration(milliseconds: 500));
      expect(unlocked, isFalse); // not yet 1000ms

      await tester.pump(const Duration(milliseconds: 1000));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(unlocked, isTrue);
    });
  });

  group('ItemSearchDelegate Widget Tests', () {
    testWidgets('renders search list with fluid animation and filters items', (WidgetTester tester) async {
      final provider = ItemProvider();
      provider.items.add(Item(name: 'Maçã Fuji', category: 'Frutas', unitPrice: 8.50, quantity: 2, isBought: false, index: 1));
      provider.items.add(Item(name: 'Banana Prata', category: 'Frutas', unitPrice: 5.00, quantity: 1, isBought: true, index: 2));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showSearch(
                    context: context,
                    delegate: ItemSearchDelegate(
                      provider,
                      onEdit: (_) {},
                      onDelete: (_) {},
                    ),
                  );
                },
                child: const Text('Buscar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();

      expect(find.text('Maçã Fuji'), findsOneWidget);
      expect(find.text('Banana Prata'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Maçã');
      await tester.pumpAndSettle();

      expect(find.text('Maçã Fuji'), findsOneWidget);
      expect(find.text('Banana Prata'), findsNothing);
    });
  });

  group('AppColors & ThemeProvider Unit Tests', () {
    test('AppColors contains curated named colors and formats names', () {
      expect(AppColors.curated.length, greaterThanOrEqualTo(12));
      expect(AppColors.getColorName(AppColors.navy), equals('Azul Marinho'));
      expect(AppColors.getColorName(AppColors.ocean), equals('Azul Oceano'));
      expect(AppColors.getColorName(const Color(0xFF123456)), contains('#123456'));
    });

    test('ThemeProvider switches colors and dark mode correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      await provider.init();

      await provider.setSeedColor(AppColors.emerald);
      expect(provider.seedColor, equals(AppColors.emerald));

      await provider.setTheme(true);
      expect(provider.isDarkMode, isTrue);
      expect(provider.currentTheme.brightness, equals(Brightness.dark));

      await provider.toggleTheme();
      expect(provider.isDarkMode, isFalse);
      expect(provider.currentTheme.brightness, equals(Brightness.light));
    });
  });
}


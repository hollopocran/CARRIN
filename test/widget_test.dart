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
import 'package:lista_compras/services/auth_service.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
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
}

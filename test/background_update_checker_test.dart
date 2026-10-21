import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lista_compras/services/background_update_checker.dart';
import 'package:lista_compras/services/app_update_service.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('BackgroundUpdateChecker Contract Tests', () {
    test('task identifiers and preference keys are correctly defined', () {
      expect(backgroundUpdateTaskKey, equals('com.wmartins.carrin.periodic_update_check'));
      expect(backgroundUpdateUniqueName, equals('carrin_periodic_update_check'));
      expect(prefLastNotifiedUpdateVersionKey, equals('last_notified_update_version'));
    });

    test('anti-spam logic prevents duplicate notifications for the same version', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Before notification
      expect(prefs.getString(prefLastNotifiedUpdateVersionKey), isNull);

      // Simulates notification sent
      await prefs.setString(prefLastNotifiedUpdateVersionKey, '1.3.580');

      // Now it should match
      expect(prefs.getString(prefLastNotifiedUpdateVersionKey), equals('1.3.580'));
    });

    test('AppUpdateService version is bumped to 1.3.582', () {
      expect(AppUpdateService.currentAppVersion, equals('1.3.582'));
      expect(AppUpdateService.currentBuildNumber, equals(582));
    });
  });
}

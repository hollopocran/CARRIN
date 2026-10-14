import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:shared_preferences/shared_preferences.dart';
import 'google_auth_client.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '114329991086-8gpmm2617uinkalo45ml81tlstcpng30.apps.googleusercontent.com',
    scopes: [
      drive.DriveApi.driveFileScope,
      sheets.SheetsApi.spreadsheetsScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  GoogleAuthClient? _authClient;
  GoogleAuthClient? get authClient => _authClient;

  bool get isSignedIn => _currentUser != null && _authClient != null;

  Future<void> init() async {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      _currentUser = account;
      if (_currentUser != null) {
        _authClient = GoogleAuthClient(_currentUser!);
      } else {
        _authClient = null;
      }
      notifyListeners();
    });
    
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = account;
        _authClient = GoogleAuthClient(account);
        debugPrint('✅ AuthService: Restaurado login silencioso para ${account.email}');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_user_email', account.email);
      }
    } catch (e) {
      debugPrint('Erro no signInSilently: $e');
    }
  }

  Future<bool> signIn() async {
    try {
      debugPrint('🔍 AuthService: Iniciando processo de login com clientId...');
      final account = await _googleSignIn.signIn();
      if (account != null) {
        debugPrint('🔍 AuthService: Conta selecionada: ${account.email}');
        _currentUser = account;
        _authClient = GoogleAuthClient(account);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_user_email', account.email);
        notifyListeners();
        return true;
      }
      debugPrint('🔍 AuthService: Login cancelado pelo usuário ou retornou nulo.');
      return false;
    } catch (e) {
      debugPrint('❌ Erro CRÍTICO ao fazer login com Google:');
      debugPrint('❌ Detalhes: $e');
      if (e.toString().contains('10')) {
        debugPrint('⚠️ DICA: Erro 10 (DEVELOPER_ERROR) geralmente indica que o SHA-1 ou o Nome do Pacote não coincidem com o console do Google.');
      } else if (e.toString().contains('7')) {
        debugPrint('⚠️ DICA: Erro 7 (NETWORK_ERROR) indica problema de conexão ou erro no Play Services.');
      }
      return false;
    }
  }

  Future<void> signOut() async {
    _currentUser = null;
    _authClient = null;
    await _googleSignIn.signOut();
    notifyListeners();
  }
}
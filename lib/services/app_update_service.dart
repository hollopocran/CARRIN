import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de dados da versão remota disponível
class AppUpdateInfo {
  final String version;
  final int buildNumber;
  final String releaseDate;
  final String title;
  final List<String> releaseNotes;
  final String apkUrl;
  final bool isActive;
  final bool forceUpdate;

  AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.title,
    required this.releaseNotes,
    required this.apkUrl,
    this.isActive = true,
    this.forceUpdate = false,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    List<String> notes = [];
    if (json['release_notes'] is List) {
      notes = (json['release_notes'] as List).map((e) => e.toString()).toList();
    } else if (json['release_notes'] is String) {
      notes = (json['release_notes'] as String)
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return AppUpdateInfo(
      version: json['version']?.toString() ?? '1.0.0',
      buildNumber: int.tryParse(json['build_number']?.toString() ?? '0') ?? 0,
      releaseDate: json['release_date']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Nova Atualização',
      releaseNotes: notes,
      apkUrl: json['apk_url']?.toString() ?? '',
      isActive: json['is_active'] == null ? true : (json['is_active'] == true),
      forceUpdate: json['force_update'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'build_number': buildNumber,
    'release_date': releaseDate,
    'title': title,
    'release_notes': releaseNotes,
    'apk_url': apkUrl,
    'is_active': isActive,
    'force_update': forceUpdate,
  };
}

/// Serviço responsável por identificar atualizações, baixar APKs e invocar a instalação nativa.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String currentAppVersion = '1.3.567';
  static const int currentBuildNumber = 567;

  static const MethodChannel _installerChannel = MethodChannel('com.wmartins.carrin/installer');

  static const String primaryVersionUrl =
      'https://raw.githubusercontent.com/hollopocran/CARRIN/main/version.json';
  static const String fallbackVersionUrl =
      'https://cdn.jsdelivr.net/gh/hollopocran/CARRIN@main/version.json';

  static const String _prefCustomVersionUrlKey = 'custom_app_version_url';
  static const String _prefDismissedBuildKey = 'dismissed_update_build';

  /// Armazena o último motivo de falha na consulta (ex: 404 por repo privado ou falha de conexão)
  String? lastFetchError;

  /// Consulta a versão mais recente disponível na nuvem
  Future<AppUpdateInfo?> fetchLatestUpdateInfo() async {
    lastFetchError = null;
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString(_prefCustomVersionUrlKey);
    final urlsToTry = [
      if (customUrl != null && customUrl.trim().isNotEmpty) customUrl.trim(),
      primaryVersionUrl,
      fallbackVersionUrl,
    ];

    int notFoundCount = 0;
    int connectionErrorCount = 0;

    for (final url in urlsToTry) {
      try {
        final uri = Uri.parse(url);
        final response = await http.get(uri).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            final info = AppUpdateInfo.fromJson(decoded);
            if (info.isActive) {
              lastFetchError = null;
              return info;
            }
          }
        } else if (response.statusCode == 404) {
          notFoundCount++;
          debugPrint('Aviso: $url retornou HTTP 404 (arquivo não encontrado ou repositório privado)');
        }
      } catch (e) {
        connectionErrorCount++;
        debugPrint('Erro ao consultar versão em $url: $e');
      }
    }

    if (notFoundCount > 0) {
      lastFetchError = 'Erro 404: Arquivo version.json não encontrado. Verifique se a visibilidade do repositório no GitHub está como "Público".';
    } else if (connectionErrorCount == urlsToTry.length) {
      lastFetchError = 'Falha de conexão ao verificar atualizações. Verifique sua internet.';
    }

    return null;
  }

  /// Verifica se há uma versão mais nova que a instalada
  Future<AppUpdateInfo?> checkForUpdate({bool ignoreDismissed = false}) async {
    final info = await fetchLatestUpdateInfo();
    if (info == null) return null;

    final isNewer = info.buildNumber > currentBuildNumber ||
        _isSemanticVersionGreater(info.version, currentAppVersion);

    if (!isNewer) return null;

    if (!ignoreDismissed && !info.forceUpdate) {
      final prefs = await SharedPreferences.getInstance();
      final dismissedBuild = prefs.getInt(_prefDismissedBuildKey) ?? 0;
      if (dismissedBuild >= info.buildNumber) {
        return null; // Usuário pediu para lembrar depois desta build
      }
    }

    return info;
  }

  /// Guarda que o usuário dispensou temporariamente esta build
  Future<void> dismissBuild(int buildNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefDismissedBuildKey, buildNumber);
  }

  /// Verifica se a permissão para instalar APKs desconhecidos está ativa no Android
  Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? canInstall = await _installerChannel.invokeMethod<bool>('canRequestPackageInstalls');
      return canInstall ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Abre as configurações do Android para permitir instalação a partir deste app
  Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _installerChannel.invokeMethod('openInstallPermissionSettings');
    } catch (e) {
      debugPrint('Erro ao abrir configurações de instalação: $e');
    }
  }

  /// Dispara a instalação nativa do APK baixado via FileProvider
  Future<bool> installApk(String filePath) async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? result = await _installerChannel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Erro nativo ao invocar instalador do Android: $e');
      return false;
    }
  }

  /// Baixa o APK com acompanhamento de progresso em tempo real e inicia a instalação
  Future<File> downloadApk({
    required String apkUrl,
    required void Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    final client = http.Client();
    try {
      final uri = Uri.parse(apkUrl);
      final request = http.Request('GET', uri);
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Servidor retornou erro ${response.statusCode} ao baixar o APK.');
      }

      final totalBytes = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/carrin_update.apk');
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final sink = apkFile.openWrite();
      int receivedBytes = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = totalBytes > 0 ? (receivedBytes / totalBytes) : 0.0;
        onProgress(progress, receivedBytes, totalBytes);
      }

      await sink.flush();
      await sink.close();
      return apkFile;
    } finally {
      client.close();
    }
  }

  /// Checa se a versão A é maior que a versão B semanticamente (ex: 1.3.566 > 1.3.565)
  bool _isSemanticVersionGreater(String remote, String current) {
    try {
      final rParts = remote.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final cParts = current.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      while (rParts.length < 3) {
        rParts.add(0);
      }
      while (cParts.length < 3) {
        cParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (rParts[i] > cParts[i]) return true;
        if (rParts[i] < cParts[i]) return false;
      }
    } catch (_) {}
    return false;
  }
}

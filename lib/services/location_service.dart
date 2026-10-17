import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'default_supermarkets.dart';
import 'google_places_service.dart';

class LocationService {
  LocationService._privateConstructor();
  static final LocationService instance = LocationService._privateConstructor();

  /// Checks if location permission is granted, and requests it if not determined yet.
  Future<bool> requestPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('📍 LocationService: Serviços de localização desativados no dispositivo.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('📍 LocationService: Permissão de localização negada pelo usuário.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('📍 LocationService: Permissão de localização negada permanentemente.');
        return false;
      }

      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('📍 LocationService: Erro ao solicitar permissão: $e');
      return false;
    }
  }

  /// Obtém a posição precisa do usuário via GPS de alta precisão.
  /// Prioriza coordenadas recentes (< 15 segundos) e realiza leitura via satélite/alta acurácia.
  Future<Position?> getCurrentPosition({Duration maxAge = const Duration(seconds: 15), bool highAccuracy = true}) async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;

      // 1. Tenta obter a última posição conhecida SE for muito recente (< 15s)
      Position? position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        final age = DateTime.now().difference(position.timestamp);
        if (age <= maxAge) {
          return position;
        }
      }

      // 2. Busca nova coordenada via GPS de alta acurácia com timeout adequado
      position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        ),
      );
      return position;
    } catch (e) {
      debugPrint('📍 LocationService: Erro ao obter posição GPS alta precisão: $e');
      // Fallback secundário
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (_) {
        try {
          return await Geolocator.getLastKnownPosition();
        } catch (_) {
          return null;
        }
      }
    }
  }

  /// Retorna um stream contínuo de atualizações do GPS em tempo real (alta precisão).
  Stream<Position> getPositionStream({int distanceFilter = 2}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// Calculates geodesic distance between two coordinates in meters.
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Formats distance in meters into human-readable string.
  String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      final km = distanceInMeters / 1000;
      return '${km.toStringAsFixed(1)}km';
    }
  }

  /// Finds the closest supermarket from a list of saved markets if within radius.
  Map<String, dynamic>? findNearbyMarket(
    Position position,
    List<Map<String, dynamic>> savedMarkets,
  ) {
    Map<String, dynamic>? closestMarket;
    double minDistance = double.infinity;

    for (var market in savedMarkets) {
      final lat = (market['latitude'] as num?)?.toDouble();
      final lng = (market['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final radius = (market['radius_meters'] as num?)?.toDouble() ?? 150.0;
      final distance = calculateDistance(position.latitude, position.longitude, lat, lng);

      if (distance <= radius && distance < minDistance) {
        minDistance = distance;
        closestMarket = {
          ...market,
          'current_distance_meters': distance,
          'formatted_distance': formatDistance(distance),
        };
      }
    }

    return closestMarket;
  }

  /// Comprehensive nearby supermarket detection:
  /// 1. Saved markets registered by the user (highest priority, custom radius)
  /// 2. Official MWM preloaded supermarkets catalog (3,484+ stores across RJ, ES, SP)
  /// 3. Google Places API (if API key is configured in GooglePlacesService)
  /// 4. OpenStreetMap reverse geocode fallback
  Future<Map<String, dynamic>?> identifyNearbySupermarket(
    Position position,
    List<Map<String, dynamic>> savedMarkets,
  ) async {
    // 1. Prioridade máxima: Mercados salvos/customizados pelo usuário
    if (savedMarkets.isNotEmpty) {
      final savedMatch = findNearbyMarket(position, savedMarkets);
      if (savedMatch != null) {
        return savedMatch;
      }
    }

    // 1.5. Catálogo estático MWM em memória (instantâneo e offline)
    final mwmMatch = DefaultSupermarketsData.findNearestWithinRadius(
      position.latitude,
      position.longitude,
    );
    if (mwmMatch != null) {
      final dist = calculateDistance(
        position.latitude,
        position.longitude,
        mwmMatch.latitude,
        mwmMatch.longitude,
      );
      return {
        'name': mwmMatch.name,
        'latitude': mwmMatch.latitude,
        'longitude': mwmMatch.longitude,
        'radius_meters': mwmMatch.radiusMeters,
        'current_distance_meters': dist,
        'formatted_distance': formatDistance(dist),
        'source': 'mwm_catalog',
      };
    }

    // 2. Google Places API (se chave configurada)
    try {
      final googleMatch = await GooglePlacesService.instance.findNearbySupermarket(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMeters: 350.0,
      );
      if (googleMatch != null) {
        return googleMatch;
      }
    } catch (e) {
      debugPrint('📍 LocationService: Erro no Google Places: $e');
    }

    // 3. Fallback inteligente: OpenStreetMap Nominatim
    try {
      final osmName = await identifyPlaceName(position.latitude, position.longitude);
      if (osmName != null && osmName.isNotEmpty) {
        return {
          'name': osmName,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'radius_meters': 150.0,
          'current_distance_meters': 0.0,
          'formatted_distance': '0m',
          'source': 'osm',
        };
      }
    } catch (e) {
      debugPrint('📍 LocationService: Erro no fallback OSM: $e');
    }

    return null;
  }

  /// Tries to fetch commercial name of nearby place using Google Places first, then OpenStreetMap Nominatim.
  Future<String?> identifyPlaceName(double lat, double lng) async {
    // 1. Tenta pelo Google Places se houver chave configurada
    try {
      final googlePlace = await GooglePlacesService.instance.findNearbySupermarket(
        latitude: lat,
        longitude: lng,
        radiusMeters: 350.0,
      );
      if (googlePlace != null && googlePlace['name'] != null) {
        return googlePlace['name'] as String;
      }
    } catch (e) {
      debugPrint('📍 LocationService: Erro ao buscar pelo Google Places: $e');
    }

    // 2. Fallback OpenStreetMap Nominatim: DEVE RETORNAR APENAS SE FOR ESTABELECIMENTO COMERCIAL / SUPERMERCADO
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'CARRIN-ShoppingApp/1.3'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final osmClass = (data['class'] ?? '').toString().toLowerCase();
        final osmType = (data['type'] ?? '').toString().toLowerCase();
        final address = data['address'] as Map<String, dynamic>?;
        final shopType = (address?['shop'] ?? '').toString().toLowerCase();
        final rawName = (data['name'] ?? '').toString().trim();

        // Se for rua, rodovia, bairro, residencial, via pública ou estação: NUNCA tratar como mercado
        if (osmClass == 'highway' || osmClass == 'place' || osmClass == 'railway' || osmClass == 'boundary' || osmClass == 'building') {
          return null;
        }

        final bool isCommercialShop = osmClass == 'shop' ||
            osmType == 'supermarket' ||
            osmType == 'grocery' ||
            shopType.isNotEmpty;

        final bool isSupermarketName = rawName.toLowerCase().contains(RegExp(
          r'guanabara|supermercado|hipermercado|atacad[aã]o|assa[ií]|carrefour|extra|p[aã]o de a[cç][uú]car|mercado|hortifruti|sacol[aã]o|a[cç]ougue|mercearia'
        ));

        if (isCommercialShop || isSupermarketName) {
          if (rawName.isNotEmpty) return rawName;
          if (shopType.isNotEmpty) return 'Supermercado ($shopType)';
        }
      }
    } catch (e) {
      debugPrint('📍 LocationService: Erro ao identificar nome do local via OSM: $e');
    }
    return null;
  }
}

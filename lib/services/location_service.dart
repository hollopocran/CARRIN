import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
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

  /// Gets current user position quickly (prioritizes last known position, then quick GPS fix).
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;

      // 1. Tenta obter a última posição conhecida primeiro (instantâneo e zero consumo de bateria)
      Position? position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        final age = DateTime.now().difference(position.timestamp);
        // Se a posição conhecida tiver menos de 10 minutos, aproveita diretamente
        if (age.inMinutes < 10) {
          return position;
        }
      }

      // 2. Se não houver posição recente, busca uma nova com timeout de 3 segundos
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );
      return position;
    } catch (e) {
      debugPrint('📍 LocationService: Erro ao obter posição GPS: $e');
      // Fallback para última posição mesmo antiga
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
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
  /// 2. Google Places API (if API key is configured in GooglePlacesService)
  /// 3. OpenStreetMap reverse geocode fallback
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
          r'supermercado|hipermercado|atacad[aã]o|assa[ií]|carrefour|extra|p[aã]o de a[cç][uú]car|mercado|hortifruti|sacol[aã]o|a[cç]ougue|mercearia'
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

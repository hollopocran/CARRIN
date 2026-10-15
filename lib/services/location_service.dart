import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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

  /// Tries to fetch commercial name of nearby place using OpenStreetMap Nominatim reverse geocode.
  Future<String?> identifyPlaceName(double lat, double lng) async {
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
        final address = data['address'] as Map<String, dynamic>?;
        
        // Prioridades de nome comercial
        final name = data['name']?.toString();
        if (name != null && name.isNotEmpty) return name;

        if (address != null) {
          final shop = address['shop']?.toString();
          final amenity = address['amenity']?.toString();
          final road = address['road']?.toString();
          final suburb = address['suburb']?.toString() ?? address['neighbourhood']?.toString();

          if (shop != null && shop.isNotEmpty) {
            return 'Mercado ($shop)';
          }
          if (amenity != null && amenity.isNotEmpty) {
            return amenity;
          }
          if (road != null && road.isNotEmpty) {
            return suburb != null ? '$road - $suburb' : road;
          }
        }
      }
    } catch (e) {
      debugPrint('📍 LocationService: Erro ao identificar nome do local via OSM: $e');
    }
    return null;
  }
}

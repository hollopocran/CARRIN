import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

class GooglePlacesService {
  GooglePlacesService._privateConstructor();
  static final GooglePlacesService instance = GooglePlacesService._privateConstructor();

  static const String _prefApiKey = 'google_places_api_key';

  String? _cachedApiKey;
  bool _isInitialized = false;

  /// Retrieves the saved Google Places API key from SharedPreferences.
  Future<String?> getApiKey() async {
    if (_isInitialized) return _cachedApiKey;
    final prefs = await SharedPreferences.getInstance();
    _cachedApiKey = prefs.getString(_prefApiKey);
    _isInitialized = true;
    return _cachedApiKey;
  }

  /// Saves or removes the Google Places API key.
  Future<void> saveApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanKey = key?.trim();
    if (cleanKey == null || cleanKey.isEmpty) {
      await prefs.remove(_prefApiKey);
      _cachedApiKey = null;
    } else {
      await prefs.setString(_prefApiKey, cleanKey);
      _cachedApiKey = cleanKey;
    }
    _isInitialized = true;
  }

  /// Verifies if a given API key is valid by querying Google Places.
  Future<Map<String, dynamic>> testApiKey(String key) async {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) {
      return {'valid': false, 'message': 'Chave não informada.'};
    }

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=-23.5505,-46.6333&radius=500&type=supermarket&key=$cleanKey',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'] as String?;
        if (status == 'OK' || status == 'ZERO_RESULTS') {
          return {'valid': true, 'message': 'Chave válida e ativa!'};
        } else if (status == 'REQUEST_DENIED') {
          final errorMsg = data['error_message'] ?? 'Acesso negado. Verifique se a Places API está ativada no Google Cloud.';
          return {'valid': false, 'message': errorMsg};
        } else if (status == 'OVER_QUERY_LIMIT') {
          return {'valid': false, 'message': 'Limite de requisições atingido no Google Cloud.'};
        } else {
          return {'valid': false, 'message': 'Status retornado: $status'};
        }
      } else {
        return {'valid': false, 'message': 'Erro de resposta HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'valid': false, 'message': 'Falha na conexão: $e'};
    }
  }

  /// Finds nearby supermarkets using Google Places Nearby Search.
  Future<Map<String, dynamic>?> findNearbySupermarket({
    required double latitude,
    required double longitude,
    double radiusMeters = 350.0,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$latitude,$longitude&radius=${radiusMeters.round()}&type=supermarket&language=pt-BR&key=$apiKey',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'] as String?;

        if (status == 'OK') {
          final results = data['results'] as List<dynamic>?;
          if (results != null && results.isNotEmpty) {
            Map<String, dynamic>? closest;
            double minDistance = double.infinity;

            for (var place in results) {
              final geom = place['geometry']?['location'];
              final placeLat = (geom?['lat'] as num?)?.toDouble();
              final placeLng = (geom?['lng'] as num?)?.toDouble();
              final name = place['name']?.toString() ?? '';

              if (placeLat != null && placeLng != null && name.isNotEmpty) {
                final dist = LocationService.instance.calculateDistance(
                  latitude,
                  longitude,
                  placeLat,
                  placeLng,
                );

                if (dist <= radiusMeters && dist < minDistance) {
                  minDistance = dist;
                  closest = {
                    'name': name,
                    'place_id': place['place_id'],
                    'vicinity': place['vicinity'],
                    'latitude': placeLat,
                    'longitude': placeLng,
                    'radius_meters': radiusMeters,
                    'current_distance_meters': dist,
                    'formatted_distance': LocationService.instance.formatDistance(dist),
                    'source': 'google_places',
                  };
                }
              }
            }
            return closest;
          }
        } else if (status == 'REQUEST_DENIED' || status == 'OVER_QUERY_LIMIT') {
          debugPrint('📍 GooglePlacesService: $status - ${data['error_message']}');
          return null;
        }
      }
    } catch (e) {
      debugPrint('📍 GooglePlacesService: Erro na consulta ao Google Places: $e');
    }
    return null;
  }
}

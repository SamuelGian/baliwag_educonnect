import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather.dart';

class WeatherException implements Exception {
  final String message;
  WeatherException(this.message);
  @override
  String toString() => message;
}

/// Thin client for the free, keyless Open-Meteo API.
/// https://open-meteo.com/en/docs
///
/// Used to warn applicants about rain before they travel to submit physical
/// requirements (Barangay Certificate, Scholarship Office visits, scholar
/// orientation at Baliwag Bayan Hall) — see WeatherAdvisoryCard.
class WeatherService {
  static const _forecastEndpoint = 'https://api.open-meteo.com/v1/forecast';
  static const _geocodingEndpoint =
      'https://geocoding-api.open-meteo.com/v1/search';

  Future<WeatherSnapshot> fetchWeather({
    required double latitude,
    required double longitude,
    required String locationName,
  }) async {
    final uri = Uri.parse(_forecastEndpoint).replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': 'temperature_2m,relative_humidity_2m,weather_code,is_day',
      'daily': 'temperature_2m_max,temperature_2m_min',
      'timezone': 'Asia/Manila',
      'forecast_days': '1',
    });

    final response = await _get(uri, 'weather service');
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw WeatherException('Weather service returned an unreadable response.');
    }

    final current = body['current'] as Map<String, dynamic>?;
    final daily = body['daily'] as Map<String, dynamic>?;
    if (current == null || daily == null) {
      throw WeatherException('Weather data is unavailable for this location right now.');
    }

    try {
      final maxTemps = (daily['temperature_2m_max'] as List).cast<num>();
      final minTemps = (daily['temperature_2m_min'] as List).cast<num>();

      return WeatherSnapshot(
        locationName: locationName,
        temperature: (current['temperature_2m'] as num).toDouble(),
        minTemp: minTemps.first.toDouble(),
        maxTemp: maxTemps.first.toDouble(),
        humidity: (current['relative_humidity_2m'] as num).round(),
        weatherCode: (current['weather_code'] as num).round(),
        isDay: (current['is_day'] as num) == 1,
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      throw WeatherException('Weather service returned an unexpected data format.');
    }
  }

  /// Looks up a city/municipality by name so a student can check the
  /// forecast somewhere other than Baliwag before traveling there.
  Future<List<GeoLocation>> searchLocation(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(_geocodingEndpoint).replace(queryParameters: {
      'name': query.trim(),
      'count': '6',
      'language': 'en',
      'format': 'json',
    });

    final response = await _get(uri, 'location search');
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw WeatherException('Location search returned an unreadable response.');
    }

    final results = body['results'] as List<dynamic>?;
    if (results == null) return [];

    return results.map((r) {
      final m = r as Map<String, dynamic>;
      return GeoLocation(
        name: m['name'] as String,
        admin1: m['admin1'] as String?,
        country: m['country'] as String? ?? '',
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
      );
    }).toList();
  }

  Future<http.Response> _get(Uri uri, String label) async {
    final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw WeatherException(
        'Could not reach the $label. Check your internet connection.',
      );
    }
    if (response.statusCode != 200) {
      throw WeatherException('The $label returned an error (${response.statusCode}).');
    }
    return response;
  }
}

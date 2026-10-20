import 'package:flutter/foundation.dart';
import '../models/weather.dart';
import 'weather_service.dart';

enum WeatherLoadState { loading, loaded, error }

/// Holds the current weather lookup (location + snapshot) so the compact
/// dashboard badge and the full [WeatherAdvisoryModal] can share one fetch
/// instead of each hitting Open-Meteo independently — the badge shows
/// whatever this controller already has, and opening the modal reuses it
/// rather than starting a second load from scratch. Fetch/search logic
/// itself is unchanged from the previous WeatherCard — moved here as-is.
class WeatherController extends ChangeNotifier {
  static const _defaultLat = 14.9563;
  static const _defaultLon = 120.8967;
  static const _defaultName = 'Baliwag';

  final _service = WeatherService();

  double _lat = _defaultLat;
  double _lon = _defaultLon;
  String _name = _defaultName;

  WeatherLoadState state = WeatherLoadState.loading;
  WeatherSnapshot? weather;
  String? errorMessage;

  bool searching = false;
  String? searchError;

  String get locationName => _name;

  WeatherController() {
    load();
  }

  Future<void> load() async {
    state = WeatherLoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final snapshot = await _service.fetchWeather(
        latitude: _lat,
        longitude: _lon,
        locationName: _name,
      );
      weather = snapshot;
      state = WeatherLoadState.loaded;
      notifyListeners();
    } on WeatherException catch (e) {
      errorMessage = e.message;
      state = WeatherLoadState.error;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;
    searching = true;
    searchError = null;
    notifyListeners();
    try {
      final results = await _service.searchLocation(query);
      if (results.isEmpty) {
        searching = false;
        searchError = 'No matching city found.';
        notifyListeners();
        return;
      }
      final match = results.first;
      searching = false;
      _lat = match.latitude;
      _lon = match.longitude;
      _name = match.name;
      notifyListeners();
      await load();
    } on WeatherException catch (e) {
      searching = false;
      searchError = e.message;
      notifyListeners();
    }
  }
}

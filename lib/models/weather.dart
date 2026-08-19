import 'package:flutter/material.dart';

/// Maps Open-Meteo's WMO weather codes to a short label and icon.
/// https://open-meteo.com/en/docs (see "WMO Weather interpretation codes")
extension WeatherCodeX on int {
  /// Broad category, e.g. "Clouds" — paired with [weatherLabel] for a
  /// two-line "CLOUDS / FEW CLOUDS" style display.
  String get weatherMain {
    switch (this) {
      case 0:
      case 1:
        return 'Clear';
      case 2:
      case 3:
        return 'Clouds';
      case 45:
      case 48:
        return 'Fog';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
        return 'Rain';
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return 'Snow';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Weather';
    }
  }

  String get weatherLabel {
    switch (this) {
      case 0:
        return 'Clear Sky';
      case 1:
        return 'Mainly Clear';
      case 2:
        return 'Partly Cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 56:
      case 57:
        return 'Freezing Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 66:
      case 67:
        return 'Freezing Rain';
      case 71:
      case 73:
      case 75:
      case 77:
        return 'Snow';
      case 80:
      case 81:
      case 82:
        return 'Rain Showers';
      case 85:
      case 86:
        return 'Snow Showers';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Unknown';
    }
  }

  IconData get weatherIcon {
    switch (this) {
      case 0:
      case 1:
        return Icons.wb_sunny_rounded;
      case 2:
        return Icons.wb_cloudy_rounded;
      case 3:
        return Icons.cloud_rounded;
      case 45:
      case 48:
        return Icons.blur_on_rounded;
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return Icons.grain_rounded;
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
        return Icons.umbrella_rounded;
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return Icons.ac_unit_rounded;
      case 95:
      case 96:
      case 99:
        return Icons.thunderstorm_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  /// True for any code where carrying an umbrella / rescheduling an
  /// outdoor errand (e.g. a Barangay Hall visit) is worth flagging.
  bool get isRainRisk => const {
        51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99,
      }.contains(this);
}

class WeatherSnapshot {
  final String locationName;
  final double temperature;
  final double minTemp;
  final double maxTemp;
  final int humidity;
  final int weatherCode;
  final bool isDay;
  final DateTime updatedAt;

  const WeatherSnapshot({
    required this.locationName,
    required this.temperature,
    required this.minTemp,
    required this.maxTemp,
    required this.humidity,
    required this.weatherCode,
    required this.isDay,
    required this.updatedAt,
  });
}

/// A single match returned by the Open-Meteo geocoding endpoint when a
/// student searches for a city/municipality to check before traveling.
class GeoLocation {
  final String name;
  final String? admin1;
  final String country;
  final double latitude;
  final double longitude;

  const GeoLocation({
    required this.name,
    required this.admin1,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  String get label =>
      [name, if (admin1 != null && admin1!.isNotEmpty) admin1, country].join(', ');
}

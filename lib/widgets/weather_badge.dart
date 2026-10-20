import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/weather_controller.dart';
import 'animated_weather_icon.dart';
import 'weather_advisory_modal.dart';

/// Compact clickable replacement for the old full-size WeatherCard — sits
/// in the dashboard header next to the greeting instead of taking a whole
/// row. Tapping it opens [WeatherAdvisoryModal] with the full details,
/// reusing the same [WeatherController] (and its already-fetched data)
/// rather than starting a fresh lookup.
class WeatherBadge extends StatefulWidget {
  const WeatherBadge({super.key});

  @override
  State<WeatherBadge> createState() => _WeatherBadgeState();
}

class _WeatherBadgeState extends State<WeatherBadge> {
  late final WeatherController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WeatherController();
    _controller.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    showDialog(
      context: context,
      builder: (dialogContext) =>
          ChangeNotifierProvider<WeatherController>.value(
            value: _controller,
            child: const WeatherAdvisoryModal(),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = _controller.weather;
    final loading = _controller.state == WeatherLoadState.loading;
    final label = w != null
        ? '${w.temperature.toStringAsFixed(1)}°'
        : (loading ? '--°' : '?');
    return Semantics(
      button: true,
      label: 'Weather advisory, ${_controller.locationName}, $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else if (w != null)
                  AnimatedWeatherIcon(
                    weatherCode: w.weatherCode,
                    size: 18,
                    color: Colors.white,
                  )
                else
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 18,
                    color: Colors.white70,
                  ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/weather.dart';
import '../services/weather_controller.dart';
import '../theme/app_theme_context.dart';
import 'animated_weather_icon.dart';

/// Full Weather Advisory details, opened from [WeatherBadge]. Follows the
/// same rounded Dialog + ConstrainedBox(maxWidth, 85%-height) + header/
/// Flexible-scroll-body shape used elsewhere in the app (see
/// _ReviewDialog/_ScholarshipFormDialog in admin_dashboard_screen.dart) so
/// it looks like it belongs, not like a new modal style.
class WeatherAdvisoryModal extends StatefulWidget {
  const WeatherAdvisoryModal({super.key});

  @override
  State<WeatherAdvisoryModal> createState() => _WeatherAdvisoryModalState();
}

class _WeatherAdvisoryModalState extends State<WeatherAdvisoryModal> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WeatherController>();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.wb_cloudy_rounded,
                    size: 18,
                    color: context.scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Weather Advisory',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: controller.state == WeatherLoadState.loading
                        ? null
                        : controller.load,
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Check conditions before heading out to submit documents.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _buildSearchField(controller),
              if (controller.searching)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (controller.searchError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    controller.searchError!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.scheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(child: _buildBody(controller)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(WeatherController controller) {
    return TextField(
      controller: _searchController,
      onSubmitted: controller.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search for another city',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          onPressed: () => controller.search(_searchController.text),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 14,
        ),
      ),
    );
  }

  Widget _buildBody(WeatherController controller) {
    switch (controller.state) {
      case WeatherLoadState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        );
      case WeatherLoadState.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 32,
                color: context.appColors.textMuted,
              ),
              const SizedBox(height: 10),
              Text(
                controller.errorMessage ?? 'Could not load weather.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: controller.load,
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case WeatherLoadState.loaded:
        return _buildWeather(controller.weather!);
    }
  }

  Widget _buildWeather(WeatherSnapshot w) {
    final sunny = w.weatherCode == 0 || w.weatherCode == 1;
    return Column(
      children: [
        Text(
          w.locationName.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: context.appColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          w.weatherCode.weatherMain.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: context.appColors.textSecondary,
          ),
        ),
        Text(
          w.weatherCode.weatherLabel.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: context.appColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedWeatherIcon(
          weatherCode: w.weatherCode,
          size: 72,
          color: sunny ? context.appColors.accentDark : context.scheme.primary,
        ),
        const SizedBox(height: 10),
        Text(
          '${w.temperature.toStringAsFixed(1)}°',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: context.appColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: context.appColors.border),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MinMax(label: 'min', value: '${w.minTemp.toStringAsFixed(1)}°'),
            Container(width: 1, height: 26, color: context.appColors.border),
            _MinMax(label: 'max', value: '${w.maxTemp.toStringAsFixed(1)}°'),
          ],
        ),
        if (w.weatherCode.isRainRisk) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.infoBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.umbrella_rounded,
                  size: 16,
                  color: context.appColors.info,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bring an umbrella if you\'re heading out to submit documents.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.appColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MinMax extends StatelessWidget {
  final String label;
  final String value;

  const _MinMax({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: context.appColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

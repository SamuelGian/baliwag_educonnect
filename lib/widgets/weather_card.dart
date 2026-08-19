import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/weather.dart';
import '../services/weather_service.dart';
import '../theme/app_colors.dart';

enum _LoadState { loading, loaded, error }

/// Frosted-glass weather widget on the Student Dashboard. Lets a student
/// check conditions before traveling to submit physical requirements
/// (Barangay Hall, Scholarship Office, scholar orientation at the Baliwag
/// Bayan Hall), or look up another city/municipality before heading there.
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  static const _defaultLat = 14.9563;
  static const _defaultLon = 120.8967;
  static const _defaultName = 'Baliwag';

  final _service = WeatherService();
  final _searchController = TextEditingController();

  double _lat = _defaultLat;
  double _lon = _defaultLon;
  String _name = _defaultName;

  _LoadState _state = _LoadState.loading;
  WeatherSnapshot? _weather;
  String? _errorMessage;

  bool _searching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _state = _LoadState.loading;
      _errorMessage = null;
    });
    try {
      final snapshot = await _service.fetchWeather(
        latitude: _lat,
        longitude: _lon,
        locationName: _name,
      );
      if (!mounted) return;
      setState(() {
        _weather = snapshot;
        _state = _LoadState.loaded;
      });
    } on WeatherException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _state = _LoadState.error;
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await _service.searchLocation(query);
      if (!mounted) return;
      if (results.isEmpty) {
        setState(() {
          _searching = false;
          _searchError = 'No matching city found.';
        });
        return;
      }
      final match = results.first;
      _searchController.clear();
      setState(() {
        _searching = false;
        _lat = match.latitude;
        _lon = match.longitude;
        _name = match.name;
      });
      _load();
    } on WeatherException catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.68),
                AppColors.primaryLight.withValues(alpha: 0.48),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(right: -34, top: -34, child: _blob(110)),
              Positioned(left: -28, bottom: -28, child: _blob(84)),
              Padding(
                padding: const EdgeInsets.all(18),
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blob(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.wb_cloudy_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Weather Advisory',
                style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white70),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _state == _LoadState.loading ? null : _load,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSearchField(),
        if (_searching)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: LinearProgressIndicator(minHeight: 2, color: Colors.white),
          ),
        if (_searchError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _searchError!,
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
          ),
        const SizedBox(height: 14),
        _buildBody(),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: TextField(
        controller: _searchController,
        onSubmitted: _search,
        style: const TextStyle(fontSize: 12.5, color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Enter a city name',
          hintStyle: const TextStyle(fontSize: 12, color: Colors.white70),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          border: InputBorder.none,
          suffixIcon: IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded, size: 18, color: Colors.white),
            onPressed: () => _search(_searchController.text),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 22),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
            ),
          ),
        );
      case _LoadState.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Could not load weather.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
            TextButton(
              onPressed: _load,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Retry', style: TextStyle(fontSize: 12.5)),
            ),
          ],
        );
      case _LoadState.loaded:
        return _buildWeather(_weather!);
    }
  }

  Widget _buildWeather(WeatherSnapshot w) {
    final sunny = w.weatherCode == 0 || w.weatherCode == 1;
    return Column(
      children: [
        Text(
          w.locationName.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          w.weatherCode.weatherMain.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          w.weatherCode.weatherLabel.toUpperCase(),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Icon(
          w.weatherCode.weatherIcon,
          size: 48,
          color: sunny ? AppColors.accent : Colors.white,
        ),
        const SizedBox(height: 10),
        Text(
          '${w.temperature.toStringAsFixed(1)}°',
          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.22)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MinMax(label: 'min', value: '${w.minTemp.toStringAsFixed(1)}°'),
            Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.22)),
            _MinMax(label: 'max', value: '${w.maxTemp.toStringAsFixed(1)}°'),
          ],
        ),
        if (w.weatherCode.isRainRisk) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.umbrella_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bring an umbrella if you\'re heading out to submit documents.',
                  style: const TextStyle(fontSize: 10.5, color: Colors.white, height: 1.35),
                ),
              ),
            ],
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
          style: const TextStyle(fontSize: 10.5, color: Colors.white70, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 13.5, color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

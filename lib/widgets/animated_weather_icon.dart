import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/weather.dart';

/// A small looping animation per broad weather category (see
/// [WeatherCodeX.weatherMain]) — a drifting cloud, falling rain/snow, a
/// pulsing sun, or a flickering bolt — built from plain Flutter widgets
/// (Transform/Opacity/Icon) so it needs no extra package. Used both small
/// (the dashboard badge) and large (inside the advisory modal).
class AnimatedWeatherIcon extends StatefulWidget {
  final int weatherCode;
  final double size;
  final Color color;

  const AnimatedWeatherIcon({
    super.key,
    required this.weatherCode,
    required this.size,
    required this.color,
  });

  @override
  State<AnimatedWeatherIcon> createState() => _AnimatedWeatherIconState();
}

class _AnimatedWeatherIconState extends State<AnimatedWeatherIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final main = widget.weatherCode.weatherMain;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          switch (main) {
            case 'Clear':
              return _clear(t);
            case 'Clouds':
              return _clouds(t);
            case 'Fog':
              return _fog(t);
            case 'Drizzle':
            case 'Rain':
              return _rain(t);
            case 'Snow':
              return _snow(t);
            case 'Thunderstorm':
              return _storm(t);
            default:
              return Icon(
                widget.weatherCode.weatherIcon,
                size: widget.size,
                color: widget.color,
              );
          }
        },
      ),
    );
  }

  Widget _icon(IconData icon, {double scale = 1, double opacity = 1}) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: Icon(icon, size: widget.size, color: widget.color),
      ),
    );
  }

  // Slow rotation + a gentle breathing scale — a sun that feels alive
  // without spinning fast enough to be distracting at a glance.
  Widget _clear(double t) {
    final scale = 1.0 + 0.06 * math.sin(t * 2 * math.pi);
    return Transform.rotate(
      angle: t * 2 * math.pi,
      child: _icon(Icons.wb_sunny_rounded, scale: scale),
    );
  }

  // Drifts a couple pixels left-right, like a cloud caught in a light
  // breeze rather than sitting perfectly still.
  Widget _clouds(double t) {
    final dx = math.sin(t * 2 * math.pi) * widget.size * 0.08;
    return Transform.translate(
      offset: Offset(dx, 0),
      child: _icon(Icons.cloud_rounded),
    );
  }

  // Opacity breathing in and out to read as haze rather than a solid shape.
  Widget _fog(double t) {
    final opacity = 0.55 + 0.35 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
    return _icon(Icons.blur_on_rounded, opacity: opacity);
  }

  Widget _rain(double t) {
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Positioned(top: 0, child: _icon(Icons.cloud_rounded, scale: 0.9)),
        for (var i = 0; i < 3; i++) _drop(t, i),
      ],
    );
  }

  // Three droplets falling on staggered phases so they don't all move in
  // lockstep, fading out as they near the bottom.
  Widget _drop(double t, int i) {
    final phase = (t + i / 3) % 1.0;
    final top = widget.size * (0.55 + phase * 0.45);
    final left = widget.size * (0.28 + i * 0.22);
    final opacity = (1 - phase).clamp(0.0, 1.0);
    return Positioned(
      top: top,
      left: left,
      child: Opacity(
        opacity: opacity,
        child: Icon(
          Icons.water_drop_rounded,
          size: widget.size * 0.22,
          color: widget.color,
        ),
      ),
    );
  }

  Widget _snow(double t) {
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Positioned(top: 0, child: _icon(Icons.cloud_rounded, scale: 0.9)),
        for (var i = 0; i < 3; i++) _flake(t, i),
      ],
    );
  }

  Widget _flake(double t, int i) {
    final phase = (t + i / 3) % 1.0;
    final top = widget.size * (0.55 + phase * 0.45);
    final sway = math.sin((phase + i) * 2 * math.pi) * widget.size * 0.08;
    final left = widget.size * (0.28 + i * 0.22) + sway;
    final opacity = (1 - phase).clamp(0.0, 1.0);
    return Positioned(
      top: top,
      left: left,
      child: Opacity(
        opacity: opacity,
        child: Icon(
          Icons.ac_unit_rounded,
          size: widget.size * 0.2,
          color: widget.color,
        ),
      ),
    );
  }

  // A bolt that flashes briefly near the end of each loop instead of
  // pulsing continuously, closer to how real lightning reads.
  Widget _storm(double t) {
    final flash = t > 0.85 ? 1.0 : 0.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        _icon(Icons.cloud_rounded, scale: 0.95),
        Opacity(
          opacity: flash,
          child: Icon(
            Icons.bolt_rounded,
            size: widget.size * 0.7,
            color: widget.color,
          ),
        ),
      ],
    );
  }
}

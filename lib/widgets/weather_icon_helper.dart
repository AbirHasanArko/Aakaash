import 'package:flutter/material.dart';

import '../core/weather_codes.dart';

/// Material-symbol icon for an OWM weather code. No emoji, no
/// gradient tint — the icon sits inside a primary-tinted circle that
/// adapts to the active Material 3 ColorScheme.
class WeatherVisual {
  final IconData icon;
  const WeatherVisual({required this.icon});
}

WeatherVisual visualFor(int code, {required bool isDay}) {
  if (code >= 200 && code < 300) {
    return const WeatherVisual(icon: Icons.thunderstorm_rounded);
  }
  if (code >= 300 && code < 400) {
    return const WeatherVisual(icon: Icons.grain_rounded);
  }
  if (code >= 500 && code < 600) {
    // 5xx = rain. Sub-codes:
    //   500-501 light; 502-504 heavy; 511 freezing; 520-522 shower.
    if (code == 511) {
      return const WeatherVisual(icon: Icons.ac_unit_rounded);
    }
    if (code >= 502 && code < 510) {
      // heavy rain / very heavy / extreme — storm icon reads well at large size
      return const WeatherVisual(icon: Icons.storm_rounded);
    }
    if (code >= 520 && code < 600) {
      // shower rain
      return const WeatherVisual(icon: Icons.shower_rounded);
    }
    return const WeatherVisual(icon: Icons.water_drop_rounded);
  }
  if (code >= 600 && code < 700) {
    return const WeatherVisual(icon: Icons.ac_unit_rounded);
  }
  if (code >= 700 && code < 800) {
    return const WeatherVisual(icon: Icons.filter_drama_rounded);
  }
  if (WeatherCodes.isClear(code)) {
    return WeatherVisual(
      icon: isDay ? Icons.wb_sunny_rounded : Icons.nightlight_rounded,
    );
  }
  if (code == 801 || code == 802) {
    return const WeatherVisual(icon: Icons.cloud_queue_rounded);
  }
  return const WeatherVisual(icon: Icons.cloud_rounded);
}

/// Tinted Material weather chip with a gentle pulse — keeps the
/// icon the centerpiece without resorting to Lottie or emoji.
class AnimatedWeatherGlyph extends StatefulWidget {
  final int code;
  final bool isDay;
  final double size;
  final Color? color;
  const AnimatedWeatherGlyph({
    super.key,
    required this.code,
    required this.isDay,
    this.size = 80,
    this.color,
  });

  @override
  State<AnimatedWeatherGlyph> createState() => _AnimatedWeatherGlyphState();
}

class _AnimatedWeatherGlyphState extends State<AnimatedWeatherGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = visualFor(widget.code, isDay: widget.isDay);
    final scheme = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: (widget.color ?? scheme.primaryContainer).withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(
          v.icon,
          size: widget.size * 0.6,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}


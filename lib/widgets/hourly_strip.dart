import 'package:flutter/material.dart';

import '../models/weather_models.dart';
import '../utils/date_format.dart';
import 'glass_card.dart';
import 'weather_icon_helper.dart';

/// Horizontal hourly forecast strip.
///
/// Text colors come from the active M3 `ColorScheme` so the strip
/// reads correctly in both light and dark mode. The legacy
/// `textColor` parameter is preserved for back-compat with call
/// sites that passed an explicit colour.
class HourlyStrip extends StatelessWidget {
  final List<HourlyForecast> hours;
  final Color textColor;
  const HourlyStrip({super.key, required this.hours, this.textColor = Colors.transparent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = textColor == Colors.transparent ? scheme.onSurface : textColor;
    if (hours.isEmpty) {
      return GlassCard(
        child: SizedBox(
          height: 110,
          child: Center(
            child: Text(
              'Hourly forecast not available for this location.',
              style: TextStyle(color: base),
            ),
          ),
        ),
      );
    }
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: hours.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemBuilder: (_, i) {
            final h = hours[i];
            return SizedBox(
              width: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    i == 0 ? 'Now' : DateFmt.time(h.time),
                    style: TextStyle(
                      color: base,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AnimatedWeatherGlyph(
                    code: h.weatherCode,
                    isDay: true,
                    size: 28,
                  ),
                  Text(
                    '${h.temp.round()}°',
                    style: TextStyle(
                      color: base,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (h.pop > 0.05)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.water_drop_rounded, size: 10, color: base.withValues(alpha: 0.7)),
                        Text(
                          '${(h.pop * 100).round()}%',
                          style: TextStyle(color: base.withValues(alpha: 0.7), fontSize: 10),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/weather_models.dart';
import '../utils/date_format.dart';
import 'glass_card.dart';
import 'weather_icon_helper.dart';

/// 5-day forecast list with a temperature range bar.
///
/// All text colours come from the active M3 ColorScheme so the row
/// reads correctly in both light and dark mode. The legacy
/// `textColor` parameter is kept for back-compat with call sites
/// that passed an explicit colour.
class DailyList extends StatelessWidget {
  final List<DailyForecast> days;
  final Color textColor;
  const DailyList({super.key, required this.days, this.textColor = Colors.transparent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = textColor == Colors.transparent ? scheme.onSurface : textColor;
    if (days.isEmpty) {
      return GlassCard(
        child: SizedBox(
          height: 80,
          child: Center(
            child: Text(
              '5-day forecast not available for this location.',
              style: TextStyle(color: base),
            ),
          ),
        ),
      );
    }
    final allTemps = days.expand((d) => [d.tempMin, d.tempMax]).toList();
    final globalMin = allTemps.reduce((a, b) => a < b ? a : b);
    final globalMax = allTemps.reduce((a, b) => a > b ? a : b);
    final span = (globalMax - globalMin).clamp(1, 60).toDouble();

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          for (int i = 0; i < days.length; i++)
            _DailyRow(
              entry: days[i],
              globalMin: globalMin.toDouble(),
              globalMax: globalMax.toDouble(),
              span: span,
              textColor: base,
              isToday: i == 0,
              trackColor: scheme.surfaceContainerHighest,
              barStart: scheme.tertiary,
              barEnd: scheme.primary,
            ),
        ],
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  final DailyForecast entry;
  final double globalMin;
  final double globalMax;
  final double span;
  final Color textColor;
  final bool isToday;
  final Color trackColor;
  final Color barStart;
  final Color barEnd;

  const _DailyRow({
    required this.entry,
    required this.globalMin,
    required this.globalMax,
    required this.span,
    required this.textColor,
    required this.isToday,
    required this.trackColor,
    required this.barStart,
    required this.barEnd,
  });

  @override
  Widget build(BuildContext context) {
    final start = ((entry.tempMin - globalMin) / span).clamp(0.0, 1.0);
    final end = ((entry.tempMax - globalMin) / span).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              isToday ? 'Today' : DateFmt.shortDay(entry.date),
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedWeatherGlyph(code: entry.weatherCode, isDay: true, size: 26),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '${entry.tempMin.round()}°',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 6,
                  color: trackColor,
                  child: Row(
                    children: [
                      if ((start * 100).toInt() > 0)
                        Spacer(flex: (start * 100).toInt().clamp(0, 100)),
                      Container(
                        height: 6,
                        width: ((end - start) * 100).clamp(6, 100).toDouble(),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [barStart, barEnd],
                          ),
                        ),
                      ),
                      if (((1 - end) * 100).toInt() > 0)
                        Spacer(flex: ((1 - end) * 100).toInt().clamp(0, 100)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${entry.tempMax.round()}°',
              textAlign: TextAlign.right,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

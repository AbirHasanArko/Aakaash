import 'package:flutter/material.dart';

import '../models/weather_models.dart';
import 'metric_tile.dart';

class DetailsGrid extends StatelessWidget {
  final CurrentWeather current;
  final Color textColor;
  const DetailsGrid({super.key, required this.current, this.textColor = Colors.transparent});

  @override
  Widget build(BuildContext context) {
    final windKmh = (current.windSpeed * 3.6).round();
    final visibilityKm = (current.visibility / 1000).toStringAsFixed(1);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        MetricTile(
          icon: Icons.thermostat_rounded,
          label: 'Feels like',
          value: '${current.feelsLike.round()}°C',
          textColor: textColor,
        ),
        MetricTile(
          icon: Icons.water_drop_rounded,
          label: 'Humidity',
          value: '${current.humidity}%',
          textColor: textColor,
        ),
        MetricTile(
          icon: Icons.air_rounded,
          label: 'Wind',
          value: '$windKmh km/h',
          textColor: textColor,
        ),
        MetricTile(
          icon: Icons.compress_rounded,
          label: 'Pressure',
          value: '${current.pressure} hPa',
          textColor: textColor,
        ),
        MetricTile(
          icon: Icons.visibility_rounded,
          label: 'Visibility',
          value: '$visibilityKm km',
          textColor: textColor,
        ),
        MetricTile(
          icon: Icons.wb_sunny_rounded,
          label: 'UV Index',
          value: current.uvIndex != null ? current.uvIndex!.toStringAsFixed(1) : '—',
          textColor: textColor,
        ),
      ],
    );
  }
}

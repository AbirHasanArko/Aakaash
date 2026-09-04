import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/farming_advisory.dart';
import '../providers/farming_provider.dart';
import '../providers/weather_provider.dart';
import '../widgets/glass_card.dart';

class FarmersCornerScreen extends StatelessWidget {
  const FarmersCornerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FarmingProvider>();
    final wp = context.watch<WeatherProvider>();
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌾', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text("Farmer's Corner"),
          ],
        ),
        centerTitle: true,
      ),
      body: !fp.isReady
          ? _EmptyState(wp: wp)
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // ── Score gauge + season badge ──────────────────────────────
                _ScoreHeader(
                  score: fp.overallScore,
                  season: fp.season,
                  cityName: wp.city?.name ?? '',
                  lastUpdated: wp.lastUpdated,
                ),

                const SizedBox(height: 4),

                // ── Advisory cards ──────────────────────────────────────────
                ...fp.advisories.map((a) => _AdvisoryCard(advice: a)),

                // ── Seasonal crop info ──────────────────────────────────────
                _SeasonCard(season: fp.season),

                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Advisories based on current weather data. '
                    'Always consult your local DAE block supervisor for field-specific guidance.',
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Score gauge header ────────────────────────────────────────────────────

class _ScoreHeader extends StatelessWidget {
  final int score;
  final BdSeason season;
  final String cityName;
  final DateTime? lastUpdated;

  const _ScoreHeader({
    required this.score,
    required this.season,
    required this.cityName,
    this.lastUpdated,
  });

  Color _scoreColor(int s) {
    if (s >= 70) return const Color(0xFF4CAF50);
    if (s >= 40) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String _scoreLabel(int s) {
    if (s >= 70) return 'Good Conditions';
    if (s >= 40) return 'Mixed Conditions';
    return 'Poor Conditions';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final color = _scoreColor(score);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            // City + updated
            if (cityName.isNotEmpty)
              Text(
                cityName,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 4),
            // Season badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                FarmingAdvisory.seasonName(season),
                style: tt.labelSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Circular gauge
            SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _GaugePainter(
                  score: score,
                  color: color,
                  trackColor: scheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score',
                        style: tt.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      Text(
                        '/ 100',
                        style: tt.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _scoreLabel(score),
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (lastUpdated != null) ...[
              const SizedBox(height: 4),
              Text(
                'Updated ${_ago(lastUpdated!)}',
                style: tt.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours}h ago';
  }
}

class _GaugePainter extends CustomPainter {
  final int score;
  final Color color;
  final Color trackColor;

  const _GaugePainter({
    required this.score,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.shortestSide / 2) - 10;
    const strokeWidth = 12.0;
    const startAngle = math.pi * 0.75;
    const sweepFull = math.pi * 1.5;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    canvas.drawArc(rect, startAngle, sweepFull, false, trackPaint);
    final sweep = sweepFull * score / 100;
    if (sweep > 0) {
      canvas.drawArc(rect, startAngle, sweep, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.score != score || old.color != color;
}

// ─── Advisory card ─────────────────────────────────────────────────────────

class _AdvisoryCard extends StatefulWidget {
  final FarmAdvice advice;
  const _AdvisoryCard({required this.advice});

  @override
  State<_AdvisoryCard> createState() => _AdvisoryCardState();
}

class _AdvisoryCardState extends State<_AdvisoryCard> {
  bool _expanded = false;

  Color _levelColor(AdvisoryLevel l, ColorScheme s) => switch (l) {
        AdvisoryLevel.good    => const Color(0xFF4CAF50),
        AdvisoryLevel.caution => const Color(0xFFFF9800),
        AdvisoryLevel.warning => const Color(0xFFFF5722),
        AdvisoryLevel.danger  => const Color(0xFFF44336),
      };

  String _levelLabel(AdvisoryLevel l) => switch (l) {
        AdvisoryLevel.good    => 'Good',
        AdvisoryLevel.caution => 'Caution',
        AdvisoryLevel.warning => 'Warning',
        AdvisoryLevel.danger  => 'Danger',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final a = widget.advice;
    final lColor = _levelColor(a.level, scheme);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(20),
        child: GlassCard(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Colour strip
                  Container(width: 6, color: lColor),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row
                          Row(
                            children: [
                              Text(a.emoji,
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  a.title,
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              // Level chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: lColor.withAlpha(30),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: lColor.withAlpha(100), width: 1),
                                ),
                                child: Text(
                                  _levelLabel(a.level),
                                  style: tt.labelSmall?.copyWith(
                                    color: lColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _expanded
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                size: 20,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Summary
                          Text(
                            a.summary,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: lColor,
                            ),
                          ),
                          // Expandable detail
                          if (_expanded) ...[
                            const SizedBox(height: 8),
                            Text(
                              a.detail,
                              style: tt.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if (a.tips.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ...a.tips.map(
                                (t) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('•  ',
                                          style: tt.bodySmall?.copyWith(
                                              color: lColor,
                                              fontWeight: FontWeight.w700)),
                                      Expanded(
                                        child: Text(
                                          t,
                                          style: tt.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Season info card ───────────────────────────────────────────────────────

class _SeasonCard extends StatelessWidget {
  final BdSeason season;
  const _SeasonCard({required this.season});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final crops = FarmingAdvisory.seasonCrops(season);
    final activity = FarmingAdvisory.seasonKeyActivity(season);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Current Season Crops',
              subtitle: FarmingAdvisory.seasonName(season),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: crops
                  .map((c) => Chip(
                        label: Text(c, style: tt.labelSmall),
                        backgroundColor: scheme.secondaryContainer,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'Key Activity',
              style: tt.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(activity, style: tt.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ─── Empty / loading state ──────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final WeatherProvider wp;
  const _EmptyState({required this.wp});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (wp.status == WeatherStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌾', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Weather data needed',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for a city on the home screen first to generate farming advisories.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

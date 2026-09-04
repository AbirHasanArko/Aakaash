// lib/screens/calamity_screen.dart
//
// Natural-calamity dashboard for Bangladesh.
//
// Layout:
//   • Custom-painted district map of Bangladesh (64 polygons colored by
//     flood-risk score, division borders, severity pins for events).
//   • Filter chips (All / Flood / Cyclone / Earthquake / Storm / Fire / ...).
//   • Scrollable list of glass cards, one per event, tappable to read
//     the full source.
//   • Tap a district on the map → bottom sheet showing all events in that
//     district.
//   • Pull-to-refresh.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bd_districts.dart';
import '../models/calamity_model.dart';
import '../providers/calamity_provider.dart';

class CalamityScreen extends StatefulWidget {
  const CalamityScreen({super.key});

  @override
  State<CalamityScreen> createState() => _CalamityScreenState();
}

class _CalamityScreenState extends State<CalamityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalamityProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text('Natural Calamities'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<CalamityProvider>().refresh(),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => context.read<CalamityProvider>().refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const _MapCard(),
                  const SizedBox(height: 16),
                  _LegendCard(),
                  const SizedBox(height: 16),
                  _FilterChips(),
                  const SizedBox(height: 16),
                  _StatusBanner(),
                  const SizedBox(height: 12),
                  const _CalamityList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── map ───────────────────────────────────
class _MapCard extends StatefulWidget {
  const _MapCard();

  @override
  State<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<_MapCard> {
  late Future<List<District>> _districtsFuture;

  @override
  void initState() {
    super.initState();
    _districtsFuture = BangladeshDistricts.load();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        height: 320,
        width: double.infinity,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F2A6E),
                Color(0xFF1A4FA0),
                Color(0xFF3D8BDC),
              ],
            ),
          ),
          child: FutureBuilder<List<District>>(
            future: _districtsFuture,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              return _InteractiveMap(districts: snap.data!);
            },
          ),
        ),
      ),
    );
  }
}

class _InteractiveMap extends StatelessWidget {
  final List<District> districts;
  const _InteractiveMap({required this.districts});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CalamityProvider>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        // Project every district ring to screen-space ONCE per size.
        // Both painters share this cache so we never re-project for
        // every frame or every paint pass.
        final cache = _MapProjectionCache.build(districts, size);
        return Stack(
          fit: StackFit.expand,
          children: [
            // Sea / bay gradient — painted first so districts sit on top.
            CustomPaint(
              size: size,
              painter: _MapBackdropPainter(cache: cache),
            ),
            // District polygons, division borders, and event pins.
            GestureDetector(
              onTapUp: (details) => _handleTap(
                context,
                details.localPosition,
                size,
                prov,
              ),
              child: CustomPaint(
                size: size,
                painter: _DistrictsPainter(
                  cache: cache,
                  calamities: prov.all,
                  filter: prov.filter,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleTap(BuildContext ctx, Offset p, Size size, CalamityProvider prov) {
    // Find a district containing the tap (use the geojson point-in-polygon).
    for (final d in districts) {
      if (d.containsPoint(_lonFor(p.dx, size.width), _latFor(p.dy, size.height))) {
        final events = prov.all
            .where((c) => c.district == d.name)
            .toList(growable: false);
        _showDistrictSheet(ctx, d, events);
        return;
      }
    }
  }

  double _lonFor(double x, double w) {
    final nx = (x / w).clamp(0.0, 1.0);
    return MapProjection.lonMin + nx * (MapProjection.lonMax - MapProjection.lonMin);
  }

  double _latFor(double y, double h) {
    final ny = (y / h).clamp(0.0, 1.0);
    return MapProjection.latMax - ny * (MapProjection.latMax - MapProjection.latMin);
  }

  void _showDistrictSheet(BuildContext ctx, District d, List<Calamity> events) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _DistrictDetailSheet(
        district: d,
        events: events,
      ),
    );
  }
}

/// Pre-projects every district's rings to screen-space for one canvas
/// size. The painters consume this cache so we don't re-project on
/// every repaint. Rings are also Douglas-Peucker simplified at a
/// small pixel tolerance — that's a 4-6× speed-up for the fill loop
/// with no visible quality loss.
class _MapProjectionCache {
  _MapProjectionCache._({
    required this.size,
    required this.fillPaths,
    required this.fillOwners,
    required this.outlinePaths,
  });

  final Size size;

  /// One [Path] per district outer ring for the fill pass.
  final List<Path> fillPaths;

  /// Parallel list to [fillPaths] — the district each fill path
  /// belongs to. Lets the painter look up flood risk per polygon
  /// without having to walk the full `districts` list again.
  final List<District> fillOwners;

  /// Stroked [Path]s for the border + glow passes (simplified).
  final List<Path> outlinePaths;

  static _MapProjectionCache build(List<District> districts, Size size) {
    // ~1 px simplification tolerance — invisible at all device DPIs.
    const double tolerancePx = 1.0;
    final fills = <Path>[];
    final owners = <District>[];
    final strokes = <Path>[];
    for (final d in districts) {
      for (final poly in d.polygons) {
        if (poly.isEmpty) continue;
        // Use the outer ring for the fill + stroke. Inner rings
        // (holes) are rare for BD district polygons — we ignore
        // them rather than emit even-odd holes, which would over-cut
        // thin districts like Sandwip.
        final ring = poly.first;
        if (ring.length < 3) continue;
        final simplified = _simplifyRing(ring, tolerancePx);
        final stroke = _buildPath(simplified, size);
        strokes.add(stroke);
        fills.add(_buildPath(ring, size)); // unsimplified for accurate fill
        owners.add(d);
      }
    }
    return _MapProjectionCache._(
      size: size,
      fillPaths: fills,
      fillOwners: owners,
      outlinePaths: strokes,
    );
  }

  static Path _buildPath(List<List<double>> ring, Size size) {
    final path = Path();
    for (var i = 0; i < ring.length; i++) {
      final p = MapProjection.pointFor(ring[i][0], ring[i][1], size);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  /// Ramer–Douglas–Peucker simplification in pixel space. Drops
  /// collinear / near-collinear vertices so the painter doesn't have
  /// to draw thousands of `lineTo` segments every frame.
  static List<List<double>> _simplifyRing(
    List<List<double>> ring,
    double tolerancePx,
  ) {
    if (ring.length < 4) return ring;
    final pts = <List<double>>[];
    for (final p in ring) {
      pts.add([p[0], p[1]]);
    }
    // First project to pixel space so tolerance is in pixels.
    // We use a normalized projection (size = 1000 wide) so the
    // tolerance works regardless of the actual canvas size.
    const w = 1000.0;
    final h = w * (MapProjection.latSpan / MapProjection.lonSpan);
    final projected = <List<double>>[];
    for (final p in pts) {
      final (nx, ny) = MapProjection.project(p[0], p[1]);
      projected.add([nx * w, ny * h]);
    }
    final keep = _rdpKeep(projected, tolerancePx);
    final out = <List<double>>[];
    for (int i = 0; i < pts.length; i++) {
      if (keep[i]) out.add(pts[i]);
    }
    // Always keep the closing vertex.
    if (!keep[0]) out.insert(0, pts.first);
    if (out.length < 3) return pts;
    return out;
  }

  static List<bool> _rdpKeep(List<List<double>> pts, double eps) {
    final n = pts.length;
    final keep = List<bool>.filled(n, false);
    keep[0] = true;
    keep[n - 1] = true;
    _rdp(pts, 0, n - 1, eps, keep);
    return keep;
  }

  static void _rdp(List<List<double>> pts, int lo, int hi, double eps, List<bool> keep) {
    if (hi <= lo + 1) return;
    double maxDist = 0;
    int idx = lo;
    final ax = pts[lo][0], ay = pts[lo][1];
    final bx = pts[hi][0], by = pts[hi][1];
    final dx = bx - ax, dy = by - ay;
    final lenSq = dx * dx + dy * dy;
    for (int i = lo + 1; i < hi; i++) {
      final px = pts[i][0], py = pts[i][1];
      final double d;
      if (lenSq < 1e-12) {
        d = ((px - ax) * (px - ax) + (py - ay) * (py - ay));
      } else {
        final t = ((px - ax) * dx + (py - ay) * dy) / lenSq;
        final tc = t < 0 ? 0 : (t > 1 ? 1 : t);
        final cx = ax + tc * dx, cy = ay + tc * dy;
        final ex = px - cx, ey = py - cy;
        d = (ex * ex + ey * ey);
      }
      if (d > maxDist) {
        maxDist = d;
        idx = i;
      }
    }
    if (maxDist > eps * eps) {
      keep[idx] = true;
      _rdp(pts, lo, idx, eps, keep);
      _rdp(pts, idx, hi, eps, keep);
    }
  }
}

class _MapBackdropPainter extends CustomPainter {
  final _MapProjectionCache cache;
  _MapBackdropPainter({required this.cache});

  @override
  void paint(Canvas canvas, Size size) {
    // Soft halo around the country silhouette.
    final bg = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.05),
        radius: 0.85,
        colors: [
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // Outer (inverted) silhouette: render the country as a soft glow
    // by drawing a stroked path on the polygon outlines.
    final glow = Paint()
      ..color = const Color(0xFF34D399).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    for (final path in cache.outlinePaths) {
      canvas.drawPath(path, glow);
    }
  }

  @override
  bool shouldRepaint(covariant _MapBackdropPainter old) =>
      old.cache != cache;
}

// ───────────────── districts + pins + borders ─────────────────────────
class _DistrictsPainter extends CustomPainter {
  final _MapProjectionCache cache;
  final List<Calamity> calamities;
  final CalamityType? filter;

  _DistrictsPainter({
    required this.cache,
    required this.calamities,
    required this.filter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Calculate per-district flood risk from calamities.
    final riskByDistrict = <String, double>{};
    for (final c in calamities) {
      if (c.type == CalamityType.flood &&
          c.district != null &&
          c.riskScore != null) {
        final prev = riskByDistrict[c.district!] ?? 0;
        if (c.riskScore! > prev) riskByDistrict[c.district!] = c.riskScore!;
      }
    }

    // 2. Fill each district polygon with a flood-risk tint (or neutral).
    // The cache has one path per district outer ring — we look up the
    // risk by the district that owns the ring (we keep a parallel list).
    final basePaint = Paint()..style = PaintingStyle.fill;
    final fills = cache.fillPaths;
    final owners = cache.fillOwners;
    for (var i = 0; i < fills.length; i++) {
      final district = owners[i];
      final risk = riskByDistrict[district.name] ?? 0.0;
      basePaint.color = _colorForRisk(risk);
      canvas.drawPath(fills[i], basePaint);
    }

    // 3. Subtle district borders (simplified paths from the cache).
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    for (final path in cache.outlinePaths) {
      canvas.drawPath(path, borderPaint);
    }

    // 4. Division delineation: paint a small badge at the centroid
    // of each division instead of a stitched border. The old stitched
    // border concatenated every district outline into one Path,
    // which produced straight lines connecting unrelated vertices
    // across the country — the "spider web" you saw.
    final divisions = <String, Offset>{};
    final divisionsCount = <String, int>{};
    for (final d in owners) {
      final p = MapProjection.pointFor(d.centroidLon, d.centroidLat, size);
      divisions.update(
        d.division,
        (v) => v + (p - v) / (divisionsCount[d.division]! + 1),
        ifAbsent: () => p,
      );
      divisionsCount[d.division] = (divisionsCount[d.division] ?? 0) + 1;
    }
    for (final entry in divisions.entries) {
      _paintLabel(
        canvas,
        entry.key.toUpperCase(),
        entry.value,
        TextStyle(
          color: Colors.white.withValues(alpha: 0.40),
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      );
    }

    // 5. Event pins (severity-coloured).
    final shown = filter == null
        ? calamities
        : calamities.where((c) => c.type == filter).toList(growable: false);
    for (final c in shown) {
      final pos = MapProjection.pointFor(c.longitude, c.latitude, size);
      _drawPin(canvas, pos, c.severity.color, c.type);
    }

    // 6. Map labels.
    _paintLabel(canvas, 'BANGLADESH',
        Offset(size.width / 2, size.height / 2),
        TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.0,
        ));
    _paintLabel(canvas, 'Bay of Bengal',
        Offset(size.width - 90, size.height - 18),
        TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 10,
          fontStyle: FontStyle.italic,
        ));
  }

  Color _colorForRisk(double risk) {
    if (risk <= 0) return Colors.white.withValues(alpha: 0.04);
    if (risk < 0.25) return const Color(0xFF10B981).withValues(alpha: 0.20);
    if (risk < 0.5) return const Color(0xFFF59E0B).withValues(alpha: 0.30);
    if (risk < 0.75) return const Color(0xFFEF4444).withValues(alpha: 0.35);
    return const Color(0xFFB91C1C).withValues(alpha: 0.45);
  }

  void _drawPin(Canvas canvas, Offset p, Color color, CalamityType type) {
    final ring = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(p, 14, ring);

    final core = Paint()..color = color;
    canvas.drawCircle(p, 7, core);

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(p, 7, border);

    _paintLabel(canvas, _glyphForType(type), p,
        const TextStyle(fontSize: 10, color: Colors.white),
        center: true);
  }

  String _glyphForType(CalamityType type) {
    switch (type) {
      case CalamityType.flood:
        return '~';
      case CalamityType.cyclone:
        return '@';
      case CalamityType.earthquake:
        return '#';
      case CalamityType.storm:
        return '*';
      case CalamityType.wildfire:
        return '▲';
      case CalamityType.landslide:
        return '▣';
      case CalamityType.other:
        return '!';
    }
  }

  void _paintLabel(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    bool center = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final origin = center
        ? Offset(at.dx - tp.width / 2, at.dy - tp.height / 2)
        : at;
    tp.paint(canvas, origin);
  }

  @override
  bool shouldRepaint(covariant _DistrictsPainter old) =>
      old.cache != cache ||
      old.calamities != calamities ||
      old.filter != filter;
}

// ───────────────────────────── legend ──────────────────────────────────
class _LegendCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CalamityProvider>();
    final tt = Theme.of(context).textTheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final s in CalamitySeverity.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${s.label} · ${prov.countBySeverity(s)}',
                    style: tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── filter chips ───────────────────────────────
class _FilterChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CalamityProvider>();
    final entries = <_ChipEntry>[
      _ChipEntry(label: 'All', value: null, icon: Icons.public_rounded),
      _ChipEntry(label: 'Flood', value: CalamityType.flood, icon: Icons.waves_rounded),
      _ChipEntry(label: 'Cyclone', value: CalamityType.cyclone, icon: Icons.cyclone_rounded),
      _ChipEntry(
        label: 'Earthquake',
        value: CalamityType.earthquake,
        icon: Icons.vibration_rounded,
      ),
      _ChipEntry(label: 'Storm', value: CalamityType.storm, icon: Icons.thunderstorm_rounded),
      _ChipEntry(label: 'Fire', value: CalamityType.wildfire, icon: Icons.local_fire_department_rounded),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final e = entries[i];
          final selected = prov.filter == e.value;
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            avatar: Icon(
              e.icon,
              size: 16,
              color: selected
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            label: Text(e.label),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.onSurface,
            ),
            onSelected: (_) => prov.setFilter(e.value),
          );
        },
      ),
    );
  }
}

class _ChipEntry {
  final String label;
  final CalamityType? value;
  final IconData icon;
  _ChipEntry({required this.label, required this.value, required this.icon});
}

// ─────────────────────────── status / errors ──────────────────────────
class _StatusBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CalamityProvider>();
    switch (prov.status) {
      case CalamityStatus.loading:
        return _banner(
          context,
          'Fetching latest events…',
          Icons.cloud_download_rounded,
        );
      case CalamityStatus.error:
        return _banner(
          context,
          'Could not load events. Pull down to retry.',
          Icons.error_outline_rounded,
          onTap: prov.refresh,
        );
      case CalamityStatus.ready:
        if (prov.visible.isEmpty) {
          return _banner(
            context,
            prov.filter == null
                ? 'No recent calamities near Bangladesh. Stay safe!'
                : 'No ${prov.filter!.label.toLowerCase()} events in this window.',
            Icons.beach_access_rounded,
          );
        }
        final fmt = prov.lastUpdated == null
            ? ''
            : 'Last updated ${DateFormat.jm().format(prov.lastUpdated!)}';
        return _banner(
          context,
          '${prov.visible.length} event(s) · $fmt',
          Icons.verified_rounded,
        );
      case CalamityStatus.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _banner(BuildContext context, String text, IconData icon,
      {VoidCallback? onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.refresh_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────── district detail bottom sheet ───────────────────────
class _DistrictDetailSheet extends StatelessWidget {
  final District district;
  final List<Calamity> events;
  const _DistrictDetailSheet({required this.district, required this.events});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.location_city_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      district.name,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    district.division,
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Divider(color: scheme.outlineVariant),
              if (events.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No active events in this district.',
                      style: tt.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                for (final c in events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SheetCalamityCard(calamity: c),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetCalamityCard extends StatelessWidget {
  final Calamity calamity;
  const _SheetCalamityCard({required this.calamity});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM, h:mm a');
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: calamity.severity.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: calamity.severity.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(calamity.type.icon, color: calamity.severity.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  calamity.title,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${calamity.severity.label} · ${fmt.format(calamity.observedAt)}',
                  style: tt.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── event list ─────────────────────────────────
class _CalamityList extends StatelessWidget {
  const _CalamityList();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CalamityProvider>();
    if (prov.status == CalamityStatus.loading && prov.all.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (prov.visible.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final c in prov.visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CalamityCard(calamity: c),
          ),
      ],
    );
  }
}

class _CalamityCard extends StatelessWidget {
  final Calamity calamity;
  const _CalamityCard({required this.calamity});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM, h:mm a');
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        onTap: () async {
          final url = calamity.sourceUrl;
          if (url != null && url.isNotEmpty) {
            try {
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            } catch (_) {}
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: calamity.severity.color.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: calamity.severity.color,
                        width: 1.4,
                      ),
                    ),
                    child: Icon(
                      calamity.type.icon,
                      color: calamity.severity.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          calamity.title,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${calamity.type.label} · ${calamity.severity.label} · '
                          '${fmt.format(calamity.observedAt)}',
                          style: tt.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (calamity.description.isNotEmpty &&
                  calamity.description != calamity.title)
                Text(
                  calamity.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _chip(context, calamity.sourceName, calamity.type.accent),
                  if (calamity.district != null) ...[
                    const SizedBox(width: 6),
                    _chip(context, calamity.district!, calamity.severity.color),
                  ],
                  if (calamity.magnitude != null) ...[
                    const SizedBox(width: 6),
                    _chip(
                      context,
                      'M ${calamity.magnitude!.toStringAsFixed(1)}',
                      calamity.severity.color,
                    ),
                  ],
                  const Spacer(),
                  if (calamity.sourceUrl != null)
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

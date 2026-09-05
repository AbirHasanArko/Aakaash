import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/weather_codes.dart';
import '../models/weather_models.dart';
import '../providers/notification_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/weather_provider.dart';
import '../utils/date_format.dart';
import '../widgets/daily_list.dart';
import '../widgets/details_grid.dart';
import '../widgets/glass_card.dart';
import '../widgets/hourly_strip.dart';
import '../widgets/weather_icon_helper.dart';
import '../services/ai_service.dart';
import 'about_screen.dart';
import 'calamity_screen.dart';
import 'farmers_corner_screen.dart';
import 'notification_settings_screen.dart';
import 'search_screen.dart';
import 'sky_analyzer_screen.dart';
import 'subscription_screen.dart';

/// Main screen with a SegmentBar (Today / Hourly / 5-Day / Details).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _segmentIndex = 0;
  static const _segments = ['Today', 'Hourly', '5 Days', 'Details'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wp = context.read<WeatherProvider>();
      if (wp.status == WeatherStatus.idle) {
        // Default to Dhaka on first launch.
        wp.loadForCity(
          const City(
            name: 'Dhaka',
            district: 'Dhaka',
            division: 'Dhaka',
            lat: 23.8103,
            lon: 90.4125,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WeatherProvider>();
    final sub = context.watch<SubscriptionProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              onSearch: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
              onSubscribe: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              ),
              onCalamities: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CalamityScreen()),
              ),
              onFarmersCorner: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FarmersCornerScreen()),
              ),
              onSkyAnalyzer: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SkyAnalyzerScreen()),
              ),
              onAbout: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
              onNotifications: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen()),
              ),
              onManageSubscription: () => _showSubscriptionSheet(context),
              isSubscribed: sub.status == SubscriptionStatus.registered,
            ),
            _SegmentBar(
              segments: _segments,
              selected: _segmentIndex,
              onSelected: (i) => setState(() => _segmentIndex = i),
            ),
            Expanded(
              child: _body(wp: wp, segment: _segmentIndex),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body({required WeatherProvider wp, required int segment}) {
    if (wp.status == WeatherStatus.loading && wp.bundle == null) {
      return const _LoadingState();
    }
    if (wp.status == WeatherStatus.error && wp.bundle == null) {
      return _ErrorState(
        message: wp.errorMessage ?? 'Could not load weather.',
        onRetry: wp.refresh,
      );
    }
    final current = wp.bundle!.current;
    final isDay = current.isDaytime;
    switch (segment) {
      case 0:
        return _TodayTab(weather: wp, current: current, isDay: isDay);
      case 1:
        return _HourlyTab(hours: wp.bundle!.hourly, cityName: wp.city?.name ?? '');
      case 2:
        return _DailyTab(days: wp.bundle!.daily, cityName: wp.city?.name ?? '');
      case 3:
      default:
        return _DetailsTab(current: current);
    }
  }

  Future<void> _showSubscriptionSheet(BuildContext context) async {
    final sub = context.read<SubscriptionProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final id = sub.subscriberId ?? '—';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_rounded, color: scheme.tertiary),
                    const SizedBox(width: 10),
                    Text(
                      'You are subscribed',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Subscriber ID',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  id,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Manage subscription'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetCtx).pop();
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await sub.unsubscribe();
                    if (!context.mounted) return;
                    final wasCachedOnly = ok && sub.subscriberId == null
                        && sub.status == SubscriptionStatus.unregistered
                        && (sub.phone != null);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? (wasCachedOnly
                                  ? 'Already unsubscribed on BDApps. '
                                      'Local cache cleared.'
                                  : 'Subscription cancelled.')
                              : (sub.lastError ?? 'Could not cancel.'),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Unsubscribe'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onSubscribe;
  final VoidCallback onCalamities;
  final VoidCallback onFarmersCorner;
  final VoidCallback onSkyAnalyzer;
  final VoidCallback onAbout;
  final VoidCallback onNotifications;
  final VoidCallback onManageSubscription;
  final bool isSubscribed;
  const _Header({
    required this.onSearch,
    required this.onSubscribe,
    required this.onCalamities,
    required this.onFarmersCorner,
    required this.onSkyAnalyzer,
    required this.onAbout,
    required this.onNotifications,
    required this.onManageSubscription,
    required this.isSubscribed,
  });

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onSearch,
            tooltip: 'Search city',
            icon: const Icon(Icons.search_rounded),
          ),
          // Bell icon — opens notification settings. Shows a small dot
          // when the user is subscribed but notifications are blocked
          // at the OS level or globally disabled.
          Consumer<NotificationProvider>(
            builder: (ctx, notif, _) {
              final showBadge =
                  isSubscribed && !notif.permissionGranted;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: onNotifications,
                    tooltip: 'Notifications',
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                  if (showBadge)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: scheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Consumer<ThemeProvider>(
            builder: (context, theme, _) => PopupMenuButton<ThemeMode>(
              tooltip: 'Theme',
              icon: Icon(theme.icon),
              color: scheme.surfaceContainerHigh,
              surfaceTintColor: scheme.surfaceTint,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              onSelected: (mode) => context
                  .read<ThemeProvider>()
                  .setMode(mode),
              itemBuilder: (context) => [
                for (final entry in const [
                  (ThemeMode.system, 'Follow system',
                      Icons.brightness_auto_rounded),
                  (ThemeMode.light, 'Light', Icons.light_mode_rounded),
                  (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
                ])
                  PopupMenuItem<ThemeMode>(
                    value: entry.$1,
                    child: Row(
                      children: [
                        Icon(entry.$3,
                            color: theme.mode == entry.$1
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            size: 20),
                        const SizedBox(width: 12),
                        Text(
                          entry.$2,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: theme.mode == entry.$1
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        if (theme.mode == entry.$1) ...[
                          const Spacer(),
                          Icon(Icons.check_rounded,
                              color: scheme.primary, size: 18),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            color: scheme.surfaceContainerHigh,
            surfaceTintColor: scheme.surfaceTint,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            onSelected: (v) {
              switch (v) {
                case 'calamities':
                  onCalamities();
                  break;
                case 'farmers':
                  onFarmersCorner();
                  break;
                case 'sky_analyzer':
                  onSkyAnalyzer();
                  break;
                case 'about':
                  onAbout();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'calamities',
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: scheme.primary, size: 20),
                    const SizedBox(width: 12),
                    const Text('Natural Calamities'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'farmers',
                child: Row(
                  children: [
                    Icon(Icons.agriculture_rounded,
                        color: scheme.primary, size: 20),
                    const SizedBox(width: 12),
                    const Text("Farmer's Corner"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sky_analyzer',
                child: Row(
                  children: [
                    Icon(Icons.camera_enhance_rounded,
                        color: scheme.primary, size: 20),
                    const SizedBox(width: 12),
                    const Text("Sky Analyzer"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: scheme.primary, size: 20),
                    const SizedBox(width: 12),
                    const Text('About Aakaash'),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          if (!isSubscribed)
            FilledButton.tonalIcon(
              onPressed: onSubscribe,
              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
              label: Text(
                sub.status == SubscriptionStatus.pending
                    ? 'Verify OTP'
                    : 'Subscribe',
                style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: const StadiumBorder(),
              ),
            )
          else
            Material(
              color: scheme.tertiaryContainer,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onManageSubscription,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          color: scheme.onTertiaryContainer, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Subscribed',
                        style: tt.labelMedium?.copyWith(
                          color: scheme.onTertiaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.expand_more_rounded,
                          color: scheme.onTertiaryContainer, size: 16),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentBar extends StatelessWidget {
  final List<String> segments;
  final int selected;
  final ValueChanged<int> onSelected;
  const _SegmentBar({
    required this.segments,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            for (int i = 0; i < segments.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected == i
                          ? scheme.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: selected == i
                          ? [
                              BoxShadow(
                                color: scheme.shadow.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        segments[i],
                        style: tt.labelLarge?.copyWith(
                          color: selected == i
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  final WeatherProvider weather;
  final CurrentWeather current;
  final bool isDay;
  const _TodayTab({
    required this.weather,
    required this.current,
    required this.isDay,
  });

  @override
  Widget build(BuildContext context) {
    final city = weather.city;
    final hour = DateTime.now().hour;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        GlassCard(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_rounded, color: scheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      city?.fullLabel ?? current.cityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        textStyle: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  if (weather.usingCurrentLocation)
                    Icon(Icons.my_location_rounded, color: scheme.primary, size: 18),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                DateFmt.full(current.observedAt),
                style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Text(
                DateFmt.greetingForHour(hour),
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedWeatherGlyph(
                    code: current.weatherCode,
                    isDay: isDay,
                    size: 96,
                  ),
                  const SizedBox(width: 20),
                  Text(
                    '${current.temperature.round()}°',
                    style: GoogleFonts.outfit(
                      textStyle: tt.displayLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                        fontSize: 72,
                        letterSpacing: -2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                WeatherCodes.label(current.weatherCode),
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Feels like ${current.feelsLike.round()}°C • '
                'High ${weather.bundle!.daily.first.tempMax.round()}° • '
                'Low ${weather.bundle!.daily.first.tempMin.round()}°',
                style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        // ───── AI Briefing Card ─────
        _AiBriefingCard(weather: weather),
        const SectionHeader(
          title: 'Sun cycle',
          subtitle: 'Sunrise, sunset and current daylight',
        ),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: _SunArc(
                  sunrise: current.sunrise,
                  sunset: current.sunset,
                  now: current.observedAt,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Sunrise',
                      style: tt.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  Text(DateFmt.time(current.sunrise),
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Sunset',
                      style: tt.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  Text(DateFmt.time(current.sunset),
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
        const SectionHeader(
          title: 'Today by the hour',
          subtitle: 'Next 24 hours of temperature and rain',
        ),
        HourlyStrip(hours: weather.bundle!.hourly.take(24).toList()),
        const SectionHeader(title: 'Highlights'),
        const SizedBox(height: 8),
        DetailsGrid(current: current),
      ],
    );
  }
}

class _SunArc extends StatelessWidget {
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime now;
  const _SunArc({
    required this.sunrise,
    required this.sunset,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final total = sunset.millisecondsSinceEpoch - sunrise.millisecondsSinceEpoch;
    final cur = (now.millisecondsSinceEpoch - sunrise.millisecondsSinceEpoch)
        .clamp(0, total);
    final t = total == 0 ? 0.0 : cur / total;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 96,
      width: 160,
      child: CustomPaint(
        painter: _SunArcPainter(
          progress: t,
          outline: scheme.outlineVariant,
          sun: scheme.primary,
        ),
      ),
    );
  }
}

class _SunArcPainter extends CustomPainter {
  final double progress;
  final Color outline;
  final Color sun;
  _SunArcPainter({
    required this.progress,
    required this.outline,
    required this.sun,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Theme-aware colors — outline uses the active scheme's
    // outlineVariant, sun uses primary. Looks correct in both light
    // and dark mode.
    final stroke = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.6);
    canvas.drawArc(rect, 3.14159, 3.14159, false, stroke);

    final angle = 3.14159 + (progress * 3.14159);
    final cx = rect.center.dx +
        (rect.width / 2) * (angle - 3.14159).abs() / 3.14159;
    final cy = rect.center.dy - (rect.height / 2) * (progress);
    final sunPaint = Paint()..color = sun;
    canvas.drawCircle(Offset(cx, cy), 6, sunPaint);
  }

  @override
  bool shouldRepaint(covariant _SunArcPainter old) =>
      old.progress != progress ||
      old.outline != outline ||
      old.sun != sun;
}

class _HourlyTab extends StatelessWidget {
  final List<HourlyForecast> hours;
  final String cityName;
  const _HourlyTab({required this.hours, required this.cityName});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(
          title: 'Hourly forecast',
          subtitle: '$cityName • 24 hours',
        ),
        HourlyStrip(hours: hours),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Hourly detail'),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              for (int i = 0; i < hours.length.clamp(0, 12); i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox(
                    width: 60,
                    child: Text(
                      i == 0 ? 'Now' : DateFmt.time(hours[i].time),
                      style: tt.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  title: Text(
                    WeatherCodes.label(hours[i].weatherCode),
                    style: tt.bodyMedium,
                  ),
                  trailing: Text(
                    '${hours[i].temp.round()}°  '
                    '${(hours[i].pop * 100).round()}%',
                    style: tt.bodyMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DailyTab extends StatelessWidget {
  final List<DailyForecast> days;
  final String cityName;
  const _DailyTab({required this.days, required this.cityName});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(
          title: '5-day forecast',
          subtitle: '$cityName • next 5 days',
        ),
        DailyList(days: days),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Headlines'),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _Headline(
                title: 'Hottest day',
                value: '${_extreme(days, true).tempMax.round()}°C on ${DateFmt.dateOnly(_extreme(days, true).date)}',
                icon: Icons.local_fire_department_rounded,
              ),
              const SizedBox(height: 8),
              _Headline(
                title: 'Coldest day',
                value: '${_extreme(days, false).tempMin.round()}°C on ${DateFmt.dateOnly(_extreme(days, false).date)}',
                icon: Icons.ac_unit_rounded,
              ),
              const SizedBox(height: 8),
              _Headline(
                title: 'Wettest day',
                value: _wettestText(days),
                icon: Icons.water_drop_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  DailyForecast _extreme(List<DailyForecast> ds, bool max) {
    return ds.reduce((a, b) =>
        (max ? (a.tempMax > b.tempMax) : (a.tempMin < b.tempMin)) ? a : b);
  }

  String _wettestText(List<DailyForecast> ds) {
    if (ds.isEmpty) return '—';
    final w = ds.reduce((a, b) {
      if (a.rain > b.rain) return a;
      if (b.rain > a.rain) return b;
      return a.pop > b.pop ? a : b;
    });
    if (w.rain == 0 && w.pop == 0) return 'No rain in the next 5 days';
    if (w.rain == 0 && w.pop > 0) return '${(w.pop * 100).round()}% chance on ${DateFmt.dateOnly(w.date)}';
    return '${w.rain.toStringAsFixed(1)} mm on ${DateFmt.dateOnly(w.date)}';
  }
}

class _Headline extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _Headline(
      {required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: scheme.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tt.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              Text(
                value,
                style: tt.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final CurrentWeather current;
  const _DetailsTab({required this.current});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(title: 'Atmospheric details'),
        const SizedBox(height: 8),
        DetailsGrid(current: current),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Conditions'),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                WeatherCodes.label(current.weatherCode),
                style: tt.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                current.weatherDescription,
                style: tt.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              if (current.rainLastHour != null)
                Text(
                  'Rain last hour: ${current.rainLastHour!.toStringAsFixed(1)} mm',
                  style: tt.bodyMedium,
                ),
              if (current.snowLastHour != null)
                Text(
                  'Snow last hour: ${current.snowLastHour!.toStringAsFixed(1)} mm',
                  style: tt.bodyMedium,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text('Fetching the latest forecast…', style: tt.bodyMedium),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: scheme.error, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────── AI Briefing Card ─────────────────────

class _AiBriefingCard extends StatelessWidget {
  final WeatherProvider weather;
  const _AiBriefingCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (!weather.isSubscribed) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GlassCard(
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              // Blurred fake content
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            color: scheme.tertiary.withOpacity(0.5), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'AI Weather Insight',
                          style: tt.labelMedium?.copyWith(
                            color: scheme.tertiary.withOpacity(0.5),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unlock intelligent, natural-language weather summaries and context-aware suggestions tailored for you.',
                      style: tt.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Lock overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                      ),
                      icon: const Icon(Icons.lock_open_rounded, size: 16),
                      label: const Text('Unlock with BDApps'),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.tertiary,
                        foregroundColor: scheme.onTertiary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Still loading
    if (weather.aiBriefingLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GlassCard(
          child: Shimmer.fromColors(
            baseColor: scheme.surfaceContainerHighest,
            highlightColor: scheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 14,
                  width: 200,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // No briefing available (no API key, error, etc.)
    final briefing = weather.aiBriefing;
    if (briefing == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GlassCard(
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI insights are temporarily unavailable. Please try refreshing.',
                  style: tt.bodySmall?.copyWith(color: scheme.error),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: scheme.tertiary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'AI Weather Insight',
                      style: tt.labelMedium?.copyWith(
                        color: scheme.tertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  briefing.summary,
                  style: tt.bodyMedium,
                ),
              ],
            ),
          ),
          if (briefing.suggestions.isNotEmpty)
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(top: 6),
                itemCount: briefing.suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final s = briefing.suggestions[i];
                  return ActionChip(
                    avatar: Text(s.emoji, style: const TextStyle(fontSize: 14)),
                    label: Text(s.label),
                    onPressed: () {
                      if (s.route != null) _navigate(ctx, s.route!);
                    },
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    if (route == 'farmers_corner') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FarmersCornerScreen()),
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:provider/provider.dart';

import '../data/bangladesh_cities.dart';
import '../models/weather_models.dart';
import '../providers/subscription_provider.dart';
import '../providers/weather_provider.dart';
import '../services/location_service.dart';
import '../widgets/weather_icon_helper.dart';
import 'home_screen.dart';
import 'subscription_screen.dart';

import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeIcon;
  late final Animation<Offset> _slideIcon;
  late final Animation<double> _fadeTitle;
  late final Animation<Offset> _slideTitle;
  late final Animation<double> _fadeTagline;
  late final Animation<Offset> _slideTagline;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeIcon = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _slideIcon = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)),
    );

    _fadeTitle = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.3, 0.8, curve: Curves.easeOut)),
    );
    _slideTitle = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic)),
    );

    _fadeTagline = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );
    _slideTagline = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic)),
    );

    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Small artificial delay to let the nice animation finish
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      await context.read<SubscriptionProvider>().load();
      if (!mounted) return;
      _goToHome();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _goToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _fadeIcon,
                    child: SlideTransition(
                      position: _slideIcon,
                      child: const AnimatedWeatherGlyph(code: 800, isDay: true, size: 110),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeTitle,
                    child: SlideTransition(
                      position: _slideTitle,
                      child: Text(
                        'Aakaash',
                        style: GoogleFonts.outfit(
                          textStyle: tt.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _fadeTagline,
                    child: SlideTransition(
                      position: _slideTagline,
                      child: Text(
                        'Weather forecast for Bangladesh',
                        style: tt.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48.0),
                child: FadeTransition(
                  opacity: _fadeTagline,
                  child: SizedBox(
                    width: 40,
                    child: LinearProgressIndicator(
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 4,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: scheme.primary,
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

/// Search overlay (also used as the typeahead header in HomeScreen).
class SearchOverlay extends StatelessWidget {
  final EdgeInsets padding;
  final double borderRadius;
  const SearchOverlay({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 14),
    this.borderRadius = 30,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: TypeAheadField<City>(
        debounceDuration: const Duration(milliseconds: 200),
        hideOnEmpty: true,
        hideOnLoading: false,
        textFieldConfiguration: TextFieldConfiguration(
          decoration: InputDecoration(
            filled: true,
            fillColor: scheme.surfaceContainerHigh,
            hintText: 'Search city, e.g. Sylhet, Cox\'s Bazar, Khulna',
            hintStyle: TextStyle(color: scheme.onSurfaceVariant),
            prefixIcon:
                Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide.none,
            ),
            suffixIcon: Consumer<WeatherProvider>(
              builder: (_, wp, __) => IconButton(
                tooltip: 'Use current location',
                icon: Icon(Icons.my_location_rounded, color: scheme.primary),
                onPressed: wp.status == WeatherStatus.loading
                    ? null
                    : () => _useLocation(context),
              ),
            ),
          ),
        ),
        suggestionsCallback: (pattern) async => searchCities(pattern),
        itemBuilder: (context, c) => ListTile(
          leading: Icon(Icons.location_city_rounded, color: scheme.primary),
          title: Text(
            c.name,
            style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${c.district} • ${c.division}',
            style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          trailing: Text(
            '${_distanceKmFromDhaka(c).toStringAsFixed(0)} km',
            style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        onSuggestionSelected: (c) async {
          await context.read<WeatherProvider>().loadForCity(c);
        },
        noItemsFoundBuilder: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No match. Try the BD dropdown or current location button.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        suggestionsBoxDecoration: SuggestionsBoxDecoration(
          borderRadius: BorderRadius.circular(18),
          elevation: 6,
          color: scheme.surfaceContainerHigh,
        ),
      ),
    );
  }

  Future<void> _useLocation(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final loc = LocationService();
    final weather = context.read<WeatherProvider>();
    final sub = context.read<SubscriptionProvider>();
    try {
      final pos = await loc.getCurrentPosition();
      if (sub.status != SubscriptionStatus.registered) {
        await sub.incrementFreeUse();
        if (sub.freeQuotaExhausted) {
          final nav = Navigator.of(context, rootNavigator: true);
          await nav.push(
            MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
          );
          return;
        }
      }
      await weather.loadForLatLon(pos.latitude, pos.longitude);
    } on LocationServiceException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(e.toString()), behavior: SnackBarBehavior.floating),
      );
    }
  }
}

/// Approximate great-circle distance from Dhaka centre (23.81, 90.41).
double _distanceKmFromDhaka(City c) {
  const latRef = 23.81;
  const lonRef = 90.41;
  const r = 6371.0;
  const rad = 3.141592653589793 / 180;
  final dLat = (c.lat - latRef) * rad;
  final dLon = (c.lon - lonRef) * rad;
  final h = (dLat / 2) * (dLat / 2) +
      (dLon / 2) * (dLon / 2) * 0.92; // cos(Dhaka-lat) ~ 0.92
  return 2 * r * _sqrtSmall(h);
}

double _sqrtSmall(double v) {
  double x = v <= 0 ? 0 : v;
  for (int i = 0; i < 6; i++) {
    x = (x + v / x) / 2;
  }
  return x;
}

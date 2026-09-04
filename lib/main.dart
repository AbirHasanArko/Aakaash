import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'providers/calamity_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/farming_provider.dart';
import 'providers/weather_provider.dart';
import 'screens/calamity_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/bdapps_service.dart';
import 'services/calamity_service.dart';
import 'services/notification_service.dart';
import 'services/openweather_service.dart';

/// Global navigator key — lets the background notification tap-handler
/// route to the right screen even when the app was cold-launched from
/// a notification.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'aakaash.root');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait — better for the segmented layout.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Restore the user's theme preference before the first frame so the
  // app never flashes the wrong brightness on launch.
  final themeProvider = ThemeProvider();
  await themeProvider.load();
  // Initialize the notification subsystem (timezone DB + plugin +
  // channels) BEFORE runApp so the first frame can already query
  // notification state.
  await NotificationService.instance.initialize();
  // Status bar styling driven by the active theme via AnnotatedRegion inside
  // each scaffold, so no global overlay is required.
  runApp(AakaashApp(themeProvider: themeProvider));
}

class AakaashApp extends StatefulWidget {
  final ThemeProvider themeProvider;
  const AakaashApp({super.key, required this.themeProvider});

  @override
  State<AakaashApp> createState() => _AakaashAppState();
}

class _AakaashAppState extends State<AakaashApp> {
  @override
  void initState() {
    super.initState();
    // Tap-router: route notification taps via the global navigator key.
    // Scheduled here (not in main()) because rootNavigatorKey must
    // already be mounted by the time a tap arrives.
    NotificationService.instance.setTapHandler(_routeFromNotification);
  }

  /// Push the right screen when a notification is tapped.
  ///
  /// For "home" we simply pop back to the root (Home is the start
  /// screen after splash). For "calamity:<id>" we push the Calamity
  /// screen which already lists events; in a later iteration we could
  /// scroll-to / highlight the matching id.
  void _routeFromNotification(NotificationRoutePayload payload) {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    switch (payload.route) {
      case NotificationRoute.home:
        navigator.popUntil((r) => r.isFirst);
        break;
      case NotificationRoute.calamity:
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => const CalamityScreen(),
        ));
        break;
      case NotificationRoute.earthquake:
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => const CalamityScreen(),
        ));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: widget.themeProvider),
        Provider<OpenWeatherService>(
          create: (_) => OpenWeatherService(),
          dispose: (_, s) {},
        ),
        Provider<BdappsService>(
          create: (_) => buildDefaultBdappsService(),
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider()..load(),
        ),
        ChangeNotifierProxyProvider<NotificationProvider,
            SubscriptionProvider>(
          create: (ctx) => SubscriptionProvider(
            ctx.read<BdappsService>(),
            notif: ctx.read<NotificationProvider>(),
          ),
          update: (_, notif, prev) =>
              prev ?? SubscriptionProvider(
                _.read<BdappsService>(),
                notif: notif,
              ),
        ),
        ChangeNotifierProxyProvider<SubscriptionProvider, WeatherProvider>(
          create: (ctx) =>
              WeatherProvider(ctx.read<OpenWeatherService>()),
          update: (_, sub, prev) =>
              (prev ?? WeatherProvider(_.read<OpenWeatherService>()))
                ..updateSubscription(
                    sub.status == SubscriptionStatus.registered),
        ),
        ChangeNotifierProxyProvider<WeatherProvider, FarmingProvider>(
          create: (_) => FarmingProvider(),
          update: (_, wp, prev) => (prev ?? FarmingProvider())..updateFromWeather(wp),
        ),
        ChangeNotifierProvider<CalamityProvider>(
          create: (_) => CalamityProvider(service: CalamityService()),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Aakaash',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(brightness: Brightness.light),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          themeMode: theme.mode,
          navigatorKey: rootNavigatorKey,
          home: const SplashScreen(),
          // Named routes used by the notification tap handler above.
          routes: {
            '/home': (_) => const HomeScreen(),
          },
        ),
      ),
    );
  }
}

/// App-wide constants — endpoints, keys, defaults.
class AppConstants {
  AppConstants._();

  // OpenWeather — own key (Abir Hasan Arko). Read from
  // `--dart-define=OWM_API_KEY=...` at build time; falls back to the
  // baked-in personal key for `flutter run` without a define.
  static String get owmApiKey {
    const fromEnv = String.fromEnvironment('OWM_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    return '03984c4bec5812073eb738362973a73e';
  }
  static const String owmBase = 'https://api.openweathermap.org/data/2.5';
  static const String owmGeoBase = 'https://api.openweathermap.org/geo/1.0';

  // AppsPro proxy URLs — these are required for the BDApps portal
  // configuration (the operator pastes them into developer.bdapps.com
  // for the Aakaash app). AppsPro sits in front of BDApps and adds a
  // hosted checkout, subscription widget, and analytics on top of the
  // direct API. See https://api.appspro.dev
  static const String appsproSmsUrl = 'https://api.appspro.dev/bdapps/sms';
  static const String appsproUssdUrl = 'https://api.appspro.dev/bdapps/ussd';
  static const String appsproNotifyUrl = 'https://api.appspro.dev/bdapps/notify';

  // AppsPro outbound IP — whitelist this on developer.bdapps.com so the
  // AppsPro proxy is allowed to call your backend.
  static const String appsproOutboundIp = '217.15.160.79';

  // AppsPro App ID (UUID). This is the integrator's app identifier —
  // paste it into any external admin tool that has an "AppsPro App ID"
  // field (e.g. tex-auth's AppsPro tab).
  static const String appsproAppId = '6622177a-eafa-4689-a66a-f4f852374989';

  // AppsPro SDK base URL (for WebSDK init and server-to-server calls).
  static const String appsproApiBase = 'https://api.appspro.dev/api/v1';

  // AppsPro publishable key. Safe to embed in client code / WebSDK.
  static const String appsproPublishableKey =
      'pk_6a2e6e4159436d82e513419a';

  // AppsPro hosted checkout URL — redirect users here to subscribe.
  // Append "?callback=..." to deep-link back into the app after success.
  static const String appsproCheckoutUrl =
      'https://appspro.dev/s/f6N5yeCno1';

  // AppsPro webhook URL — AppsPro will POST subscriber / SMS / USSD
  // events here. We receive them in `subscription_listener.php`.
  // NOTE: replace `your-domain.com` with your real backend host before
  // going to production; otherwise leave the placeholder.
  static const String appsproWebhookUrl =
      'https://your-domain.com/webhooks/appspro';

  // AppsPro SECRET key — server-side only. Read from
  // `--dart-define=APPSPRO_SECRET_KEY=...` at build time, never commit it.
  // Authorization header: `Bearer <secret_key>`.
  static String? get appsproSecretKey {
    const v = String.fromEnvironment('APPSPRO_SECRET_KEY');
    return v.isEmpty ? null : v;
  }

  // App config
  static const String appName = 'Aakaash';
  static const String appVersion = '1.0.0';
  static const String developerName = 'Abir Hasan Arko';
  static const String developerGithub = 'https://github.com/AbirHasanArko';
  static const String developerLinkedin = 'https://www.linkedin.com/in/abirhasanarko/';
  static const String developerEmail = 'abirhasanarko2004@gmail.com';
  static const String appTagline =
      'Weather forecast and intelligent natural calamity radar '
      'designed for the people of Bangladesh';
  static const int freeDailyLimit = 3; // free searches per day before subscription gate

  // Gemini AI — read from `--dart-define=GEMINI_API_KEY=...`.
  static String? get geminiApiKey {
    const v = String.fromEnvironment('GEMINI_API_KEY');
    if (v.isNotEmpty) return v;
    // Fallback so it works in debug/IDE without explicit --dart-define
    return 'DUMMY_GEMINI_API_KEY_1234567890';
  }
  static const String geminiModel = 'gemini-3.5-flash-lite';
}

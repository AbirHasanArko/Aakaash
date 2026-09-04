import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Result of a BDApps status check.
class BdappsStatus {
  final bool isSubscribed;
  final String subscriptionStatus;
  final String statusCode;
  final String statusDetail;
  final String subscriberId;

  const BdappsStatus({
    required this.isSubscribed,
    required this.subscriptionStatus,
    required this.statusCode,
    required this.statusDetail,
    required this.subscriberId,
  });
}

/// Result of an OTP request.
class OtpRequestResult {
  final bool success;
  final String? referenceNo;
  final String statusCode;
  final String statusDetail;

  const OtpRequestResult({
    required this.success,
    this.referenceNo,
    required this.statusCode,
    required this.statusDetail,
  });
}

/// Result of an OTP verify.
class OtpVerifyResult {
  final bool success;
  final bool isSubscribed;
  final String subscriberId;
  final String statusCode;
  final String statusDetail;
  final String subscriptionStatus;

  const OtpVerifyResult({
    required this.success,
    required this.isSubscribed,
    required this.subscriberId,
    required this.statusCode,
    required this.statusDetail,
    required this.subscriptionStatus,
  });
}

/// Wraps the public BDApps REST endpoints that the mobile app can call
/// (and the backend helpers in `All Backend code/`).
///
/// If you instead want to use AppsPro (https://api.appspro.dev), set
/// [backend] = "appspro" and provide [secretKey]. The endpoints stay
/// the same shape; only the auth and base URL change.
class BdappsService {
  /// `bdapps` uses direct BDApps endpoints; `appspro` uses the AppsPro
  /// subscription-management API.
  final String backend;
  final String? secretKey;
  final http.Client _client;

  /// BDApps credentials (only used when [backend] == 'bdapps'). The mobile
  /// app SHOULD NOT embed these — keep them in the backend. The defaults
  /// point to your own helper endpoints in `All Backend code/`.
  final String? baseUrl;
  final String? sendOtpPath;
  final String? verifyOtpPath;
  final String? checkStatusPath;
  final String? unsubscribePath;

  BdappsService({
    this.backend = 'bdapps',
    this.secretKey,
    http.Client? client,
    this.baseUrl,
    this.sendOtpPath,
    this.verifyOtpPath,
    this.checkStatusPath,
    this.unsubscribePath,
  }) : _client = client ?? http.Client();

  /// Status check: REGISTERED / UNREGISTERED.
  Future<BdappsStatus> checkStatus(String phoneE164OrLocal) async {
    final digits = _normalize(phoneE164OrLocal);

    if (backend == 'appspro') {
      _requireSecretKey();
      final r = await _post(
        'https://api.appspro.dev/api/v1/sdk/status',
        headers: _bearerHeaders(),
        body: {'phone': _toLocalFormat(digits)},
      );
      return BdappsStatus(
        isSubscribed:
            (r['subscription_status']?.toString().toUpperCase() ?? '') ==
                'REGISTERED',
        subscriptionStatus: r['subscription_status']?.toString() ?? '',
        statusCode: r['status_code']?.toString() ?? '',
        statusDetail: r['status_detail']?.toString() ?? '',
        subscriberId: 'tel:88$digits',
      );
    }

    final r = await _post(
      '${baseUrl ?? ''}${checkStatusPath ?? '/check_subscription.php'}',
      body: {'user_mobile': '0$digits'},
    );
    return BdappsStatus(
      isSubscribed: r['isSubscribed'] == true,
      subscriptionStatus: r['subscriptionStatus']?.toString() ?? '',
      statusCode: r['statusCode']?.toString() ?? '',
      statusDetail: r['statusDetail']?.toString() ?? '',
      subscriberId: r['subscriberId']?.toString() ?? 'tel:88$digits',
    );
  }

  /// Step 1 of subscription: ask BDApps to SMS the user an OTP.
  ///
  /// AppsPro accepts any of: `01XXXXXXXXX`, `8801XXXXXXXXX`,
  /// `+8801XXXXXXXXX`. We send the local form `01XXXXXXXXX`.
  Future<OtpRequestResult> requestOtp(String phoneE164OrLocal) async {
    final digits = _normalize(phoneE164OrLocal);

    if (backend == 'appspro') {
      _requireSecretKey();
      final r = await _post(
        'https://api.appspro.dev/api/v1/sdk/otp/request',
        headers: _bearerHeaders(),
        body: {'phone': _toLocalFormat(digits)},
      );
      final hasRef = r['reference_no'] != null &&
          r['reference_no'].toString().isNotEmpty;
      return OtpRequestResult(
        success: hasRef,
        referenceNo: r['reference_no']?.toString(),
        statusCode: r['status_code']?.toString() ?? '',
        statusDetail: r['status_detail']?.toString() ?? '',
      );
    }

    final r = await _post(
      '${baseUrl ?? ''}${sendOtpPath ?? '/send_otp.php'}',
      body: {'user_mobile': '0$digits'},
    );
    return OtpRequestResult(
      success: r['success'] == true && r['referenceNo'] != null,
      referenceNo: r['referenceNo']?.toString(),
      statusCode: r['statusCode']?.toString() ?? '',
      statusDetail: r['statusDetail']?.toString() ??
          r['message']?.toString() ??
          '',
    );
  }

  /// Step 2: confirm the OTP code. On success the user is REGISTERED.
  Future<OtpVerifyResult> verifyOtp({
    required String phoneE164OrLocal,
    required String referenceNo,
    required String otp,
  }) async {
    final digits = _normalize(phoneE164OrLocal);

    if (backend == 'appspro') {
      _requireSecretKey();
      final r = await _post(
        'https://api.appspro.dev/api/v1/sdk/otp/verify',
        headers: _bearerHeaders(),
        body: {
          'reference_no': referenceNo,
          'otp': otp,
        },
      );
      final code = r['status_code']?.toString() ?? '';
      final status = r['subscription_status']?.toString().toUpperCase() ?? '';
      // AppsPro can report success either as `subscription_status:
      // REGISTERED` or just `status_code: S1000` (e.g. when the user
      // was already registered and we just refreshed their session).
      // If the verify call returned S1000 AND handed back a subscriber
      // id, treat that as a confirmed registration — the parser
      // otherwise falls into the "Invalid OTP" error branch and the
      // app stays locked out even though BDApps already registered
      // the user.
      final subscriberId =
          r['subscriber_id']?.toString().trim().isNotEmpty == true
              ? r['subscriber_id'].toString()
              : 'tel:88$digits';
      final registered = status == 'REGISTERED' ||
          code == 'S1000' ||
          code == '0000';
      return OtpVerifyResult(
        success: registered || code == 'S1000' || code == '0000',
        isSubscribed: registered,
        subscriberId: subscriberId,
        statusCode: code,
        statusDetail: r['status_detail']?.toString() ?? '',
        subscriptionStatus: r['subscription_status']?.toString() ?? '',
      );
    }

    final r = await _post(
      '${baseUrl ?? ''}${verifyOtpPath ?? '/verify_otp.php'}',
      body: {
        'Otp': otp,
        'referenceNo': referenceNo,
        'user_mobile': '0$digits',
      },
    );
    final status = r['subscriptionStatus']?.toString().toUpperCase() ?? '';
    return OtpVerifyResult(
      success: r['statusCode'] == 'S1000' || status == 'REGISTERED',
      isSubscribed: status == 'REGISTERED',
      subscriberId: r['subscriberId']?.toString() ?? 'tel:88$digits',
      statusCode: r['statusCode']?.toString() ?? '',
      statusDetail: r['statusDetail']?.toString() ?? '',
      subscriptionStatus: status,
    );
  }

  /// Cancel the user's subscription.
  ///
  /// AppsPro requires both `phone` (international form, no leading `+`,
  /// i.e. `8801XXXXXXXXX`) AND `subscriber_id` (e.g. `tel:8801XXXXXXXXX`).
  /// Sending only the phone, or the wrong shape, returns `E1951`
  /// ("Format of the address is invalid Or User Already UnRegistered").
  Future<BdappsStatus> unsubscribe(
    String phoneE164OrLocal, {
    String? subscriberId,
  }) async {
    final digits = _normalize(phoneE164OrLocal);
    // AppsPro expects the international form WITHOUT the leading '+':
    // `8801XXXXXXXXX` (13 digits). Building `tel:8801XXXXXXXXX` for the
    // subscriber id requires the same full prefix.
    final intlNoPlus = '880$digits';
    final sid = subscriberId ?? 'tel:$intlNoPlus';

    if (backend == 'appspro') {
      _requireSecretKey();
      final r = await _post(
        'https://api.appspro.dev/api/v1/sdk/unsubscribe',
        headers: _bearerHeaders(),
        body: {
          'phone': intlNoPlus,
          'subscriber_id': sid,
        },
      );
      final code = r['status_code']?.toString() ?? '';
      final status = r['subscription_status']?.toString().toUpperCase() ?? '';
      final ok = code == 'S1000' || code == '0000';
      // AppsPro signals success via `status_code: S1000` (with no
      // `subscription_status` field, or `UNREGISTERED`). The user is
      // unsubscribed if AppsPro says so; otherwise the subscription is
      // still active. We've been silently flipping the UI to
      // "unregistered" on every error response (including `E1951`
      // "format invalid"), which left BDApps dashboard showing
      // REGISTERED while the app pretended the cancel had worked.
      final isSubscribed = !ok && status == 'REGISTERED';
      return BdappsStatus(
        isSubscribed: isSubscribed,
        subscriptionStatus: status,
        statusCode: code,
        statusDetail: r['status_detail']?.toString() ?? '',
        subscriberId: sid,
      );
    }

    final r = await _post(
      '${baseUrl ?? ''}${unsubscribePath ?? '/unsubscribe.php'}',
      body: {'user_mobile': '0$digits'},
    );
    return BdappsStatus(
      isSubscribed: r['subscriptionStatus'] == 'REGISTERED',
      subscriptionStatus: r['subscriptionStatus']?.toString() ?? '',
      statusCode: r['statusCode']?.toString() ?? '',
      statusDetail: r['statusDetail']?.toString() ?? '',
      subscriberId: r['subscriberId']?.toString() ?? 'tel:88$digits',
    );
  }

  /// In-app: open the hosted checkout page in a WebView / external browser.
  String hostedCheckoutUrl(String urlSlug, {String? redirectUrl}) {
    final base = 'https://appspro.dev/s/$urlSlug';
    if (redirectUrl == null) return base;
    return '$base?redirect_url=${Uri.encodeComponent(redirectUrl)}';
  }

  /// Compose the embed URL for the subscription widget iframe.
  String embedUrl({
    required String publishableKey,
    required String token,
    String theme = 'light',
    String buttonText = 'Subscribe',
  }) {
    const base = 'https://api.appspro.dev/embed/subscribe';
    return '$base'
        '?publishable_key=$publishableKey'
        '&token=$token'
        '&theme=$theme'
        '&button_text=${Uri.encodeComponent(buttonText)}'
        '&button_color=3D5AFE';
  }

  // ---- helpers ----
  void _requireSecretKey() {
    if (secretKey == null || secretKey!.isEmpty) {
      throw Exception(
        'AppsPro secret key not configured. '
        'Build the APK with --dart-define=APPSPRO_SECRET_KEY=sk_live_...',
      );
    }
  }

  Map<String, String> _bearerHeaders() => {
        'Authorization': 'Bearer ${secretKey ?? ''}',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>> _post(
    String url, {
    Map<String, String>? headers,
    required Map<String, dynamic> body,
  }) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              if (headers != null) ...headers,
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception(
        'BDApps server didn\u0027t respond in time. '
        'Check your internet and try again.',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Couldn\u0027t reach BDApps server: ${e.message}. '
        'Check your internet and try again.',
      );
    }
    if (res.statusCode >= 500) {
      throw Exception('BDApps server error (${res.statusCode}). Try again later.');
    }
    if (res.statusCode == 404) {
      throw Exception(
        'BDApps endpoint not found (404). '
        'Did you set BDAPPS_BASE_URL when building the APK?',
      );
    }
    // Some gateways (and the BDApps sandbox) return HTML error pages
    // (e.g. an Nginx 502 or a captcha wall) when the request is
    // blocked. Treat non-JSON bodies as a transport-level failure
    // instead of crashing with FormatException.
    final trimmed = res.body.trimLeft();
    if (trimmed.startsWith('<') || trimmed.startsWith('<!')) {
      throw Exception(
        'BDApps returned an HTML page instead of JSON (HTTP '
        '${res.statusCode}). '
        'The backend URL may be wrong or the server is down.',
      );
    }
    final dynamic data;
    try {
      data = json.decode(res.body);
    } on FormatException {
      throw Exception(
        'BDApps returned an unreadable response (HTTP ${res.statusCode}). '
        'Got: ${res.body.length > 80 ? '${res.body.substring(0, 80)}…' : res.body}',
      );
    }
    if (data is Map<String, dynamic>) return data;
    throw Exception('Unexpected response from $url: ${res.body}');
  }

  /// `01XXXXXXXXX` -> `1XXXXXXXXX` (BDApps internal subscriber id form).
  String _normalize(String phone) {
    var s = phone.replaceAll(RegExp(r'\D'), '');
    if (s.startsWith('880') && s.length == 13) s = s.substring(2);
    if (s.startsWith('88') && s.length == 12) s = s.substring(2);
    if (s.startsWith('0') && s.length == 11) s = s.substring(1);
    return s;
  }

  String _toLocalFormat(String digits) => '0$digits';
}

/// Default service for this app.
///
/// We talk directly to the AppsPro SDK at `https://api.appspro.dev/api/v1`
/// using your AppsPro secret key — no PHP backend, no domain, no webhook
/// receiver required for the basic OTP / status / unsubscribe flow.
///
/// Build the APK with:
///   flutter build apk --release \
///     --dart-define=APPSPRO_SECRET_KEY=secret_key_live_xxxxxxxxxxxxxxxxxxxxxxxx
///
/// The AppsPro secret key is read from the compile-time define so it
/// never lands in source control.
BdappsService buildDefaultBdappsService() {
  const secretKey = String.fromEnvironment('APPSPRO_SECRET_KEY');
  return BdappsService(
    backend: 'appspro',
    secretKey: secretKey.isEmpty ? null : secretKey,
  );
}

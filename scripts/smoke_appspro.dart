// Standalone smoke test for the BDApps / AppsPro integration.
//
// Run with:
//   dart run scripts/smoke_appspro.dart \
//     --phone 01712345678 \
//     --otp 123456 \
//     --secret sk_xxxxxxxxxxxxx
//
// (You won't actually receive the OTP unless you're testing live.
// Use --skip-verify to stop after requestOtp.)
//
// If AppsPro is rate-limiting OTP requests for this number
// (`E1853: Maximum number of OTP requests reached`), pass
// `--wait-for-otp` to keep retrying `requestOtp` with exponential
// backoff until a fresh `reference_no` is issued (or until
// `--otp-poll-max <seconds>` elapses, default 600s).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Tiny CLI args parser.
class Args {
  final String phone;
  final String otp;
  final String secret;
  final bool skipVerify;
  final bool skipUnsubscribe;
  final bool waitForOtp;
  final Duration otpPollMax;

  Args._({
    required this.phone,
    required this.otp,
    required this.secret,
    required this.skipVerify,
    required this.skipUnsubscribe,
    required this.waitForOtp,
    required this.otpPollMax,
  });

  factory Args.parse(List<String> argv) {
    String phone = '01700000000';
    String otp = '000000';
    String secret = '';
    bool skipVerify = false;
    bool skipUnsubscribe = false;
    bool waitForOtp = false;
    Duration otpPollMax = const Duration(minutes: 10);
    for (var i = 0; i < argv.length; i++) {
      switch (argv[i]) {
        case '--phone':
          phone = argv[++i];
          break;
        case '--otp':
          otp = argv[++i];
          break;
        case '--secret':
          secret = argv[++i];
          break;
        case '--skip-verify':
          skipVerify = true;
          break;
        case '--skip-unsubscribe':
          skipUnsubscribe = true;
          break;
        case '--wait-for-otp':
          waitForOtp = true;
          break;
        case '--otp-poll-max':
          // e.g. --otp-poll-max 600  (seconds)
          otpPollMax = Duration(seconds: int.parse(argv[++i]));
          break;
      }
    }
    if (secret.isEmpty) {
      const fromEnv = String.fromEnvironment('APPSPRO_SECRET_KEY');
      if (fromEnv.isNotEmpty) secret = fromEnv;
    }
    if (secret.isEmpty && Platform.environment['APPSPRO_SECRET_KEY'] != null) {
      secret = Platform.environment['APPSPRO_SECRET_KEY']!;
    }
    if (secret.isEmpty) {
      // Try a local file so the secret never has to be typed on the
      // command line. Path is taken from --secret-file or defaults.
      String? path;
      for (var i = 0; i < argv.length; i++) {
        if (argv[i] == '--secret-file') {
          path = argv[++i];
        }
      }
      path ??= '.appspro_secret';
      if (File(path).existsSync()) {
        secret = File(path).readAsStringSync().trim();
      }
    }
    return Args._(
      phone: phone,
      otp: otp,
      secret: secret,
      skipVerify: skipVerify,
      skipUnsubscribe: skipUnsubscribe,
      waitForOtp: waitForOtp,
      otpPollMax: otpPollMax,
    );
  }
}

const _base = 'https://api.appspro.dev/api/v1';

String _normalize(String phone) {
  var s = phone.replaceAll(RegExp(r'\D'), '');
  if (s.startsWith('880') && s.length == 13) s = s.substring(2);
  if (s.startsWith('88') && s.length == 12) s = s.substring(2);
  if (s.startsWith('0') && s.length == 11) s = s.substring(1);
  return s;
}

String _toLocal(String d) => '0$d';
String _toIntlNoPlus(String d) => '880$d';

Future<Map<String, dynamic>> _post(
  String url,
  Map<String, dynamic> body, {
  required String secret,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final req = await client.postUrl(Uri.parse(url));
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Authorization', 'Bearer $secret');
    req.add(utf8.encode(json.encode(body)));
    final resp = await req.close();
    final raw = await resp.transform(utf8.decoder).join();
    stdout.writeln('HTTP ${resp.statusCode} ${resp.reasonPhrase}');
    stdout.writeln('URL: $url');
    stdout.writeln('Body sent: ${json.encode(body)}');
    stdout.writeln('Response: $raw');
    stdout.writeln('---');
    if (resp.statusCode >= 400) {
      // AppsPro returns JSON `{"detail": "..."}` for app-level config
      // problems (e.g. "App is missing BDApps credentials"). Surface
      // that hint as a tailored message instead of letting the raw
      // exception bubble up.
      String hint = raw;
      try {
        final parsed = json.decode(raw);
        if (parsed is Map && parsed['detail'] is String) {
          hint = parsed['detail'] as String;
        }
      } on FormatException {/* ignore */}
      if (resp.statusCode == 400) {
        stderr.writeln(
          'HTTP 400 — AppsPro rejected the request. '
          'This usually means your secret key is valid but the app '
          'is not fully configured (no BDApps product / credentials '
          'linked under it). '
          'See docs/BDAPPSPRO_CREATION_GUIDE.md §5.',
        );
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        stderr.writeln(
          'HTTP ${resp.statusCode} — auth failed. Check '
          'APPSPRO_SECRET_KEY is correct and still active.',
        );
      }
      throw Exception('HTTP ${resp.statusCode}: $hint');
    }
    try {
      final parsed = json.decode(raw);
      if (parsed is Map<String, dynamic>) return parsed;
      throw Exception('Expected JSON object, got: $raw');
    } on FormatException catch (e) {
      throw Exception('JSON parse failed: ${e.message} -- body: $raw');
    }
  } finally {
    client.close();
  }
}

Future<void> main(List<String> argv) async {
  final args = Args.parse(argv);
  if (args.secret.isEmpty) {
    stderr.writeln(
        'ERROR: secret key missing. Pass --secret sk_... or APPSPRO_SECRET_KEY env.');
    exit(2);
  }
  final digits = _normalize(args.phone);
  stdout.writeln('Normalized phone digits: $digits');
  stdout.writeln('Local form: ${_toLocal(digits)}   Intl (no +): ${_toIntlNoPlus(digits)}');
  stdout.writeln('');

  // Step 1: request OTP
  stdout.writeln('=== STEP 1: request OTP ===');
  Future<Map<String, dynamic>> requestOtpOnce() => _post(
        '$_base/sdk/otp/request',
        {'phone': _toLocal(digits)},
        secret: args.secret,
      );

  Map<String, dynamic> reqResult;
  try {
    reqResult = await requestOtpOnce();
  } catch (e) {
    stderr.writeln('FAIL: requestOtp threw: $e');
    exit(1);
  }
  // If AppsPro is rate-limiting the number, optionally poll until the
  // window clears. We treat `E1853` as the only recoverable signal —
  // any other error from step 1 means the request shape is wrong or
  // the app is misconfigured, and retrying won't help.
  String? reqStatus = reqResult['status_code']?.toString();
  while (args.waitForOtp &&
      reqStatus == 'E1853' &&
      reqResult['reference_no'] == null) {
    final stopwatch = Stopwatch()..start();
    var delay = const Duration(seconds: 5);
    const maxDelay = Duration(seconds: 60);
    stdout.writeln(
        'Rate-limited (E1853). Polling until a reference_no is issued '
        '(max ${args.otpPollMax.inSeconds}s)...');
    var lastReport = DateTime.now();
    while (stopwatch.elapsed < args.otpPollMax) {
      await Future.delayed(delay);
      try {
        reqResult = await requestOtpOnce();
      } catch (e) {
        stderr.writeln('poll error (will retry): $e');
        continue;
      }
      reqStatus = reqResult['status_code']?.toString();
      if (reqResult['reference_no'] != null) break;
      final now = DateTime.now();
      if (now.difference(lastReport) >= const Duration(seconds: 15)) {
        lastReport = now;
        stdout.writeln(
            'still rate-limited after ${stopwatch.elapsed.inSeconds}s '
            '(status=$reqStatus); next retry in ${delay.inSeconds}s');
      }
      // Exponential backoff capped at maxDelay.
      delay = delay * 2;
      if (delay > maxDelay) delay = maxDelay;
      if (reqStatus != 'E1853') break; // give up early on a different error
    }
    if (reqResult['reference_no'] == null) {
      stderr.writeln(
          'FAIL: still rate-limited after ${args.otpPollMax.inSeconds}s. '
          'Last status_code=$reqStatus.');
      exit(1);
    }
  }
  final refNo = reqResult['reference_no']?.toString();
  reqStatus = reqResult['status_code']?.toString();
  if (refNo == null || refNo.isEmpty) {
    stderr.writeln('FAIL: no reference_no in response. status_code=$reqStatus');
    exit(1);
  }
  stdout.writeln('reference_no=$refNo, status_code=$reqStatus');
  stdout.writeln('');

  if (args.skipVerify) {
    stdout.writeln('--skip-verify: stopping after requestOtp.');
    return;
  }

  // Step 2: verify OTP
  stdout.writeln('=== STEP 2: verify OTP ===');
  final verResult = await _post(
    '$_base/sdk/otp/verify',
    {'reference_no': refNo, 'otp': args.otp},
    secret: args.secret,
  );
  final verStatus = verResult['subscription_status']?.toString();
  final subscriberId = verResult['subscriber_id']?.toString();
  stdout.writeln('subscription_status=$verStatus, subscriber_id=$subscriberId');
  stdout.writeln('');

  if (args.skipUnsubscribe) {
    stdout.writeln('--skip-unsubscribe: stopping after verifyOtp.');
    return;
  }

  // Step 3: unsubscribe
  stdout.writeln('=== STEP 3: unsubscribe ===');
  if (subscriberId == null || subscriberId.isEmpty) {
    stderr.writeln('FAIL: no subscriber_id from verifyOtp; cannot unsubscribe.');
    exit(3);
  }
  await _post(
    '$_base/sdk/unsubscribe',
    {'phone': _toIntlNoPlus(digits), 'subscriber_id': subscriberId},
    secret: args.secret,
  );

  stdout.writeln('=== DONE ===');
}
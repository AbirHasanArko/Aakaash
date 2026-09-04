// Verify an existing OTP and (if successful) unsubscribe.
// Use after the user has already received an OTP from a separate
// `requestOtp` call and the cooldown prevents re-issuing.
import 'dart:convert';
import 'dart:io';

Future<void> _post(
  String url,
  Map<String, String> headers,
  Map<String, dynamic> payload,
) async {
  stdout.writeln('--- POST $url');
  stdout.writeln('Body: ${json.encode(payload)}');
  final client = HttpClient();
  try {
    final req = await client.postUrl(Uri.parse(url));
    headers.forEach(req.headers.set);
    req.write(json.encode(payload));
    final res = await req.close().timeout(const Duration(seconds: 15));
    final bodyText = await res.transform(utf8.decoder).join();
    stdout.writeln('HTTP ${res.statusCode}');
    stdout.writeln(bodyText);
  } catch (e) {
    stderr.writeln('ERR: $e');
  } finally {
    client.close();
  }
}

Future<void> main(List<String> args) async {
  String? secretPath;
  String phone = '01880703858';
  String referenceNo = '';
  String otp = '';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--secret-file' && i + 1 < args.length) {
      secretPath = args[++i];
    } else if (args[i] == '--phone' && i + 1 < args.length) {
      phone = args[++i];
    } else if (args[i] == '--reference-no' && i + 1 < args.length) {
      referenceNo = args[++i];
    } else if (args[i] == '--otp' && i + 1 < args.length) {
      otp = args[++i];
    }
  }
  if (secretPath == null || referenceNo.isEmpty || otp.isEmpty) {
    stderr.writeln('Need --secret-file <path> --reference-no <ref> --otp <code>');
    exit(2);
  }
  final secret = File(secretPath).readAsStringSync().trim();

  final digits = phone.replaceAll(RegExp(r'\D'), '');
  var d = digits;
  if (d.startsWith('880') && d.length == 13) d = d.substring(2);
  if (d.startsWith('88') && d.length == 12) d = d.substring(2);
  if (d.startsWith('0') && d.length == 11) d = d.substring(1);
  final intlNoPlus = '880$d';

  final headers = {
    'Authorization': 'Bearer $secret',
    'Content-Type': 'application/json',
  };

  stdout.writeln('=== STEP 2: verify OTP ===');
  final verify = await _post(
    'https://api.appspro.dev/api/v1/sdk/otp/verify',
    headers,
    {'reference_no': referenceNo, 'otp': otp},
  );
  // ...existing code...
}
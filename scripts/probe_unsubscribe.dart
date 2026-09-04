// One-off probe: hit /sdk/unsubscribe with two shapes to see which
// AppsPro accepts. Run with:
//   dart run scripts/probe_unsubscribe.dart --secret-file .appspro_secret
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
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--secret-file' && i + 1 < args.length) {
      secretPath = args[++i];
    } else if (args[i] == '--phone' && i + 1 < args.length) {
      phone = args[++i];
    }
  }
  if (secretPath == null) {
    stderr.writeln('Need --secret-file <path>');
    exit(2);
  }
  final secret = File(secretPath).readAsStringSync().trim();

  // Normalize: 01880703858 -> 1880703858
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  var d = digits;
  if (d.startsWith('880') && d.length == 13) d = d.substring(2);
  if (d.startsWith('88') && d.length == 12) d = d.substring(2);
  if (d.startsWith('0') && d.length == 11) d = d.substring(1);
  // Now `d` is 10 digits like "1880703858".

  const url = 'https://api.appspro.dev/api/v1/sdk/unsubscribe';
  final headers = {
    'Authorization': 'Bearer $secret',
    'Content-Type': 'application/json',
  };

  // Shape A: 880 + digits (13 digits), tel: 880 + digits (13 digits)
  await _post(url, headers, {
    'phone': '880$d',
    'subscriber_id': 'tel:880$d',
  });

  // Shape B: 88 + digits (12 digits, the OLD bug shape)
  await _post(url, headers, {
    'phone': '88$d',
    'subscriber_id': 'tel:88$d',
  });

  // Shape C: phone only, no subscriber_id
  await _post(url, headers, {
    'phone': '880$d',
  });
}
// One-shot helper to copy the Aakaash brand logo into every Android
// mipmap density bucket so the launcher icon shows the Aakaash logo
// instead of the default Flutter logo.
//
// Run with:  dart run tool/install_launcher_icons.dart
import 'dart:io';

void main() {
  final src = Directory('assets/logo');
  if (!src.existsSync()) {
    stderr.writeln('assets/logo not found at ${src.absolute.path}');
    exit(1);
  }

  // Map source logo size -> Android density bucket.
  // Android density scale: mdpi=1x, hdpi=1.5x, xhdpi=2x, xxhdpi=3x, xxxhdpi=4x.
  // Our source PNGs of 128/256/512px give us:
  //   mdpi=48,  hdpi=72,  xhdpi=96,    xxhdpi=144,  xxxhdpi=192
  // We approximate by picking the closest source pixel size for each bucket.
  final Map<String, String> bucket = {
    'mipmap-mdpi': 'aakaash_logo_128.png',     // 128px close to 1x-1.5x range
    'mipmap-hdpi': 'aakaash_logo_128.png',     // 128px
    'mipmap-xhdpi': 'aakaash_logo_256.png',    // 256px
    'mipmap-xxhdpi': 'aakaash_logo_256.png',   // 256px
    'mipmap-xxxhdpi': 'aakaash_logo_512.png',  // 512px
  };

  final resRoot = Directory('android/app/src/main/res');
  if (!resRoot.existsSync()) {
    stderr.writeln('android/app/src/main/res not found');
    exit(1);
  }

  for (final entry in bucket.entries) {
    final srcFile = File('${src.path}/${entry.value}');
    if (!srcFile.existsSync()) {
      stderr.writeln('Missing source: ${srcFile.path}');
      exit(1);
    }
    final dstDir = Directory('${resRoot.path}/${entry.key}');
    if (!dstDir.existsSync()) {
      dstDir.createSync(recursive: true);
    }
    final dst = File('${dstDir.path}/ic_launcher.png');
    srcFile.copySync(dst.path);
    stdout.writeln('Copied ${entry.value} -> ${dst.path}');
  }

  // Also drop a 512px copy as the foreground for adaptive icons (API 26+).
  final adaptiveFg = File('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png');
  File('assets/logo/aakaash_logo_512.png').copySync(adaptiveFg.path);
  stdout.writeln('Copied aakaash_logo_512.png -> ${adaptiveFg.path}');

  stdout.writeln('Done. Rebuild with: flutter build apk --debug');
}

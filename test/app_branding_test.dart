import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production UI contains no legacy display name or brand mark', () {
    final legacy = RegExp(
      r'Nostalia|Nostalgia|assets/svgs/nostalia_mark\.svg|assets/images/home/lola_logo\.png',
    );
    final staleFiles = Directory('lib')
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => legacy.hasMatch(file.readAsStringSync()))
        .map((file) => file.path)
        .toList();
    expect(staleFiles, isEmpty);
  });

  test('iOS and Android use the Liora branding and app identifiers', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
      expect(_plistValue(plist, key), 'Liora');
    }
    expect(
      _plistValue(plist, 'NSUserTrackingUsageDescription'),
      startsWith('Allow Liora '),
    );
    expect(
      _plistValue(plist, 'CFBundleIdentifier'),
      r'$(PRODUCT_BUNDLE_IDENTIFIER)',
    );
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      RegExp(r'android:label="([^"]+)"').firstMatch(manifest)?.group(1),
      'Liora',
    );
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(
      RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle)?.group(1),
      'com.lioraai.videogenerator',
    );
  });

  test(
    'every configured launcher and launch image has its required dimensions',
    () {
      const iconRoot = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      final catalog =
          jsonDecode(File('$iconRoot/Contents.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final entry in catalog['images'] as List<dynamic>) {
        final size = double.parse((entry['size'] as String).split('x').first);
        final scale = int.parse((entry['scale'] as String).replaceAll('x', ''));
        final pixels = (size * scale).round();
        expect(_pngSize('$iconRoot/${entry['filename']}'), [pixels, pixels]);
      }
      for (final entry in {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      }.entries) {
        expect(
          _pngSize(
            'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
          ),
          [entry.value, entry.value],
        );
      }
      const launchRoot = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
      final launch =
          jsonDecode(File('$launchRoot/Contents.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final entry in launch['images'] as List<dynamic>) {
        expect(entry['filename'], startsWith('Liora'));
        final scale = int.parse((entry['scale'] as String).replaceAll('x', ''));
        expect(_pngSize('$launchRoot/${entry['filename']}'), [
          128 * scale,
          128 * scale,
        ]);
      }
    },
  );
}

String? _plistValue(String plist, String key) => RegExp(
  '<key>$key</key>\\s*<string>([^<]*)</string>',
).firstMatch(plist)?.group(1);

List<int> _pngSize(String path) {
  final bytes = File(path).readAsBytesSync();
  expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10], reason: path);
  final data = ByteData.sublistView(bytes);
  return [data.getUint32(16), data.getUint32(20)];
}

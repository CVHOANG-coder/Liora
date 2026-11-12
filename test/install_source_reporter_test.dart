import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_gen/core/analytics/install_source_reporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'classifies Google, Meta and other known non-organic sources as ADS',
    () {
      for (final media in [
        'googleadwords_int',
        'Facebook Ads',
        'tiktokglobal_int',
      ]) {
        expect(
          InstallSource.fromConversionData({
            'af_status': 'Non-organic',
            'media_source': media,
          }),
          InstallSource.ads,
        );
      }
      expect(
        InstallSource.fromConversionData({'af_status': 'Organic'}),
        InstallSource.organic,
      );
      for (final data in <Map<String, dynamic>>[
        {},
        {'af_status': 'Unknown'},
        {'af_status': 'Non-organic'},
        {'af_status': 'Non-organic', 'media_source': 'restricted'},
        {'af_status': 'Non-organic', 'media_source': 'unknown'},
        {'af_status': 'Organic', 'media_source': 'googleadwords_int'},
      ]) {
        expect(InstallSource.fromConversionData(data), isNull);
      }
    },
  );

  test(
    'waits for attribution and identity in either order and deduplicates',
    () async {
      final sent = <String>[];
      final reporter = InstallSourceReporter(
        send: (id, source) async {
          sent.add('$id:$source');
        },
      );
      addTearDown(reporter.dispose);
      await reporter.recordSource(InstallSource.ads);
      expect(sent, isEmpty);
      await reporter.updateUser(42);
      await reporter.recordSource(InstallSource.ads);
      await reporter.retryPending();
      expect(sent, ['42:ADS']);
      await reporter.updateUser(43);
      expect(sent, ['42:ADS', '43:ADS']);

      SharedPreferences.setMockInitialValues({});
      final other = InstallSourceReporter(
        send: (id, source) async {
          sent.add('$id:$source');
        },
      );
      addTearDown(other.dispose);
      await other.updateUser(44);
      expect(sent, hasLength(2));
      await other.recordSource(InstallSource.organic);
      expect(sent.last, '44:ORGANIC');
    },
  );

  test(
    'never sends again after success even when attribution changes',
    () async {
      final sent = <String>[];
      final reporter = InstallSourceReporter(
        send: (_, source) async => sent.add(source),
      );
      addTearDown(reporter.dispose);
      await reporter.updateUser(42);
      await reporter.recordSource(InstallSource.organic);
      await reporter.recordSource(InstallSource.ads);
      await reporter.recordSource(InstallSource.organic);
      await reporter.retryPending();
      expect(sent, ['ORGANIC']);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('install_attribution_reported_v1_42'), isTrue);
    },
  );

  test('success flag survives restart and blocks a changed source', () async {
    final sent = <String>[];
    InstallSourceReporter create() =>
        InstallSourceReporter(send: (_, source) async => sent.add(source));
    final first = create();
    await first.updateUser(42);
    await first.recordSource(InstallSource.organic);
    first.dispose();
    final second = create();
    addTearDown(second.dispose);
    await second.recordSource(InstallSource.ads);
    await second.updateUser(42);
    await second.retryPending();
    expect(sent, ['ORGANIC']);
  });

  test('recognizes successful reports saved by the previous version', () async {
    for (final source in ['ADS', 'ORGANIC']) {
      SharedPreferences.setMockInitialValues({
        'install_attribution_sent_v1_42': source,
      });
      var attempts = 0;
      final reporter = InstallSourceReporter(
        send: (_, _) async {
          attempts++;
        },
      );
      await reporter.updateUser(42);
      await reporter.recordSource(InstallSource.ads);
      expect(attempts, 0);
      reporter.dispose();
    }
  });

  test(
    'persists pending attribution and successful acknowledgements across restart',
    () async {
      final sent = <String>[];
      var failing = true;
      InstallSourceReporter create() => InstallSourceReporter(
        send: (id, source) async {
          if (failing) throw StateError('offline');
          sent.add('$id:$source');
        },
      );
      final first = create();
      await first.updateUser(42);
      await first.recordSource(InstallSource.ads);
      first.dispose();
      failing = false;
      final second = create();
      await second.updateUser(42);
      expect(sent, ['42:ADS']);
      second.dispose();
      final third = create();
      addTearDown(third.dispose);
      await third.updateUser(42);
      await third.recordSource(InstallSource.organic);
      expect(sent, ['42:ADS']);
    },
  );

  test('retries transient failures automatically', () async {
    final completed = Completer<void>();
    var attempts = 0;
    final reporter = InstallSourceReporter(
      retryDelay: const Duration(milliseconds: 5),
      send: (_, _) async {
        attempts++;
        if (attempts == 1) throw StateError('offline');
        completed.complete();
      },
    );
    addTearDown(reporter.dispose);
    await reporter.updateUser(42);
    await reporter.recordSource(InstallSource.ads);
    await completed.future.timeout(const Duration(seconds: 2));
    expect(attempts, 2);
  });

  test(
    'serializes overlapping callbacks without duplicate HTTP requests',
    () async {
      final finish = Completer<void>();
      var attempts = 0;
      final reporter = InstallSourceReporter(
        send: (_, _) async {
          attempts++;
          await finish.future;
        },
      );
      addTearDown(reporter.dispose);
      await reporter.updateUser(42);
      final first = reporter.recordSource(InstallSource.ads);
      final second = reporter.recordSource(InstallSource.ads);
      finish.complete();
      await Future.wait([first, second]);
      expect(attempts, 1);
    },
  );
}

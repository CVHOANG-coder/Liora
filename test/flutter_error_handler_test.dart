import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/firebase/flutter_error_handler.dart';

void main() {
  test('late image download failure is reported as non-fatal', () {
    final reports = <({FlutterErrorDetails details, bool fatal})>[];
    final originalHandler = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalHandler);
    FlutterError.onError = FlutterErrorHandler(
      recordError: (details, {fatal = false}) async {
        reports.add((details: details, fatal: fatal));
      },
    ).call;
    final exception = HttpException(
      'Connection closed while receiving data',
      uri: Uri.parse('https://example.test/preview.webp'),
    );
    final stack = StackTrace.current;

    // Reproduce an image request completing after the widget's error listener
    // has gone away, as can happen when scrolling away from a theme card.
    _TestImageStreamCompleter().reportError(
      exception: exception,
      stack: stack,
      context: ErrorDescription('resolving an image codec'),
      silent: true,
    );

    expect(reports, hasLength(1));
    expect(reports.single.fatal, isFalse);
    expect(reports.single.details.exception, same(exception));
    expect(reports.single.details.stack, same(stack));
  });

  test('framework and image listener errors retain fatal reporting', () {
    final reports = <bool>[];
    final handler = FlutterErrorHandler(
      recordError: (details, {fatal = false}) async => reports.add(fatal),
    );

    for (final details in [
      FlutterErrorDetails(exception: StateError('build failed')),
      FlutterErrorDetails(
        exception: StateError('image listener failed'),
        library: 'image resource service',
      ),
      FlutterErrorDetails(
        exception: StateError('another silent failure'),
        library: 'another service',
        silent: true,
      ),
    ]) {
      handler(details);
    }

    expect(reports, [true, true, true]);
  });
}

class _TestImageStreamCompleter extends ImageStreamCompleter {}

import 'dart:async';

import 'package:flutter/foundation.dart';

typedef FlutterErrorRecorder =
    Future<void> Function(FlutterErrorDetails details, {bool fatal});

/// Keeps recoverable image failures visible without counting them as crashes.
class FlutterErrorHandler {
  const FlutterErrorHandler({required this.recordError});

  final FlutterErrorRecorder recordError;

  void call(FlutterErrorDetails details) {
    // ImageStreamCompleter marks expected loading/decoding failures as silent.
    // They can still reach this handler after a thumbnail leaves the screen
    // and its UI error listener has been removed. Keep reporting these failures
    // as non-fatal; do not downgrade other framework or image-listener errors.
    final recoverableImageError =
        details.library == 'image resource service' && details.silent;
    unawaited(recordError(details, fatal: !recoverableImageError));
  }
}

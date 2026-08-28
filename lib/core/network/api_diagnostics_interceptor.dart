import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only timings, without tokens, query strings, prompts or image bytes.
/// A terminal error is logged even when dart:io's Network entry stays pending.
class ApiDiagnosticsInterceptor extends Interceptor {
  ApiDiagnosticsInterceptor({
    this.enabled = kDebugMode,
    void Function(String)? log,
  }) : _log = log ?? debugPrint;

  final bool enabled;
  final void Function(String) _log;
  static const _traceKey = 'api_diagnostics_trace';
  static int _nextId = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      final previous = options.extra[_traceKey];
      final originalProgress = previous is _RequestTrace
          ? previous.originalProgress
          : options.onSendProgress;
      final trace = _RequestTrace(++_nextId, originalProgress);
      options.extra[_traceKey] = trace;
      final data = options.data;
      _write(
        trace,
        'start ${options.method} ${options.uri.path}'
        '${data is FormData ? ' multipart_bytes=${data.length}' : ''}',
      );
      // Do not install a progress callback on body-less requests.
      if (data != null) {
        options.onSendProgress = (sent, total) {
          if (!trace.finished &&
              trace.uploadFinishedMs == null &&
              total > 0 &&
              sent >= total) {
            trace.uploadFinishedMs = trace.clock.elapsedMilliseconds;
            // This measures bytes handed to the transport, not server receipt.
            _write(
              trace,
              'body_sent bytes=$sent '
              'elapsed_ms=${trace.uploadFinishedMs}',
            );
          }
          originalProgress?.call(sent, total);
        };
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _finish(response.requestOptions, 'response status=${response.statusCode}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final cause = err.error;
    // Only emit an allowlisted reason, never arbitrary exception text (which
    // can contain a URL, credential, local file path, or server response).
    final reason =
        cause is HttpException &&
            cause.message.toLowerCase().contains('connection reset by peer')
        ? 'connection_reset_by_peer'
        : cause?.runtimeType.toString() ?? 'none';
    _finish(
      err.requestOptions,
      'error type=${err.type.name} reason=$reason '
      'status=${err.response?.statusCode ?? 'none'}',
    );
    handler.next(err);
  }

  void _finish(RequestOptions options, String outcome) {
    final trace = options.extra[_traceKey];
    if (!enabled || trace is! _RequestTrace || trace.finished) return;
    trace.finished = true;
    trace.clock.stop();
    final totalMs = trace.clock.elapsedMilliseconds;
    final sentMs = trace.uploadFinishedMs;
    _write(
      trace,
      '$outcome elapsed_ms=$totalMs'
      '${sentMs == null ? '' : ' after_body_ms=${totalMs - sentMs}'}',
    );
  }

  void _write(_RequestTrace trace, String message) {
    try {
      _log('[API ${trace.id}] $message');
    } catch (_) {
      // Diagnostics must never break a request.
    }
  }
}

class _RequestTrace {
  _RequestTrace(this.id, this.originalProgress);

  final int id;
  final ProgressCallback? originalProgress;
  final Stopwatch clock = Stopwatch()..start();
  int? uploadFinishedMs;
  bool finished = false;
}

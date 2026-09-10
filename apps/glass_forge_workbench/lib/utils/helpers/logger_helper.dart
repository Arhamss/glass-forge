import 'dart:convert';

import 'package:flutter/foundation.dart';

const _sensitiveKeys = {
  'password',
  'token',
  'accesstoken',
  'refreshtoken',
  'otp',
  'authorization',
  'cookie',
  'set-cookie',
  'x-api-key',
  'cardnumber',
  'cvv',
  'pin',
};

bool _isSensitiveKey(String key) {
  final lower = key.toLowerCase();
  return _sensitiveKeys.any(lower.contains);
}

dynamic _redact(dynamic value) {
  if (value is Map) {
    return value.map<dynamic, dynamic>((dynamic k, dynamic v) {
      if (k is String && _isSensitiveKey(k)) {
        return MapEntry<dynamic, dynamic>(k, '***');
      }
      return MapEntry<dynamic, dynamic>(k, _redact(v));
    });
  }
  if (value is List) {
    return value.map<dynamic>(_redact).toList();
  }
  return value;
}

class AppLogger {
  AppLogger._();

  static const _w = 60;
  static const _encoder = JsonEncoder.withIndent('  ');

  static void debug(String message) {
    if (kDebugMode) debugPrint('  🔹 $message');
  }

  static void info(String message) {
    if (kDebugMode) debugPrint('  🔵 $message');
  }

  static void warning(String message) {
    if (!kDebugMode) return;
    final buf = StringBuffer()
      ..writeln('  ┌${'─' * _w}')
      ..writeln('  │ ⚠️ $message')
      ..write('  └${'─' * _w}');
    debugPrint(buf.toString());
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    final buf = StringBuffer()
      ..writeln('  ┌${'─' * _w}')
      ..writeln('  │ ❌ $message');

    if (error != null) {
      buf.writeln('  │    $error');
    }

    if (stackTrace != null) {
      buf.writeln('  ├${'─' * _w}');
      final frames = stackTrace
          .toString()
          .split('\n')
          .where(
            (l) =>
                l.trim().isNotEmpty &&
                !l.contains('dart:') &&
                !l.contains('package:flutter/') &&
                !l.contains('package:bloc/') &&
                !l.contains('package:dio/'),
          )
          .take(5);
      for (final frame in frames) {
        buf.writeln('  │ ${frame.trim()}');
      }
    }

    buf.write('  └${'─' * _w}');
    debugPrint(buf.toString());
  }

  static void verbose(String message) {
    if (kDebugMode) debugPrint('  ⚪ $message');
  }

  static String _maskToken(String token) {
    if (token.length <= 12) return '***';
    return '${token.substring(0, 6)}…${token.substring(token.length - 4)}';
  }

  static void authToken(String? token) {
    if (!kDebugMode || token == null || token.isEmpty) return;
    final buf = StringBuffer()
      ..writeln()
      ..writeln('  ╔${'═' * _w}')
      ..writeln('  ║ 🔑 Auth Token')
      ..writeln('  ╟${'─' * _w}')
      ..writeln('  ║   ${_maskToken(token)}')
      ..write('  ╚${'═' * _w}');
    debugPrint(buf.toString(), wrapWidth: 1024);
  }

  static void apiRequest({
    required String method,
    required Uri uri,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParams,
    dynamic body,
  }) {
    if (!kDebugMode) return;

    final buf = StringBuffer()
      ..writeln()
      ..writeln('  ╔${'═' * _w}')
      ..writeln('  ║ ➜ $method  ${uri.path}')
      ..writeln('  ║   $uri');

    if (headers != null && headers.isNotEmpty) {
      buf.writeln('  ╟${'─' * _w}');
      for (final e in headers.entries) {
        if (e.key.toLowerCase() == 'authorization') continue;
        final value = _isSensitiveKey(e.key) ? '***' : e.value;
        buf.writeln('  ║   ${e.key}: $value');
      }
    }

    if (queryParams != null && queryParams.isNotEmpty) {
      buf
        ..writeln('  ╟${'─' * _w}')
        ..writeln('  ║ Query:');
      for (final e in queryParams.entries) {
        buf.writeln('  ║   ${e.key}: ${e.value}');
      }
    }

    if (body != null) {
      buf.writeln('  ╟${'─' * _w}');
      _writeBlock(buf, _prettyJson(body), '║');
    }

    buf.write('  ╚${'═' * _w}');
    debugPrint(buf.toString());
  }

  static void apiResponse({
    required String method,
    required String path,
    required int statusCode,
    required int elapsedMs,
    dynamic body,
  }) {
    if (!kDebugMode) return;

    final buf = StringBuffer()
      ..writeln()
      ..writeln('  ┌${'─' * _w}')
      ..writeln('  │ ✅ $statusCode  $method $path  ⏱ ${elapsedMs}ms');

    if (body != null) {
      buf.writeln('  ├${'─' * _w}');
      _writeBlock(buf, _prettyJson(body), '│');
    }

    buf.write('  └${'─' * _w}');
    debugPrint(buf.toString());
  }

  static void apiError({
    required String method,
    required String path,
    required int statusCode,
    required int elapsedMs,
    dynamic body,
    String? errorMessage,
  }) {
    if (!kDebugMode) return;

    final buf = StringBuffer()
      ..writeln()
      ..writeln('  ┏${'━' * _w}')
      ..writeln('  ┃ ❌ $statusCode  $method $path  ⏱ ${elapsedMs}ms');

    if (errorMessage != null) {
      buf.writeln('  ┃ $errorMessage');
    }

    if (body != null) {
      buf.writeln('  ┣${'━' * _w}');
      _writeBlock(buf, _prettyJson(body), '┃');
    }

    buf.write('  ┗${'━' * _w}');
    debugPrint(buf.toString());
  }

  static String _prettyJson(dynamic data) {
    try {
      final object = data is String ? jsonDecode(data) : data;
      return _encoder.convert(_redact(object));
    } catch (_) {
      return data.toString();
    }
  }

  static void _writeBlock(StringBuffer buf, String text, String border) {
    for (final line in text.split('\n')) {
      buf.writeln('  $border   $line');
    }
  }
}

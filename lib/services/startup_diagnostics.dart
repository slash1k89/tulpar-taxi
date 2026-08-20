import 'package:flutter/foundation.dart';

class StartupDiagnostics {
  StartupDiagnostics._();

  static final Stopwatch _stopwatch = Stopwatch()..start();
  static final Set<String> _reportedOnce = <String>{};

  static void mark(String event, {bool once = true}) {
    if (!kDebugMode) return;
    if (once && !_reportedOnce.add(event)) return;
    debugPrint('[Startup] $event +${_stopwatch.elapsedMilliseconds}ms');
  }

  static void error(String event, Object error) {
    if (!kDebugMode) return;
    debugPrint(
      '[Startup] $event +${_stopwatch.elapsedMilliseconds}ms error=$error',
    );
  }
}

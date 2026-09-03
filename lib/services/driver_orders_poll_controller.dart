import 'dart:async';
import 'package:flutter/foundation.dart';

/// One completion-scheduled loop. Errors are state, never stream termination.
class DriverOrdersPollController<T> extends ChangeNotifier {
  DriverOrdersPollController({
    required this.load,
    required this.label,
    this.interval = const Duration(seconds: 2),
    this.source,
  });
  final Future<T> Function() load;
  final String label;
  final Duration interval;
  final Stream<T>? source;
  static int _nextId = 0;
  final int id = ++_nextId;
  int _generation = 0;
  int _requestId = 0;
  bool _running = false;
  bool _disposed = false;
  Future<void>? _inFlight;
  Timer? _timer;
  StreamSubscription<T>? _subscription;
  T? value;
  Object? error;
  bool hasData = false;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(
        '[DriverOrdersPoll] $label id=$id '
        'generation=$_generation request=$_requestId $message',
      );
    }
  }

  void start() {
    if (_running || _disposed) return;
    _running = true;
    final generation = ++_generation;
    if (source != null) {
      _subscription = source!.listen(
        (data) => _apply(data, generation),
        onError: (Object e) => _applyError(e, generation),
      );
    } else {
      unawaited(refresh());
    }
  }

  bool _current(int generation) =>
      !_disposed && _running && generation == _generation;

  void _apply(T data, int generation) {
    if (!_current(generation)) {
      _log('state skipped stale/disposed');
      return;
    }
    value = data;
    hasData = true;
    error = null;
    _log(
      'result success orderCount=${data is List
          ? data.length
          : data == null
          ? 0
          : 1} state applied',
    );
    notifyListeners();
  }

  void _applyError(Object e, int generation) {
    if (!_current(generation)) {
      _log('error skipped stale/disposed');
      return;
    }
    error = e;
    _log('error ${e.runtimeType}: $e state applied (last data retained)');
    notifyListeners();
  }

  Future<void> refresh() {
    if (!_running || _disposed || source != null) return Future.value();
    if (_inFlight != null) {
      _log('skip_overlap');
      return _inFlight!;
    }
    _timer?.cancel();
    final generation = _generation;
    _requestId++;
    _log('start');
    return _inFlight = Future<void>(() async {
      try {
        if (!_current(generation)) return;
        _apply(await load(), generation);
      } catch (e) {
        _applyError(e, generation);
      } finally {
        _inFlight = null;
        if (_running && !_disposed) {
          _log('next poll in ${interval.inMilliseconds}ms');
          _timer = Timer(interval, () => unawaited(refresh()));
        }
      }
    });
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _generation++;
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    _log('stopped');
  }

  @override
  void dispose() {
    stop();
    _disposed = true;
    super.dispose();
  }
}

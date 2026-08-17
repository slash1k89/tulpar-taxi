import 'dart:async';

typedef CancellationCleanup = void Function();
typedef CancellationMessage = Future<void> Function(String message);
typedef CancellationNavigation = void Function();
typedef CancellationError = void Function(Object error, StackTrace stackTrace);
typedef CancellationStateChanged = void Function();

/// Coordinates cancellation feedback and the one-time return to a clean map.
///
/// Firebase mutations stay in the workflow service. This controller only owns
/// the local lifecycle so it can cancel its timer when the screen is disposed.
class OrderCancellationController {
  OrderCancellationController({
    required CancellationCleanup onCleanup,
    required CancellationMessage onShowMessage,
    required CancellationNavigation onNavigate,
    required CancellationError onError,
    CancellationStateChanged? onStateChanged,
    this.returnDelay = const Duration(seconds: 3),
  }) : _onCleanup = onCleanup,
       _onShowMessage = onShowMessage,
       _onNavigate = onNavigate,
       _onError = onError,
       _onStateChanged = onStateChanged;

  final CancellationCleanup _onCleanup;
  final CancellationMessage _onShowMessage;
  final CancellationNavigation _onNavigate;
  final CancellationError _onError;
  final CancellationStateChanged? _onStateChanged;
  final Duration returnDelay;

  Timer? _returnTimer;
  bool _isCancelling = false;
  bool _hasHandledCancellation = false;
  bool _hasNavigated = false;
  bool _isDisposed = false;

  bool get isCancelling => _isCancelling;
  bool get hasHandledCancellation => _hasHandledCancellation;

  Future<bool> cancel(Future<void> Function() cancelOrder) async {
    if (_isDisposed || _isCancelling || _hasHandledCancellation) return false;

    _isCancelling = true;
    _notifyStateChanged();
    try {
      await cancelOrder();
      if (!_isDisposed) {
        _handleCancellation('Заказ отменён');
      }
      return true;
    } catch (error, stackTrace) {
      if (!_isDisposed) {
        _onError(error, stackTrace);
      }
      return false;
    } finally {
      _isCancelling = false;
      _notifyStateChanged();
    }
  }

  void handleObservedCancellation({required bool requestedLocally}) {
    _handleCancellation(
      requestedLocally
          ? 'Заказ отменён'
          : 'Заказ отменён водителем или системой',
    );
  }

  void _handleCancellation(String message) {
    if (_isDisposed || _hasHandledCancellation) return;

    _hasHandledCancellation = true;
    _returnTimer?.cancel();
    _onCleanup();
    if (_isDisposed) return;

    Future<void>.sync(() => _onShowMessage(message)).then(
      (_) => _navigateOnce(),
      onError: (Object error, StackTrace stackTrace) {
        // Failure to render feedback must not strand a cancelled order screen.
        if (!_isDisposed) {
          _onError(error, stackTrace);
        }
      },
    );
    _returnTimer = Timer(returnDelay, _navigateOnce);
    _notifyStateChanged();
  }

  void _navigateOnce() {
    if (_isDisposed || _hasNavigated) return;
    _hasNavigated = true;
    _returnTimer?.cancel();
    _returnTimer = null;
    _onNavigate();
  }

  void _notifyStateChanged() {
    if (!_isDisposed) _onStateChanged?.call();
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _returnTimer?.cancel();
    _returnTimer = null;
  }
}

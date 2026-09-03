import 'navigation_audio_service.dart';

const newOrderVoiceCue = NavigationAudioCue(
  assetPaths: ['audio/navigation/order_new.mp3'],
  fallbackText: 'Поступил новый заказ.',
);

class NewOrderArrivalTracker {
  final Set<String> _seenOrderIds = <String>{};
  bool _initialized = false;
  bool _isActive = true;
  bool _isDisposed = false;
  Set<String> lastNewOrderIds = {};

  void setActive(bool active) {
    if (_isDisposed) return;
    _isActive = active;
  }

  void reset() {
    if (_isDisposed) return;
    _seenOrderIds.clear();
    _initialized = false;
  }

  bool process(Iterable<String> orderIds) {
    lastNewOrderIds = {};
    if (_isDisposed) return false;
    final currentIds = orderIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (!_initialized) {
      _initialized = true;
      _seenOrderIds.addAll(currentIds);
      return false;
    }

    lastNewOrderIds = currentIds.difference(_seenOrderIds);
    final hasNewOrder = lastNewOrderIds.isNotEmpty;
    _seenOrderIds.addAll(currentIds);
    return _isActive && hasNewOrder;
  }

  void dispose() {
    _isDisposed = true;
    _isActive = false;
    _seenOrderIds.clear();
  }
}

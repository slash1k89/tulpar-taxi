import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/next_order.dart';
import 'tulpar_api_client.dart';

class NextOrderCandidateController extends ChangeNotifier {
  NextOrderCandidateController({
    required TulparApiClient apiClient,
    this.pollInterval = const Duration(seconds: 10),
  }) : _apiClient = apiClient;

  final TulparApiClient _apiClient;
  final Duration pollInterval;
  Timer? _timer;
  bool _eligible = false;
  bool _requestInFlight = false;
  bool _stoppedAfterSelection = false;
  bool _disposed = false;
  final Set<String> _hiddenOrderIds = {};

  NextOrderCandidate? candidate;
  bool isAccepting = false;
  String? lastError;

  bool get isPolling => _timer?.isActive == true;

  static bool isEligibleOrder(Map<String, dynamic> order) =>
      order['serviceType']?.toString() == 'city' &&
      order['status']?.toString() == 'in_progress';

  void updateOrder(Map<String, dynamic> order) {
    final eligible = isEligibleOrder(order);
    if (eligible == _eligible) return;
    _eligible = eligible;
    if (!eligible) {
      stop(clearCandidate: true);
      return;
    }
    _stoppedAfterSelection = false;
    unawaited(refresh());
    _timer = Timer.periodic(pollInterval, (_) => unawaited(refresh()));
  }

  Future<void> refresh() async {
    if (!_eligible || _stoppedAfterSelection || _requestInFlight || _disposed) {
      return;
    }
    _requestInFlight = true;
    try {
      final candidates = await _apiClient.getNextOrderCandidates();
      if (_disposed || !_eligible || _stoppedAfterSelection) return;
      candidates.removeWhere((item) => _hiddenOrderIds.contains(item.orderId));
      candidates.sort(
        (left, right) => left.distanceToCurrentDestinationMeters.compareTo(
          right.distanceToCurrentDestinationMeters,
        ),
      );
      candidate = candidates.isEmpty ? null : candidates.first;
      lastError = null;
      notifyListeners();
    } catch (_) {
      // Temporary candidate failures must not interfere with navigation.
    } finally {
      _requestInFlight = false;
    }
  }

  Future<bool> accept() async {
    final selected = candidate;
    if (selected == null || isAccepting || _disposed) return false;
    isAccepting = true;
    lastError = null;
    notifyListeners();
    try {
      await _apiClient.acceptNextOrder(selected.orderId);
      if (_disposed) return true;
      _stoppedAfterSelection = true;
      stop(clearCandidate: true);
      return true;
    } on TulparApiException catch (error) {
      if (_disposed) return false;
      lastError = 'Заказ уже недоступен';
      if (error.statusCode == 409 &&
          error.message.toLowerCase().contains('queued')) {
        _stoppedAfterSelection = true;
        stop(clearCandidate: true);
      } else {
        candidate = null;
        notifyListeners();
        await refresh();
        lastError = 'Заказ уже недоступен';
      }
      return false;
    } catch (_) {
      if (_disposed) return false;
      lastError = 'Заказ уже недоступен';
      candidate = null;
      notifyListeners();
      await refresh();
      lastError = 'Заказ уже недоступен';
      return false;
    } finally {
      if (!_disposed) {
        isAccepting = false;
        notifyListeners();
      }
    }
  }

  void markOfferSent(String orderId) {
    if (candidate?.orderId != orderId) return;
    _hiddenOrderIds.add(orderId);
    candidate = null;
    notifyListeners();
  }

  void stop({required bool clearCandidate}) {
    _timer?.cancel();
    _timer = null;
    if (clearCandidate) candidate = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

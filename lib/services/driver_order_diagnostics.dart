import 'package:flutter/foundation.dart';

class DriverOrderDiagnosticSnapshot {
  const DriverOrderDiagnosticSnapshot({
    required this.driverUid,
    required this.orderId,
    required this.driverStatus,
    required this.orderStatus,
    required this.orderDriverId,
    required this.passengerId,
    required this.orderCreatedAt,
    required this.driverActiveOrderExists,
    required this.driverActiveOrderId,
    required this.driverActiveOrderStatus,
    required this.linkedOrderWasChecked,
    required this.linkedOrderExists,
    required this.linkedOrderStatus,
    required this.existingOfferStatus,
    required this.userProfileExists,
    required this.hasValidUserName,
    required this.hasValidUserPhone,
    required this.hasValidUserRating,
    required this.hasCompleteVehicle,
  });

  static const activeOrderStatuses = {
    'searching',
    'accepted',
    'arrived',
    'driver_arrived',
    'in_progress',
  };

  final String driverUid;
  final String orderId;
  final String? driverStatus;
  final String? orderStatus;
  final String? orderDriverId;
  final String? passengerId;
  final DateTime? orderCreatedAt;

  final bool driverActiveOrderExists;
  final String? driverActiveOrderId;
  final String? driverActiveOrderStatus;

  final bool linkedOrderWasChecked;
  final bool? linkedOrderExists;
  final String? linkedOrderStatus;

  final String? existingOfferStatus;

  final bool userProfileExists;
  final bool hasValidUserName;
  final bool hasValidUserPhone;
  final bool hasValidUserRating;
  final bool hasCompleteVehicle;

  bool? get activeBindingIsStale {
    return classifyActiveBinding(
      bindingExists: driverActiveOrderExists,
      linkedOrderWasChecked: linkedOrderWasChecked,
      linkedOrderExists: linkedOrderExists,
      linkedOrderStatus: linkedOrderStatus,
    );
  }

  static bool? classifyActiveBinding({
    required bool bindingExists,
    required bool linkedOrderWasChecked,
    required bool? linkedOrderExists,
    required String? linkedOrderStatus,
  }) {
    if (!bindingExists) return false;

    if (!linkedOrderWasChecked || linkedOrderExists == null) {
      return null;
    }

    if (linkedOrderExists == false) {
      return true;
    }

    return !activeOrderStatuses.contains(linkedOrderStatus);
  }

  bool get orderIsFresh {
    final createdAt = orderCreatedAt;

    if (createdAt == null) {
      return false;
    }

    final age = DateTime.now().difference(createdAt);

    return !age.isNegative && age <= const Duration(hours: 2);
  }

  void log({required String prefix, required String failureStep}) {
    if (!kDebugMode) return;

    debugPrint(prefix);
    debugPrint('driverUid=$driverUid');
    debugPrint('orderId=$orderId');
    debugPrint('failureStep=$failureStep');
  }
}

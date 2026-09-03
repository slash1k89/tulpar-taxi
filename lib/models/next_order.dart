class NextOrderCandidate {
  const NextOrderCandidate({
    required this.orderId,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.passengerPrice,
    required this.distanceToCurrentDestinationMeters,
  });

  final String orderId;
  final String pickupAddress;
  final String destinationAddress;
  final int passengerPrice;
  final int distanceToCurrentDestinationMeters;

  factory NextOrderCandidate.fromJson(Map<String, dynamic> json) {
    return NextOrderCandidate(
      orderId: json['id']?.toString() ?? '',
      pickupAddress: json['pickupAddress']?.toString() ?? '',
      destinationAddress: json['destinationAddress']?.toString() ?? '',
      passengerPrice: (json['passengerPrice'] as num?)?.toInt() ?? 0,
      distanceToCurrentDestinationMeters:
          (json['distanceToCurrentDestinationMeters'] as num?)?.toInt() ?? 0,
    );
  }
}

class NextOrderAcceptanceResult {
  const NextOrderAcceptanceResult({
    required this.orderId,
    required this.status,
    required this.driverId,
    required this.queuedAfterOrderId,
    required this.passengerPrice,
    required this.agreedPrice,
    required this.distanceToCurrentDestinationMeters,
  });

  final String orderId;
  final String status;
  final String driverId;
  final String? queuedAfterOrderId;
  final int passengerPrice;
  final int agreedPrice;
  final int distanceToCurrentDestinationMeters;

  factory NextOrderAcceptanceResult.fromJson(Map<String, dynamic> json) {
    return NextOrderAcceptanceResult(
      orderId: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      driverId: (json['driverId'] ?? json['driver_id'])?.toString() ?? '',
      queuedAfterOrderId:
          (json['queuedAfterOrderId'] ?? json['queued_after_order_id'])
              ?.toString(),
      passengerPrice: (json['passengerPrice'] as num?)?.toInt() ?? 0,
      agreedPrice: (json['agreedPrice'] as num?)?.toInt() ?? 0,
      distanceToCurrentDestinationMeters:
          (json['distanceToCurrentDestinationMeters'] as num?)?.toInt() ?? 0,
    );
  }
}

class CompleteOrderResult {
  const CompleteOrderResult({
    required this.orderId,
    required this.status,
    required this.nextOrderActivated,
    required this.nextOrderId,
  });

  final String orderId;
  final String status;
  final bool nextOrderActivated;
  final String? nextOrderId;

  factory CompleteOrderResult.fromJson(Map<String, dynamic> json) {
    return CompleteOrderResult(
      orderId: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      nextOrderActivated: json['nextOrderActivated'] == true,
      nextOrderId: json['nextOrderId']?.toString(),
    );
  }
}

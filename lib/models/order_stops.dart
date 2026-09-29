class OrderStop {
  const OrderStop({
    required this.sequence,
    required this.address,
    required this.isFinal,
    this.reachedAt,
    this.raw = const {},
  });

  final int sequence;
  final String address;
  final bool isFinal;
  final Object? reachedAt;
  final Map<String, dynamic> raw;

  bool get isReached => reachedAt != null;
}

/// One canonical representation for create, details, available and active API
/// responses. Older orders without order_stops keep their final destination.
List<OrderStop> orderStopsFromData(Map<String, dynamic> order) {
  final rawStops = order['stops'];
  final parsed =
      <
        ({
          int sequence,
          int index,
          String address,
          Object? reachedAt,
          Map<String, dynamic> raw,
        })
      >[];
  if (rawStops is List) {
    for (var index = 0; index < rawStops.length; index++) {
      final value = rawStops[index];
      if (value is! Map) continue;
      final raw = Map<String, dynamic>.from(value);
      final address = raw['address']?.toString().trim() ?? '';
      if (address.isEmpty &&
          (raw['latitude'] ?? raw['lat']) == null &&
          (raw['longitude'] ?? raw['lng']) == null) {
        continue;
      }
      final sequence = raw['sequence'];
      parsed.add((
        sequence: sequence is num
            ? sequence.toInt()
            : int.tryParse(sequence?.toString() ?? '') ?? index,
        index: index,
        address: address,
        reachedAt: raw['reachedAt'] ?? raw['reached_at'],
        raw: raw,
      ));
    }
  }
  parsed.sort((a, b) {
    final bySequence = a.sequence.compareTo(b.sequence);
    return bySequence != 0 ? bySequence : a.index.compareTo(b.index);
  });
  if (parsed.isEmpty) {
    final address =
        (order['toAddress'] ?? order['destinationAddress'])
            ?.toString()
            .trim() ??
        '';
    if (address.isEmpty) return const [];
    return [OrderStop(sequence: 0, address: address, isFinal: true)];
  }
  return [
    for (var index = 0; index < parsed.length; index++)
      OrderStop(
        sequence: parsed[index].sequence,
        address: parsed[index].address,
        isFinal: index == parsed.length - 1,
        reachedAt: parsed[index].reachedAt,
        raw: parsed[index].raw,
      ),
  ];
}

Map<String, dynamic> normalizeOrderStops(Map<String, dynamic> order) => {
  ...order,
  'stops': [
    for (final stop in orderStopsFromData(order))
      {
        ...stop.raw,
        'sequence': stop.sequence,
        'address': stop.address,
        'reachedAt': stop.reachedAt,
      },
  ],
};

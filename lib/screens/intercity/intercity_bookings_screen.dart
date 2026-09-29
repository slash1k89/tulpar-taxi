import 'package:flutter/material.dart';

import '../../models/intercity_ride_booking.dart';
import '../../models/order_service_type.dart';
import '../../services/intercity_ride_service.dart';
import '../../services/address_label_service.dart';
import '../../services/intercity_contact_service.dart';
import '../../widgets/chat_unread_badge.dart';
import '../chat/chat_screen.dart';
import '../../utils/intercity_ride_formatters.dart';
import '../../widgets/app_drawer.dart';
import '../../l10n/generated/app_localizations.dart';

class IntercityBookingsScreen extends StatefulWidget {
  const IntercityBookingsScreen({super.key, this.repository});

  final IntercityRideRepository? repository;

  @override
  State<IntercityBookingsScreen> createState() =>
      _IntercityBookingsScreenState();
}

class _IntercityBookingsScreenState extends State<IntercityBookingsScreen> {
  late final IntercityRideRepository _repository;
  final Set<String> _cancelling = {};
  List<IntercityRideBooking> _bookings = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? IntercityRideService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bookings = await _repository.getMyBookings();
      if (mounted) setState(() => _bookings = bookings);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(IntercityRideBooking booking) async {
    if (_cancelling.contains(booking.bookingId)) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.bookingCancelTitle),
        content: Text(l10n.bookingCancelExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.bookingBack),
          ),
          ElevatedButton(
            key: const Key('intercity_cancel_booking_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.bookingCancel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling.add(booking.bookingId));
    try {
      final updated = await _repository.cancelBooking(booking.bookingId);
      if (!mounted) return;
      setState(() {
        _bookings = _bookings
            .map((item) => item.bookingId == updated.bookingId ? updated : item)
            .toList(growable: false);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.bookingCancelFailed)));
      }
    } finally {
      if (mounted) setState(() => _cancelling.remove(booking.bookingId));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(AppLocalizations.of(context).intercityMyBookings),
    ),
    drawer: const AppDrawer(
      mode: AppMode.passenger,
      selectedServiceType: OrderServiceType.intercity,
    ),
    body: _body(),
  );

  Widget _body() {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Center(
        key: Key('intercity_bookings_loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        key: const Key('intercity_bookings_error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.bookingLoadFailed),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    if (_bookings.isEmpty) {
      return Center(
        key: const Key('intercity_bookings_empty'),
        child: Text(l10n.bookingEmpty),
      );
    }
    final groups = <IntercityRideBookingStatus, List<IntercityRideBooking>>{};
    for (final booking in _bookings) {
      groups.putIfAbsent(booking.status, () => []).add(booking);
    }
    const order = [
      IntercityRideBookingStatus.confirmed,
      IntercityRideBookingStatus.cancelled,
      IntercityRideBookingStatus.completed,
      IntercityRideBookingStatus.unknown,
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final status in order)
            if (groups[status]?.isNotEmpty == true) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  _statusTitle(status, l10n),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final booking in groups[status]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BookingCard(
                    booking: booking,
                    cancelling: _cancelling.contains(booking.bookingId),
                    onCancel: () => _cancel(booking),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.cancelling,
    required this.onCancel,
  });

  final IntercityRideBooking booking;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final driver = booking.driver;
    final vehicle = [
      driver?.carModel,
      driver?.carColor,
      driver?.carNumber,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return Card(
      key: Key('intercity_booking_${booking.bookingId}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${booking.route.originCity} → ${booking.route.destinationCity}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatIntercityRideDate(booking.departureAt)}, '
              '${formatIntercityRideTime(booking.departureAt)}',
            ),
            Text(
              l10n.bookingSeatsAndPrice(
                booking.seats,
                formatTenge(booking.totalPrice),
              ),
            ),
            if (booking.pickupAddress?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                l10n.bookingPickup(
                  AddressLabelService.format(
                    booking.pickupAddress!,
                    Localizations.localeOf(context),
                  ),
                ),
              ),
            ],
            if (booking.passengerComment?.isNotEmpty == true)
              Text(l10n.bookingComment(booking.passengerComment!)),
            if (booking.status == IntercityRideBookingStatus.confirmed &&
                driver != null) ...[
              if (driver.name != null) Text(l10n.bookingDriver(driver.name!)),
              if (vehicle.isNotEmpty) Text(vehicle),
              if (driver.phone != null) Text(l10n.bookingPhone(driver.phone!)),
            ],
            if (booking.chatAvailable && driver != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: Key('intercity_booking_chat_${booking.bookingId}'),
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          orderId: booking.bookingId,
                          peerName: driver.name ?? l10n.driver,
                          intercity: true,
                        ),
                      ),
                    ),
                    icon: ChatUnreadBadge(
                      orderId: booking.bookingId,
                      intercity: true,
                    ),
                    label: Text(l10n.intercityOpenChat),
                  ),
                  if (driver.phone != null)
                    TextButton.icon(
                      key: Key(
                        'intercity_booking_whatsapp_${booking.bookingId}',
                      ),
                      onPressed: () async {
                        final opened = await openIntercityWhatsApp(
                          driver.phone,
                        );
                        if (!opened && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.intercityWhatsAppUnavailable),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l10n.intercityWhatsApp),
                    ),
                ],
              ),
            ],
            if (booking.canCancel) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                key: Key('intercity_cancel_booking_${booking.bookingId}'),
                onPressed: cancelling ? null : onCancel,
                child: cancelling
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.bookingCancel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _statusTitle(IntercityRideBookingStatus status, AppLocalizations l10n) =>
    switch (status) {
      IntercityRideBookingStatus.confirmed => l10n.bookingUpcoming,
      IntercityRideBookingStatus.cancelled => l10n.bookingCancelled,
      IntercityRideBookingStatus.completed => l10n.bookingCompleted,
      IntercityRideBookingStatus.unknown => l10n.bookingOther,
    };

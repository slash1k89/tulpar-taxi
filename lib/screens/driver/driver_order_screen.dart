import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../../widgets/chat_unread_badge.dart';
import '../../widgets/order_stops_view.dart';
import '../../services/driver_tracking_service.dart';
import '../../services/order_workflow_service.dart';
import '../../services/tulpar_api_client.dart';
import '../../widgets/delivery_details_view.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../app_routes.dart';
import '../../services/active_order_service.dart';
import '../../widgets/city_order_cancellation_dialog.dart';

class DriverOrderScreen extends StatefulWidget {
  const DriverOrderScreen({
    super.key,
    required this.orderId,
    this.orderDetailsStream,
    this.enableTracking = true,
  });

  final String orderId;
  final Stream<Map<String, dynamic>?>? orderDetailsStream;
  final bool enableTracking;

  @override
  State<DriverOrderScreen> createState() => _DriverOrderScreenState();
}

class _DriverOrderScreenState extends State<DriverOrderScreen> {
  bool _isUpdating = false;
  bool _isCancelling = false;
  bool _handledRemoteCancellation = false;

  final DriverTrackingService _tracking = DriverTrackingService();
  final TulparApiClient _apiClient = TulparApiClient();

  String? _trackingMessage;

  @override
  void initState() {
    super.initState();
    if (widget.enableTracking) _startTracking();
  }

  Future<void> _startTracking() async {
    final result = await _tracking.startLocationUpdates(widget.orderId);

    if (mounted && !result.isStarted) {
      setState(() => _trackingMessage = result.message);
    }
  }

  @override
  void dispose() {
    if (widget.enableTracking) _tracking.stopLocationUpdates(widget.orderId);
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      await OrderWorkflowService().transitionOrderStatus(
        orderId: widget.orderId,
        nextStatus: newStatus,
      );

      if (newStatus == 'completed') {
        await _tracking.stopLocationUpdates(widget.orderId);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).driverOrderUpdateFailed),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _cancelCityOrder(String status) async {
    if (_isCancelling) return;
    final reason = status == 'in_progress'
        ? await showCityCancellationDialog(context, isDriver: true)
        : null;
    if (status == 'in_progress' && reason == null) return;
    if (!mounted) return;
    if (status != 'in_progress') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(AppLocalizations.of(dialogContext).cancelOrderTitle),
          content: Text(AppLocalizations.of(dialogContext).confirmCancelOrder),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppLocalizations.of(dialogContext).no),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(AppLocalizations.of(dialogContext).yesCancel),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _isCancelling = true);
    try {
      await OrderWorkflowService().cancelOrder(
        widget.orderId,
        reasonCode: reason?.code,
        reasonText: reason?.text,
      );
      await _tracking.stopLocationUpdates(widget.orderId);
      ActiveOrderService.clearRememberedOrder();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.driverTaxi, (_) => false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).cancelOrderFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _returnAfterRemoteCancellation() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.driverTaxi, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream:
          widget.orderDetailsStream ??
          _apiClient.watchOrderDetails(widget.orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(child: CircularProgressIndicator(color: Colors.amber)),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: AppBar(
              title: Text(AppLocalizations.of(context).yourOrder),
              backgroundColor: const Color(0xFF1E1E1E),
              foregroundColor: Colors.amber,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppLocalizations.of(context).orderLoadFailed,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          );
        }

        final data = snapshot.data;

        if (data == null || data.isEmpty) {
          return Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(
              child: Text(
                AppLocalizations.of(context).chatOrderNotFound,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final status = data['status']?.toString() ?? 'accepted';
        if (data['serviceType'] == 'city' &&
            status == 'cancelled' &&
            !_handledRemoteCancellation) {
          _handledRemoteCancellation = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _tracking.stopLocationUpdates(widget.orderId);
            ActiveOrderService.clearRememberedOrder();
            _returnAfterRemoteCancellation();
          });
        }

        String statusTitle = AppLocalizations.of(context).driverOrderHeading;
        String buttonText = AppLocalizations.of(context).driverOrderAtPickup;
        String nextStatus = 'arrived';
        Color buttonColor = Colors.amber;
        bool showStatusButton = true;

        if (status == 'arrived' || status == 'driver_arrived') {
          statusTitle = AppLocalizations.of(context).driverOrderWaiting;
          buttonText = AppLocalizations.of(context).driverOrderStart;
          nextStatus = 'in_progress';
          buttonColor = Colors.green;
        } else if (status == 'in_progress') {
          statusTitle = AppLocalizations.of(context).driverOrderInProgress;
          buttonText = AppLocalizations.of(context).driverOrderFinish;
          nextStatus = 'completed';
          buttonColor = Colors.redAccent;
        } else if (status == 'completed') {
          statusTitle = AppLocalizations.of(context).statusTripCompleted;
          showStatusButton = false;
        } else if (status == 'cancelled') {
          statusTitle = AppLocalizations.of(context).orderCancelled;
          showStatusButton = false;
        } else if (status == 'searching') {
          statusTitle = AppLocalizations.of(context).statusSearchingDriver;
          showStatusButton = false;
        }

        final passengerName = data['passengerName']?.toString().trim() ?? '';

        final passengerPhone = data['passengerPhone']?.toString().trim() ?? '';

        final price =
            data['price'] ?? data['agreedPrice'] ?? data['passengerPrice'] ?? 0;

        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            title: Text(statusTitle),
            backgroundColor: const Color(0xFF1E1E1E),
            foregroundColor: Colors.amber,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: ChatUnreadBadge(orderId: widget.orderId),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        orderId: widget.orderId,
                        peerUserId: data['passengerId']?.toString(),
                        peerName: passengerName.isNotEmpty
                            ? passengerName
                            : AppLocalizations.of(context).passenger,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_trackingMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _trackingMessage!,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                Card(
                  color: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).driverRidePassengerName(
                            passengerName.isNotEmpty
                                ? passengerName
                                : AppLocalizations.of(context).passenger,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (passengerPhone.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            AppLocalizations.of(
                              context,
                            ).bookingPhone(passengerPhone),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ],
                        const Divider(color: Colors.white24, height: 24),
                        OrderStopsView(
                          orderData: data,
                          textColor: Colors.white70,
                        ),
                        if (DeliveryDetailsView.isDelivery(data)) ...[
                          const Divider(color: Colors.white24, height: 24),
                          DeliveryDetailsView(
                            orderData: data,
                            enableRecipientCall: true,
                            onDarkCard: true,
                          ),
                        ],
                        const Divider(color: Colors.white24, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(context).driverOrderCost,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '$price ₸',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (showStatusButton)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isUpdating
                          ? null
                          : () => _updateStatus(nextStatus),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isUpdating
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              buttonText,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                if (data['serviceType'] == 'city' &&
                    const {
                      'accepted',
                      'driver_arriving',
                      'driver_arrived',
                      'arrived',
                      'in_progress',
                    }.contains(status))
                  TextButton.icon(
                    onPressed: _isCancelling
                        ? null
                        : () => _cancelCityOrder(status),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(AppLocalizations.of(context).cancelOrder),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

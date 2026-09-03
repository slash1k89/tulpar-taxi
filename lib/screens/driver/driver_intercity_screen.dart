import 'package:flutter/material.dart';

import '../../models/order_service_type.dart';
import 'driver_screen.dart';

class DriverIntercityScreen extends StatelessWidget {
  const DriverIntercityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DriverScreen(serviceType: OrderServiceType.intercity);
  }
}

import 'package:flutter/material.dart';

import '../services/order_creation_service.dart';

void showOrderCreationError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(orderCreationUserMessage(error))));
}

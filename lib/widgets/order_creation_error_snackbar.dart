import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/order_creation_service.dart';

String localizedOrderCreationError(
  AppLocalizations l10n,
  Object error, {
  String? serviceType,
}) {
  if (error is! OrderCreationException) return l10n.orderErrorUnknown;
  return switch (error.failure) {
    OrderCreationFailure.notAuthenticated => l10n.orderErrorLogin,
    OrderCreationFailure.activeOrderExists => l10n.orderErrorActive,
    OrderCreationFailure.invalidData => switch (serviceType) {
      'delivery' => l10n.orderErrorDelivery,
      'intercity' => l10n.orderErrorIntercity,
      _ => l10n.orderErrorInvalid,
    },
    OrderCreationFailure.permissionDenied => l10n.orderErrorPermission,
    OrderCreationFailure.unavailable => l10n.orderErrorUnavailable,
    OrderCreationFailure.unknown => l10n.orderErrorUnknown,
  };
}

void showOrderCreationError(
  BuildContext context,
  Object error, {
  String? serviceType,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        localizedOrderCreationError(
          AppLocalizations.of(context),
          error,
          serviceType: serviceType,
        ),
      ),
    ),
  );
}

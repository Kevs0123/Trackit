import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'services/api.dart';

String fmtDate(DateTime? d) =>
    d == null ? '-' : DateFormat('MMM d, y  h:mm a').format(d);

String money(num? v) =>
    NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(v ?? 0);

String errText(Object e) => e is ApiException ? e.message : e.toString();

void showSnack(BuildContext context, String message,
    {bool error = false, String? actionLabel, VoidCallback? onAction}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : null,
      action: actionLabel != null && onAction != null
          ? SnackBarAction(label: actionLabel, onPressed: onAction)
          : null,
    ),
  );
}

Future<void> copyTrackingNumber(
    BuildContext context, String trackingNumber) async {
  try {
    await Clipboard.setData(ClipboardData(text: trackingNumber));
    if (context.mounted) showSnack(context, 'Tracking number copied.');
  } catch (e) {
    if (context.mounted) {
      showSnack(context, 'Could not copy tracking number: $e', error: true);
    }
  }
}

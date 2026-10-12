import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/api.dart';

String fmtDate(DateTime? d) => d == null ? '-' : DateFormat('MMM d, y  h:mm a').format(d);

String money(num? v) => NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(v ?? 0);

String errText(Object e) => e is ApiException ? e.message : e.toString();

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: error ? Colors.red.shade700 : null),
  );
}

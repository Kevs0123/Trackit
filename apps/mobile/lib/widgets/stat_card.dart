import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const StatCard(
      {super.key,
      required this.icon,
      required this.label,
      required this.value,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: c.withValues(alpha: 0.12),
                child: Icon(icon, color: c)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(label,
                      style:
                          TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

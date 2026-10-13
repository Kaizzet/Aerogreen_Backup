// lib/core/widgets/alert_row.dart
import 'package:flutter/material.dart';
import '../../data/models.dart'; // Assuming AppAlert is defined here

/// A row representing a single alert with an action button.
class AlertRow extends StatelessWidget {
  const AlertRow({
    required this.alert,
    required this.onResolve,
    super.key,
  });

  final AppAlert alert;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final urgent = alert.type == 'warning';
    final bg = urgent ? const Color(0xFFFDE7DC) : const Color(0xFFDDEFE0);
    final pill = urgent ? const Color(0xFFF2A93B) : const Color(0xFF8FAF94);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: bg,
            child: const Icon(Icons.notifications, size: 16, color: Colors.black),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(alert.message, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onResolve,
            style: OutlinedButton.styleFrom(
              backgroundColor: pill,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Xử lý ngay', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

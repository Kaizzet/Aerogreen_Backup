// lib/core/widgets/skeleton.dart
import 'package:flutter/material.dart';

/// Simple gray skeleton placeholder used while loading.
class Skeleton extends StatelessWidget {
  const Skeleton({
    required this.height,
    this.borderRadius = 8.0,
    super.key,
  });

  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

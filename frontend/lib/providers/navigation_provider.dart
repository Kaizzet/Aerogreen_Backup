// lib/providers/navigation_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Holds the index of the selected bottom navigation item (0..3)
final navigationIndexProvider = StateProvider<int>((ref) => 0);

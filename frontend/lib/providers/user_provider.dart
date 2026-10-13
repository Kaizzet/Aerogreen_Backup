// lib/providers/user_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';

/// Provides the mock user profile.
final userProfileProvider = Provider<UserProfile>((ref) => const UserProfile(
  fullName: 'Mira Patel',
  email: 'mira@aerogreen.app',
  plan: 'Pro',
));

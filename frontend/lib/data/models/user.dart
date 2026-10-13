// lib/data/models/user.dart
import 'package:equatable/equatable.dart';

/// Simple user model used by the mock auth layer.
class User extends Equatable {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String plan;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.plan,
  });

  factory User.fromMap(Map<String, dynamic> map) => User(
        id: map['id'] as String,
        fullName: map['fullName'] as String,
        email: map['email'] as String,
        role: map['role'] as String,
        plan: map['plan'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'role': role,
        'plan': plan,
      };

  @override
  List<Object?> get props => [id, fullName, email, role, plan];
}

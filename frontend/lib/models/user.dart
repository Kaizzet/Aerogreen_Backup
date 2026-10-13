class User {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String role; // 'user' hoặc 'admin'

  User({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.role = 'user', // Mặc định là 'user' nếu không truyền
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      role: json['role'] ?? 'user',
    );
  }

  // Hồ sơ trả về từ /api/auth/profile: vai trò nằm trong danh sách roles.
  factory User.fromProfileJson(Map<String, dynamic> json) {
    final roles = (json['roles'] as List<dynamic>? ?? const [])
        .map((role) => role.toString())
        .toList();
    return User(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      role: roles.contains('Admin') ? 'admin' : 'user',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role,
    };
  }

  // Helper getter để check role nhanh
  bool get isAdmin => role == 'admin';
  bool get isUser => role == 'user';
}
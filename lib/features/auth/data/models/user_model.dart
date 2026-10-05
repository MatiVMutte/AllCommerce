enum UserRole {
  owner('owner'),
  customer('customer');

  const UserRole(this.id);

  /// Value stored in the database.
  final String id;

  static UserRole fromId(String id) {
    for (final UserRole role in values) {
      if (role.id == id) return role;
    }
    return UserRole.customer;
  }
}

class UserModel {
  const UserModel({
    required this.id,
    this.tenantId,
    required this.role,
    required this.fullName,
    this.phone,
    this.isAdmin = false,
    required this.createdAt,
  });

  final String id;
  final String? tenantId;
  final UserRole role;
  final String fullName;
  final String? phone;
  final bool isAdmin;
  final DateTime createdAt;

  bool get isOwner => role == UserRole.owner;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      role: UserRole.fromId(json['role'] as String),
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'tenant_id': tenantId,
      'role': role.id,
      'full_name': fullName,
      'phone': phone,
      'is_admin': isAdmin,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? tenantId,
    UserRole? role,
    String? fullName,
    String? phone,
    bool? isAdmin,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

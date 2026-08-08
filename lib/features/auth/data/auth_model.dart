class UserModel {
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.role,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? role;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        role: json['role'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
      };
}

class AuthResponseModel {
  AuthResponseModel({required this.user, required this.token});

  final UserModel user;
  final String token;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) =>
      AuthResponseModel(
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
        token: json['token'] as String,
      );
}
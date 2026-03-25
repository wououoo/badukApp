import 'user.dart';

class AuthResponse {
  final bool success;
  final String? message;
  final String? token;
  final String? refreshToken;
  final String? phone;
  final String? name;
  final bool isNewUser;
  final int? expiresIn;
  final User? user;

  AuthResponse({
    this.success = true,
    this.message,
    this.token,
    this.refreshToken,
    this.phone,
    this.name,
    this.isNewUser = false,
    this.expiresIn,
    this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // OTP 응답 형식 또는 기존 형식 둘 다 지원
    User? user;
    if (json['user'] != null) {
      user = User.fromJson(json['user']);
    } else if (json['phone'] != null) {
      // OTP 응답에서 사용자 정보 생성
      user = User(
        id: 0,
        name: json['name'] ?? '',
        phone: json['phone'],
      );
    }

    return AuthResponse(
      success: json['success'] ?? true,
      message: json['message'],
      token: json['token'],
      refreshToken: json['refreshToken'],
      phone: json['phone'],
      name: json['name'],
      isNewUser: json['isNewUser'] ?? false,
      expiresIn: json['expiresIn'],
      user: user,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'token': token,
      'refreshToken': refreshToken,
      'phone': phone,
      'name': name,
      'isNewUser': isNewUser,
      'expiresIn': expiresIn,
      if (user != null) 'user': user!.toJson(),
    };
  }
}

class LoginRequest {
  final String phone;
  final String password;

  LoginRequest({
    required this.phone,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'password': password,
    };
  }
}

class SignupRequest {
  final String name;
  final String phone;
  final String password;
  final String? birthDate;
  final String? rank;
  final String? region;

  SignupRequest({
    required this.name,
    required this.phone,
    required this.password,
    this.birthDate,
    this.rank,
    this.region,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'password': password,
      if (birthDate != null) 'birthDate': birthDate,
      if (rank != null) 'rank': rank,
      if (region != null) 'region': region,
    };
  }
}

class LoginRequest {
  final String username;
  final String password;

  LoginRequest({required this.username, required this.password});

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
  };
}

class RegisterRequest {
  final String username;
  final String password;
  final String email;
  final String nickname;

  RegisterRequest({
    required this.username,
    required this.password,
    required this.email,
    required this.nickname,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'email': email,
    'nickname': nickname,
  };
}

class UserPayload {
  final int userId;
  final String username;
  final String email;
  final int coin;

  UserPayload({
    required this.userId,
    required this.username,
    required this.email,
    required this.coin,
  });

  // Factory parse từ JWT payload (Payload đã decode từ thư viện jwt_decoder)
  factory UserPayload.fromJwt(Map<String, dynamic> json) {
    return UserPayload(
      // Chuyển đổi an toàn: Nếu server trả về Long hoặc Int đều nhận được
      userId: (json['userId'] is num) ? (json['userId'] as num).toInt() : 0,
      
      // 'sub' là key chứa username trong backend Spring Security
      username: json['sub'] ?? 'Unknown', 
      
      email: json['email'] ?? '',
      
      coin: (json['coin'] is num) ? (json['coin'] as num).toInt() : 0,
    );
  }
}
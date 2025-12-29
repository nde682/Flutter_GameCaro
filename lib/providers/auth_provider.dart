// File: lib/providers/auth_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import '../data/models/auth_models.dart';

class AuthProvider with ChangeNotifier {
  // LƯU Ý QUAN TRỌNG:
  // - Nếu chạy trên Android Emulator: Dùng 'http://10.0.2.2:8080/api/auth'
  // - Nếu chạy trên Máy thật/iPhone: Dùng IP LAN của máy tính (VD: 'http://192.168.1.15:8080/api/auth')
  // - Nếu chạy trên Web: Dùng 'http://localhost:8080/api/auth'
  final String baseUrl = 'http://localhost:8080/api/auth'; 

  String? _token;
  UserPayload? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  String? get token => _token;
  UserPayload? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isLoggedIn => _token != null && !JwtDecoder.isExpired(_token!);

  // --- 1. ĐĂNG NHẬP ---
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(LoginRequest(username: username, password: password).toJson()),
      );

      if (response.statusCode == 200) {
        // Backend trả về chuỗi Token raw (String)
        _token = response.body; 

        // Decode JWT để lấy userId, username, coin...
        // Đảm bảo token hợp lệ trước khi decode
        if (_token != null && _token!.isNotEmpty) {
          Map<String, dynamic> decodedToken = JwtDecoder.decode(_token!);
          _currentUser = UserPayload.fromJwt(decodedToken);
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Xử lý lỗi từ Backend trả về
        _errorMessage = response.body; // VD: "Tên đăng nhập hoặc mật khẩu không đúng"
        print("Login failed: ${response.body}");
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print("Login connection error: $e");
      _errorMessage = "Lỗi kết nối đến máy chủ";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- 2. ĐĂNG KÝ (Thêm mới) ---
  Future<bool> register(String username, String password, String email, String nickname) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(RegisterRequest(
          username: username, 
          password: password, 
          email: email, 
          nickname: nickname
        ).toJson()),
      );

      if (response.statusCode == 200) {
        // Đăng ký thành công
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.body; // VD: "Username đã tồn tại"
        print("Register failed: ${response.body}");
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print("Register connection error: $e");
      _errorMessage = "Lỗi kết nối đến máy chủ";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- 3. ĐĂNG XUẤT ---
  void logout() {
    _token = null;
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }
}
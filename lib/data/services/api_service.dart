import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Đổi IP nếu chạy trên máy thật (VD: "http://192.168.1.X:8080/api")
  static const String baseUrl = "http://localhost:8080/api";

  // --- AUTHENTICATION ---

  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Đăng nhập thất bại: ${response.body}");
      }
    } catch (e) {
      throw Exception("Lỗi kết nối: $e");
    }
  }

  Future<Map<String, dynamic>> register(String username, String password, String email, String nickname) async {
    final url = Uri.parse('$baseUrl/auth/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'email': email,
          'nickname': nickname,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Đăng ký thất bại: ${response.body}");
      }
    } catch (e) {
      throw Exception("Lỗi kết nối: $e");
    }
  }

  // --- GAME LOBBY (REST API) ---
  
  // Lấy danh sách phòng đang hoạt động (cho màn hình Lobby)
  Future<List<dynamic>> getActiveRooms() async {
    final url = Uri.parse('$baseUrl/rooms'); // Cần đảm bảo Backend có endpoint này
    try {
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        return []; // Trả về rỗng nếu lỗi
      }
    } catch (e) {
      print("Lỗi lấy danh sách phòng: $e");
      return [];
    }
  }

  // Tạo phòng mới qua API (Nếu backend hỗ trợ tạo qua REST)
  Future<Map<String, dynamic>> createRoom(String roomName) async {
    final url = Uri.parse('$baseUrl/rooms/create');
    final headers = await _getHeaders();
    
    final response = await http.post(
      url, 
      headers: headers,
      body: jsonEncode({'name': roomName}) // Backend cần nhận param 'name'
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Không thể tạo phòng: ${response.body}");
    }
  }

  // --- HELPER ---

  // Tự động lấy Token từ bộ nhớ đệm để gắn vào Header
  Future<Map<String, String>> _getHeaders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("jwt_token");
    
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ""}',
    };
  }
}
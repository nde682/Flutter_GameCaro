import 'dart:async'; // Cần import thư viện này cho StreamController
import 'dart:convert';
import 'package:caro_online/data/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import '../data/models/game_room.dart';

class GameProvider with ChangeNotifier {
  // CONFIG IP:
  // - Máy thật Android/iOS: Dùng IP LAN của máy tính (VD: 192.168.1.x)
  // - Máy ảo Android: Dùng 10.0.2.2
  // - Web: Dùng localhost
  final String baseUrl = 'http://localhost:8080';
  final String socketUrl = 'ws://localhost:8080/ws';

  String? _token;
  String? _currentUserId;
  String? _currentUsername;

  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;
  
  // State Lobby
  List<GameRoom> _lobbyRooms = [];

  // State Room hiện tại
  GameRoom? _currentRoom;

  // Kết quả trận đấu (Lấy từ gói tin GAME_OVER để hiện popup)
  Map<String, dynamic>? _lastGameResult;

  // --- STREAM CONTROLLER (Quan trọng để xử lý Chat và Thông báo) ---
  // Dùng để bắn tin nhắn từ Socket ra UI (hiện SnackBar) mà không cần lưu vào biến State
  final _chatStreamController = StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get chatStream => _chatStreamController.stream;

  StompClient? _stompClient;
  bool _isLoading = false;

  // --- GETTERS ---
  List<GameRoom> get lobbyRooms => _lobbyRooms;
  GameRoom? get currentRoom => _currentRoom;
  String? get currentUserId => _currentUserId;
  String? get currentUsername => _currentUsername;
  Map<String, dynamic>? get lastGameResult => _lastGameResult;
  bool get isLoading => _isLoading;
  bool get isConnected => _stompClient?.connected ?? false;

  // ==================== 1. AUTHENTICATION (REST) ====================

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
          Map<String, dynamic> data = jsonDecode(response.body);
          _token = data['accessToken'] ?? data['token'];
          if (_token != null) {
          // Decode JWT để lấy ID
          Map<String, dynamic> decodedToken = JwtDecoder.decode(_token!);
          // Backend có thể trả về 'userId' hoặc 'id' tùy cấu hình JWT
          _currentUserId = decodedToken['userId']?.toString() ?? decodedToken['id']?.toString() ?? "0";
          _currentUsername = username;

          _isLoading = false;
          notifyListeners();

          // Kết nối socket ngay lập tức
          connectSocketLobby();
          return true;
        }
      }
    } catch (e) {
      print("Login Error: $e");
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register(String username, String password, String email, String nickname) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username, 'password': password, 'email': email, 'nickname': nickname
        }),
      );
      if (response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) { print(e); }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  void logout() {
    _token = null;
    _currentUserId = null;
    _disconnectSocket();
    _currentRoom = null;
    notifyListeners();
  }

  // ==================== 2. SOCKET CONNECTION (CORE) ====================

  void connectSocketLobby() {
    if (_token == null) return;
    if (_stompClient != null && _stompClient!.connected) return;

    _stompClient = StompClient(
      config: StompConfig(
        url: socketUrl,
        onConnect: (StompFrame frame) {
          print("✅ Socket Connected!");

          // Subscribe Lobby: Nhận danh sách phòng realtime
          _stompClient!.subscribe(
            destination: '/topic/rooms',
            callback: (frame) {
              if (frame.body != null) {
                try {
                  List<dynamic> data = jsonDecode(frame.body!);
                  _lobbyRooms = data.map((json) => GameRoom.fromJson(json)).toList();
                  notifyListeners();
                } catch (e) { print("Lỗi parse Lobby: $e"); }
              }
            },
          );
        },
        onWebSocketError: (e) => print("❌ WS Error: $e"),
        stompConnectHeaders: {'Authorization': 'Bearer $_token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $_token'},
      ),
    );
    _stompClient!.activate();
    fetchLobbyRoomsRest();
  }

  Future<void> fetchLobbyRoomsRest() async {
    if (_token == null) return;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/lobby/rooms'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        _lobbyRooms = data.map((json) => GameRoom.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) { print(e); }
  }

  // ==================== 3. GAMEPLAY LOGIC (QUAN TRỌNG) ====================

// Sửa từ void -> Future<bool>
  Future<bool> joinRoom(String roomId) async {
    if (_stompClient == null || !_stompClient!.connected) return false;

    // --- LOGIC KIỂM TRA PHÒNG TỒN TẠI ---
    // 1. Tìm trong danh sách hiện tại
    bool exists = _lobbyRooms.any((r) => r.roomId == roomId);

    // 2. Nếu chưa thấy, thử gọi API làm mới danh sách 1 lần nữa cho chắc
    if (!exists) {
      await fetchLobbyRoomsRest();
      exists = _lobbyRooms.any((r) => r.roomId == roomId);
    }

    // 3. Nếu vẫn không thấy -> Trả về false (Phòng không tồn tại)
    if (!exists) {
      return false; 
    }
    // --------------------------------------

    // Nếu tồn tại -> Reset state và Subscribe như cũ
    _currentRoom = null;
    _lastGameResult = null;

    // Subscribe Game Data
    _stompClient!.subscribe(
      destination: '/topic/room/$roomId',
      callback: (frame) {
        if (frame.body != null) {
          try {
            _handleGameMessage(jsonDecode(frame.body!));
          } catch (e) {
            print("❌ Error parsing game data: $e");
          }
        }
      },
    );

    // Subscribe Chat
    _stompClient!.subscribe(
      destination: '/topic/room/$roomId/chat',
      callback: (frame) {
        if (frame.body != null) {
          try {
            var msgData = jsonDecode(frame.body!);
            String sender = msgData['sender'] ?? "System";
            String content = msgData['content'] ?? "";

            // Đẩy dữ liệu vào Stream
            _chatStreamController.add({
              'sender': sender,
              'content': content
            });
          } catch(e) { print("Chat parse error: $e"); }
        }
      },
    );

    // Gửi lệnh Join lên Server
    _send('/app/game/join', {'roomId': roomId, 'message': _currentUsername});
    
    return true; // Join thành công (về mặt logic Client)
  }
  // Xử lý logic tin nhắn Game trả về
  void _handleGameMessage(Map<String, dynamic> data) {
    // Trường hợp 1: Bản tin đặc biệt (GAME_OVER, ERROR)
    if (data.containsKey('type')) {
      String type = data['type'];

      if (type == 'GAME_OVER') {
        print("🏁 GAME OVER DETECTED");
        // Lấy kết quả thắng thua/coin
        if (data.containsKey('resultChanges')) {
          _lastGameResult = data['resultChanges'];
        }
        // BẮT BUỘC: Cập nhật lại room lần cuối để đổi status sang FINISHED
        if (data.containsKey('room')) {
          _currentRoom = GameRoom.fromJson(data['room']);
        }
      }
      else if (type == 'ERROR') {
        print("⚠️ Server Error: ${data['message']}");
        _chatStreamController.add("Lỗi: ${data['message']}" as Map<String, String>);
      }
    }
    // Trường hợp 2: Bản tin cập nhật Room thông thường (DTO)
    else {
      try {
        _currentRoom = GameRoom.fromJson(data);

        // Nếu phòng quay lại trạng thái WAITING (Host bấm chơi lại), xóa bảng kết quả cũ
        if (_currentRoom?.status == "WAITING") {
          _lastGameResult = null;
        }
      } catch (e) {
        print("Lỗi parse GameRoom DTO: $e");
      }
    }

    notifyListeners();
  }

  // --- SEND ACTIONS (Các hành động người chơi gửi đi) ---

  void makeMove(String roomId, int x, int y) {
    _sendAction(roomId, 'MOVE', extra: {'x': x, 'y': y});
  }

  void toggleReady(String roomId) {
    _sendAction(roomId, 'READY');
  }

  void startGame(String roomId) {
    _lastGameResult = null;
    _sendAction(roomId, 'START');
  }

  void restartGame(String roomId) {
    _lastGameResult = null;
    _sendAction(roomId, 'RESTART');
  }

  void leaveRoom(String roomId) {
    _sendAction(roomId, 'LEAVE');
    _currentRoom = null;
    _lastGameResult = null;
    notifyListeners();
  }

  void updateRule(String roomId, bool block2Ends) {
    _sendAction(roomId, 'UPDATE_RULE', extra: {'ruleBlock2Ends': block2Ends});
  }

  void sendDrawRequest(String roomId) {
    _sendAction(roomId, 'DRAW_REQUEST');
  }

  void replyDrawRequest(String roomId, bool accept) {
    _sendAction(roomId, accept ? 'DRAW_ACCEPT' : 'DRAW_DECLINE');
  }

  void sendChat(String roomId, String message) {
    // Gửi chat lên Server, Server sẽ broadcast lại vào topic /chat
    _sendAction(roomId, 'CHAT', extra: {'message': message});
  }

  // API REST: Tạo phòng
  Future<String?> createRoom(String roomName, bool isBlock2Ends) async {
  try {
    // Lấy username hiện tại (đảm bảo bạn đã lưu username khi login)
    // Ví dụ: biến _currentUsername trong provider
    if (_currentUsername == null) return null;

    final response = await http.post(
      Uri.parse('$baseUrl/api/lobby/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token' // Vẫn giữ token để xác thực nếu cần
      },
      body: jsonEncode({
        'username': _currentUsername, // Gửi kèm username cho chắc
        'roomName': roomName,
        'ruleBlock2Ends': isBlock2Ends
      })
    );

    if (response.statusCode == 200) {
      return response.body; // Trả về RoomID
    } else {
      print("Create error: ${response.statusCode} - ${response.body}");
    }
  } catch (e) { 
    print("Create Room Error: $e"); 
  }
  return null;
}

  // --- HELPERS ---

  void _sendAction(String roomId, String type, {Map<String, dynamic>? extra}) {
    Map<String, dynamic> body = {
      'type': type,
      'roomId': roomId,
    };
    if (extra != null) {
      body.addAll(extra);
    }

    if (_stompClient != null && _stompClient!.connected) {
      _stompClient?.send(
          destination: '/app/game/action',
          body: jsonEncode(body)
      );
    }
  }

  void _send(String dest, Map<String, dynamic> body) {
    if (_stompClient != null && _stompClient!.connected) {
      _stompClient?.send(destination: dest, body: jsonEncode(body));
    }
  }

  void _disconnectSocket() {
    _stompClient?.deactivate();
    _stompClient = null;
  }

  @override
  void dispose() {
    _chatStreamController.close(); // Đổi tên biến đóng stream
    super.dispose();
  }
  Future<bool> fetchUserProfile() async {
    if (_token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/profile'), // Đảm bảo baseUrl đúng
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token', // Gửi kèm Token
        },
      );

      if (response.statusCode == 200) {
        // Decode UTF8 để không lỗi font tiếng Việt
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _userProfile = UserProfile.fromJson(data);
        notifyListeners(); // Báo cho UI cập nhật
        return true;
      } else {
        print("Lỗi tải profile: ${response.statusCode}");
      }
    } catch (e) {
      print("Exception Profile: $e");
    }
    return false;
  }
}
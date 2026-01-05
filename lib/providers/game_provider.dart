import 'dart:async'; 
import 'dart:convert';
import 'package:caro_online/data/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:shared_preferences/shared_preferences.dart'; // [MỚI] Import thư viện này

import '../data/models/game_room.dart';

class GameProvider with ChangeNotifier {
  // CONFIG IP (Giữ nguyên của bạn):
  final String baseUrl = 'http://172.24.95.87:8080';
  final String socketUrl = 'ws://172.24.95.87:8080/ws';

  String? _token;
  String? _currentUserId;
  String? _currentUsername;

  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;
  
  // State Lobby
  List<GameRoom> _lobbyRooms = [];

  // State Room hiện tại
  GameRoom? _currentRoom;

  // Kết quả trận đấu
  Map<String, dynamic>? _lastGameResult;

  // Stream Controller Chat
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

  // ==================== 1. AUTHENTICATION (ĐÃ CẬP NHẬT GHI NHỚ ĐĂNG NHẬP) ====================

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
            // --- [MỚI] LƯU TOKEN VÀO MÁY ---
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('jwt_token', _token!);
            await prefs.setString('saved_username', username);
            // -------------------------------

            // Decode JWT để lấy ID
            Map<String, dynamic> decodedToken = JwtDecoder.decode(_token!);
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

  // --- [MỚI] HÀM TỰ ĐỘNG ĐĂNG NHẬP ---
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Kiểm tra xem có token không
    if (!prefs.containsKey('jwt_token')) return false;

    final extractedToken = prefs.getString('jwt_token');
    final savedUsername = prefs.getString('saved_username') ?? "";

    // Kiểm tra token hết hạn chưa
    if (extractedToken == null || JwtDecoder.isExpired(extractedToken)) {
      await logout(); // Hết hạn thì xóa luôn cho sạch
      return false;
    }

    // Token còn hạn -> Khôi phục lại State
    _token = extractedToken;
    _currentUsername = savedUsername;
    
    try {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(_token!);
      _currentUserId = decodedToken['userId']?.toString() ?? decodedToken['id']?.toString() ?? "0";
    } catch (e) {
      return false;
    }

    notifyListeners();
    
    // Tự động kết nối lại socket và lấy profile
    connectSocketLobby();
    fetchUserProfile();
    
    return true;
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

  Future<void> logout() async {
    _token = null;
    _currentUserId = null;
    _disconnectSocket();
    _currentRoom = null;
    
    // --- [MỚI] XÓA TOKEN KHỎI MÁY ---
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('saved_username');
    // -------------------------------

    notifyListeners();
  }

  // ==================== 2. SOCKET CONNECTION (CORE - GIỮ NGUYÊN) ====================

  void connectSocketLobby() {
    if (_token == null) return;
    if (_stompClient != null && _stompClient!.connected) return;

    _stompClient = StompClient(
      config: StompConfig(
        url: socketUrl,
        onConnect: (StompFrame frame) {
          print("✅ Socket Connected!");

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

  // ==================== 3. GAMEPLAY LOGIC (GIỮ NGUYÊN) ====================

  Future<bool> joinRoom(String roomId) async {
    if (_stompClient == null || !_stompClient!.connected) return false;

    // Logic kiểm tra phòng
    bool exists = _lobbyRooms.any((r) => r.roomId == roomId);
    if (!exists) {
      await fetchLobbyRoomsRest();
      exists = _lobbyRooms.any((r) => r.roomId == roomId);
    }
    if (!exists) return false; 

    // Reset state và Subscribe
    _currentRoom = null;
    _lastGameResult = null;

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

    _stompClient!.subscribe(
      destination: '/topic/room/$roomId/chat',
      callback: (frame) {
        if (frame.body != null) {
          try {
            var msgData = jsonDecode(frame.body!);
            _chatStreamController.add({
              'sender': msgData['sender'] ?? "System",
              'content': msgData['content'] ?? ""
            });
          } catch(e) { print("Chat parse error: $e"); }
        }
      },
    );

    _send('/app/game/join', {'roomId': roomId, 'message': _currentUsername});
    return true;
  }

  void _handleGameMessage(Map<String, dynamic> data) {
    if (data.containsKey('type')) {
      String type = data['type'];

      if (type == 'GAME_OVER') {
        if (data.containsKey('resultChanges')) {
          _lastGameResult = data['resultChanges'];
        }
        if (data.containsKey('room')) {
          _currentRoom = GameRoom.fromJson(data['room']);
        }
      }
      else if (type == 'ERROR') {
        _chatStreamController.add({'sender': 'System', 'content': "Lỗi: ${data['message']}"});
      }
    }
    else {
      try {
        _currentRoom = GameRoom.fromJson(data);
        if (_currentRoom?.status == "WAITING") {
          _lastGameResult = null;
        }
      } catch (e) {
        print("Lỗi parse GameRoom DTO: $e");
      }
    }
    notifyListeners();
  }

  // --- SEND ACTIONS ---

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
    _sendAction(roomId, 'CHAT', extra: {'message': message});
  }

  Future<String?> createRoom(String roomName, bool isBlock2Ends) async {
  try {
    if (_currentUsername == null) return null;

    final response = await http.post(
      Uri.parse('$baseUrl/api/lobby/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token'
      },
      body: jsonEncode({
        'username': _currentUsername,
        'roomName': roomName,
        'ruleBlock2Ends': isBlock2Ends
      })
    );

    if (response.statusCode == 200) {
      return response.body; 
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
    _chatStreamController.close();
    super.dispose();
  }

  Future<bool> fetchUserProfile() async {
    if (_token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/profile'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _userProfile = UserProfile.fromJson(data);
        notifyListeners(); 
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
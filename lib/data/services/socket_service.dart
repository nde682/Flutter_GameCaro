// File: lib/data/services/socket_service.dart

import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

class SocketService {
  // Cấu hình URL: Dùng 10.0.2.2 cho Android Emulator, localhost cho iOS/Web
  static const String _socketUrl = 'ws://localhost:8080/ws';

  StompClient? _client;

  bool get isConnected => _client?.connected ?? false;

  /// Kết nối Socket
  void connect(String token, {required Function() onConnect}) {
    if (_client != null && _client!.connected) return;

    _client = StompClient(
      config: StompConfig(
        url: _socketUrl,
        onConnect: (StompFrame frame) {
          print("✅ Socket: Connected!");
          onConnect();
        },
        onWebSocketError: (dynamic error) => print("❌ Socket WS Error: $error"),
        onStompError: (StompFrame frame) => print("❌ Socket Stomp Error: ${frame.body}"),
        onDisconnect: (_) => print("⚠️ Socket: Disconnected"),
        
        // Gửi Token để xác thực
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        
        // Giữ kết nối ổn định
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: const Duration(seconds: 10),
      ),
    );

    _client!.activate();
  }

  /// Ngắt kết nối
  void disconnect() {
    _client?.deactivate();
    _client = null;
  }

  /// Subscribe tổng quát (Thay thế cho subscribeRoom cũ)
  /// Cho phép Provider tự quyết định subscribe vào đâu (Room, Lobby, Chat...)
  void subscribe(String destination, Function(dynamic) callback) {
    if (!isConnected) return;

    _client!.subscribe(
      destination: destination,
      callback: (StompFrame frame) {
        if (frame.body != null) {
          try {
            var data = jsonDecode(frame.body!);
            callback(data);
          } catch (e) {
            print("Lỗi parse JSON từ $destination: $e");
          }
        }
      },
    );
    print("🔔 Subscribed to: $destination");
  }

  /// Gửi dữ liệu tổng quát (Thay thế cho sendAction, joinRoom cũ)
  /// Cho phép Provider tự quyết định gửi đi đâu
  void send(String destination, Map<String, dynamic> body) {
    if (!isConnected) return;

    _client!.send(
      destination: destination,
      body: jsonEncode(body),
    );
    // print("📤 Sent to $destination"); // Bật lên nếu muốn debug
  }
}
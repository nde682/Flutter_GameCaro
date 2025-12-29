// File: lib/data/models/game_action.dart

class GameAction {
  // Loại hành động (tùy chọn, dùng để debug hoặc nếu backend yêu cầu phân loại chung)
  final String type; 
  
  // ID phòng là bắt buộc cho mọi hành động
  final String roomId;
  
  // Tọa độ nước đi (dùng cho MOVE)
  final int x;
  final int y;
  
  // Nội dung tin nhắn (dùng cho CHAT)
  final String content; 
  
  // Cấu hình luật (dùng cho RULE_CHANGE)
  final bool ruleBlock2Ends;

  GameAction({
    this.type = "",
    required this.roomId,
    this.x = -1,
    this.y = -1,
    this.content = "",
    this.ruleBlock2Ends = false,
  });

  // Chuyển đối tượng thành JSON để gửi qua Socket
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'roomId': roomId,
      'x': x,
      'y': y,
      'content': content,
      'ruleBlock2Ends': ruleBlock2Ends,
    };
  }
}
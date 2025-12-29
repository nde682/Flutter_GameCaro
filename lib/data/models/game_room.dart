
class GameRoom {
  final String roomId;
  final String roomName;
  final String status; // WAITING, PLAYING, FINISHED
  final Map<String, String> board; // key: "x,y", value: "X" or "O"
  final List<Player> players;
  final bool ruleBlock2Ends;
  final bool isFixed;
  final int? drawRequestByUserId ; 
  final DateTime? startTime;
  final  DateTime? turnStartTime;
  final String? currentTurn; 
  final String? winner;      

  GameRoom({
    required this.roomId,
    required this.roomName,
    required this.status,
    required this.board,
    required this.players,
    required this.ruleBlock2Ends,
    this.isFixed = false,
    this.startTime,
    this.turnStartTime,
    this.currentTurn, 
    this.winner,
    this.drawRequestByUserId ,
  });

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    return GameRoom(
      roomId: json['roomId'] ?? "",
      roomName: json['roomName'] ?? "Unknown",
      status: json['status'] ?? "WAITING",
      // Parse Board
      board: (json['board'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ?? {},
      // Parse Players
      players: (json['players'] as List<dynamic>?)
              ?.map((e) => Player.fromJson(e))
              .toList() ?? [],
      ruleBlock2Ends: json['ruleBlock2Ends'] ?? false,
      isFixed: json['isFixed'] ?? false,
      currentTurn: json['currentTurn'],
      winner: json['winner'],
      drawRequestByUserId: json['drawRequestByUserId'],
      turnStartTime: json['turnStartTime'] != null ? DateTime.parse(json['turnStartTime']) : null,
      startTime: json['startTime'] != null ? DateTime.parse(json['startTime']) : null
    );
  }
}

// Model Player giữ nguyên, đảm bảo có trường isReady
class Player {
  final int id;
  final String username;
  final String sessionId;
  final String displayName;
  final String avatar;
  final String role; // HOST, GUEST
  final String side; // X, O
  final bool isReady; // <--- Quan trọng để nút Sẵn sàng đổi trạng thái
  final int coin;
  final String? rank;
  final DateTime? lastDrawRequestTime;

  Player({
    required this.id,
    required this.username,
    required this.sessionId,
    required this.displayName,
    required this.avatar,
    required this.role,
    required this.side,
    required this.isReady,
    required this.coin,
    this.rank,
    this.lastDrawRequestTime,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] ?? 0,
      username: json['username'] ?? "",
      displayName: json['displayName'] ?? "Unknown",
      sessionId: json['sessionId'] ?? "",
      avatar: json['avatar'] ?? "",
      role: json['role'] ?? "GUEST",
      side: json['side'] ?? "",
      isReady: json['ready'] ?? json['isReady'] ?? false,
      coin: json['coin'] ?? 0,
      rank: json['rank'],
      lastDrawRequestTime: json['lastDrawRequestTime'] != null ? DateTime.parse(json['lastDrawRequestTime']) : null,
    );
  }
}
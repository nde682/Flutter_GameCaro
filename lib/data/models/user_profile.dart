class MatchHistory {
  final String result;
  final int pointChange;
  final String date;
  final String roomName;

  MatchHistory({
    required this.result,
    required this.pointChange,
    required this.date,
    required this.roomName,
  });

  factory MatchHistory.fromJson(Map<String, dynamic> json) {
    return MatchHistory(
      result: json['result'] ?? "DRAW",
      pointChange: json['pointChange'] ?? 0,
      date: json['date'] ?? "", // Backend trả về chuỗi ISO date
      roomName: json['roomName'] ?? "Unknown",
    );
  }
}

class UserProfile {
  final String username;
  final String nickname;
  final String email;
  final String avatar;
  final int coin;
  final int point;
  final String rank;
  final int totalGames;
  final int wins;
  final int loses;
  final int draws;
  final List<MatchHistory> history;

  UserProfile({
    required this.username,
    required this.nickname,
    required this.email,
    required this.avatar,
    required this.coin,
    required this.point,
    required this.rank,
    required this.totalGames,
    required this.wins,
    required this.loses,
    required this.draws,
    required this.history,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    var list = json['history'] as List? ?? [];
    List<MatchHistory> historyList = list.map((i) => MatchHistory.fromJson(i)).toList();

    return UserProfile(
      username: json['username'] ?? "",
      nickname: json['nickname'] ?? "Người chơi",
      email: json['email'] ?? "",
      avatar: json['avatar'] ?? "",
      coin: json['coin'] ?? 0,
      point: json['point'] ?? 0,
      rank: json['rank'] ?? "Tập sự",
      totalGames: json['totalGames'] ?? 0,
      wins: json['wins'] ?? 0,
      loses: json['loses'] ?? 0,
      draws: json['draws'] ?? 0,
      history: historyList,
    );
  }
}
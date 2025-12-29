import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../lobby/lobby_screen.dart'; // Import màn hình sảnh chờ
import '../auth/login_screen.dart'; // Import login để logout

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Gọi API ngay khi màn hình load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GameProvider>(context, listen: false).fetchUserProfile().then((_) {
        if (mounted) setState(() => _isLoading = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GameProvider>(context);
    final profile = provider.userProfile;

    // Loading...
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
      );
    }

    // Lỗi hoặc không có data
    if (profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Không tải được dữ liệu!", style: TextStyle(color: Colors.white)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Quay lại"),
              )
            ],
          ),
        ),
      );
    }

    // Giao diện chính
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text("HỒ SƠ GAME THỦ", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              // Xử lý đăng xuất (Xóa token, về login...)
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. THẺ THÔNG TIN (Avatar, Tên, Rank)
            _buildInfoCard(profile),

            const SizedBox(height: 20),

            // 2. THỐNG KÊ (Grid 6 ô)
            _buildStatsGrid(profile),

            const SizedBox(height: 25),

            // 3. TIÊU ĐỀ LỊCH SỬ
            const Text(
              "Lịch sử 10 trận gần nhất",
              style: TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // 4. DANH SÁCH TRẬN ĐẤU
            _buildHistoryList(profile),

            const SizedBox(height: 80), // Khoảng trống cho nút bấm phía dưới
          ],
        ),
      ),
      
      // NÚT VÀO GAME
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pinkAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 5,
          ),
          onPressed: () {
            // Chuyển sang Lobby
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LobbyScreen()),
            );
          },
          child: const Text("VÀO SẢNH CHỜ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }

  // --- Widget Con: Thẻ thông tin ---
  Widget _buildInfoCard(dynamic profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3460), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white24,
            backgroundImage: profile.avatar.isNotEmpty 
                ? NetworkImage(profile.avatar) 
                : null,
            child: profile.avatar.isEmpty ? const Icon(Icons.person, size: 35, color: Colors.white) : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.nickname, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text("@${profile.username}", style: const TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Text("Rank: ${profile.rank}", style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget Con: Lưới thống kê ---
  Widget _buildStatsGrid(dynamic profile) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: [
        _statItem("Coin", "${profile.coin}", Icons.monetization_on, Colors.yellow),
        _statItem("Điểm", "${profile.point}", Icons.star, Colors.purpleAccent),
        _statItem("Tổng trận", "${profile.totalGames}", Icons.videogame_asset, Colors.blue),
        _statItem("Thắng", "${profile.wins}", Icons.emoji_events, Colors.green),
        _statItem("Thua", "${profile.loses}", Icons.thumb_down, Colors.red),
        _statItem("Hoà", "${profile.draws}", Icons.handshake, Colors.grey),
      ],
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252540),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  // --- Widget Con: Danh sách lịch sử ---
  Widget _buildHistoryList(dynamic profile) {
    if (profile.history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text("Chưa có trận đấu nào", style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: profile.history.length,
      itemBuilder: (context, index) {
        final match = profile.history[index];
        
        // Xử lý màu sắc
        Color resultColor = Colors.grey;
        String prefix = "";
        if (match.result == "WIN") { resultColor = Colors.green; prefix = "+"; }
        if (match.result == "LOSE") { resultColor = Colors.red; prefix = ""; }

        // Format ngày (đơn giản)
        String dateDisplay = match.date.replaceAll("T", " ").substring(0, 16); 

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F3460),
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: resultColor, width: 4)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            title: Text(match.roomName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(dateDisplay, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(match.result, style: TextStyle(color: resultColor, fontWeight: FontWeight.bold)),
                Text("$prefix${match.pointChange} điểm", style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}
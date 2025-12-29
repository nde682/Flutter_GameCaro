import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../auth/login_screen.dart';
import '../game/game_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({Key? key}) : super(key: key);

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshLobby();
    });
  }

  Future<void> _refreshLobby() async {
    await Provider.of<GameProvider>(context, listen: false).fetchLobbyRoomsRest();
  }

  // Hàm xử lý Join Room chung
  void _joinRoom(String roomId) {
    if (roomId.isEmpty) return;
    
    final provider = Provider.of<GameProvider>(context, listen: false);
    provider.joinRoom(roomId); // Gọi socket join

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GameScreen()),
    ).then((_) {
      _refreshLobby(); // Quay lại thì refresh
    });
  }

  // --- 1. DIALOG TẠO PHÒNG (Đã nâng cấp) ---
  void _showCreateRoomDialog() {
    final TextEditingController nameController = TextEditingController();
    bool isBlock2Ends = false; // Biến lưu trạng thái luật

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder( // Dùng StatefulBuilder để update Checkbox trong Dialog
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xFF252540),
            title: const Text("Tạo phòng mới", style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nhập tên
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Đặt tên phòng...",
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                  ),
                ),
                const SizedBox(height: 20),
                // Checkbox luật
                Row(
                  children: [
                    Checkbox(
                      value: isBlock2Ends,
                      activeColor: Colors.pinkAccent,
                      side: const BorderSide(color: Colors.white54),
                      onChanged: (val) {
                        setStateDialog(() {
                          isBlock2Ends = val ?? false;
                        });
                      },
                    ),
                    const Text("Luật chặn 2 đầu", style: TextStyle(color: Colors.white70)),
                  ],
                )
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  
                  // Hiện loading tạm thời
                  Navigator.pop(ctx); 
                  ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("Đang tạo phòng..."), duration: Duration(seconds: 1)),
                  );

                  final provider = Provider.of<GameProvider>(context, listen: false);
                  // Gọi hàm tạo phòng với tham số luật
                  String? newRoomId = await provider.createRoom(name, isBlock2Ends);
                  
                  if (newRoomId != null && mounted) {
                    _joinRoom(newRoomId); // Tạo xong tự vào luôn
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Lỗi tạo phòng!"), backgroundColor: Colors.redAccent),
                    );
                  }
                },
                child: const Text("Tạo", style: TextStyle(color: Colors.white)),
              )
            ],
          );
        },
      ),
    );
  }

  // --- 2. DIALOG NHẬP ID ĐỂ JOIN ---
  void _showJoinByIdDialog() {
    final TextEditingController idController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252540),
        title: const Text("Vào phòng bằng ID", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: idController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Nhập mã phòng (VD: ROOM-1)...",
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
          ),
        ),
        actions: [
          TextButton(
             onPressed: () => Navigator.pop(ctx),
             child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
            onPressed: () {
              final id = idController.text.trim();
              if (id.isNotEmpty) {
                Navigator.pop(ctx);
                _joinRoom(id);
              }
            },
            child: const Text("Vào ngay", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, provider, child) {
        final rooms = provider.lobbyRooms;
        final currentUser = provider.currentUsername ?? "Gamer";

        return Scaffold(
          backgroundColor: const Color(0xFF1A1A2E),
          appBar: AppBar(
            title: const Text("Sảnh Game Caro"),
            backgroundColor: const Color(0xFF16213E),
            elevation: 0,
            actions: [
               // Nút Tìm phòng bằng ID trên AppBar cho tiện
               IconButton(
                 icon: const Icon(Icons.search, color: Colors.cyanAccent),
                 tooltip: "Nhập ID phòng",
                 onPressed: _showJoinByIdDialog,
               ),
               Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(currentUser, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                onPressed: () {
                  provider.logout();
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
              )
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshLobby,
            child: rooms.isEmpty 
              ? ListView(children: const [SizedBox(height: 200), Center(child: Text("Chưa có phòng nào", style: TextStyle(color: Colors.white54)))])
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return Card(
                      color: const Color(0xFF0F3460),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Icon(room.isFixed ? Icons.verified : Icons.videogame_asset, color: Colors.cyanAccent),
                        title: Text(room.roomName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(room.isFixed ? "Phòng hệ thống" : "ID: ${room.roomId}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: ElevatedButton(
                          onPressed: () => _joinRoom(room.roomId),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                          child: const Text("Vào", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    );
                  },
                ),
          ),
          // Hai nút Floating Action Button
          floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: "btnJoin",
                onPressed: _showJoinByIdDialog,
                backgroundColor: Colors.blueGrey,
                child: const Icon(Icons.keyboard, color: Colors.white),
              ),
              const SizedBox(height: 10),
              FloatingActionButton.extended(
                heroTag: "btnCreate",
                onPressed: _showCreateRoomDialog,
                backgroundColor: Colors.pinkAccent,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Tạo Phòng", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }
}
import 'dart:async';
import 'package:caro_online/screens/game/board_painter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/game_room.dart';
import '../../providers/game_provider.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  
  // Animation Controller để lướt camera mượt mà
  late AnimationController _animController;
  Animation<Matrix4>? _mapAnimation;

  final int boardSize = 40;     // Bàn cờ 40x40
  final double cellSize = 35.0; // Kích thước mỗi ô 35px

  // Lưu trạng thái bàn cờ cũ để so sánh tìm nước đi mới
  Map<String, String> _prevBoard = {};
  bool _isStarting = false;
  bool _isEndGameDialogShown = false;
  bool _isDrawDialogShown = false;
  
  StreamSubscription? _chatSubscription;

  // -- STATE QUẢN LÝ CHAT BONG BÓNG --
  String? _myChatMsg;
  String? _opponentChatMsg;
  Timer? _myChatTimer;
  Timer? _opponentChatTimer;

  // Timer cooldown Cầu hòa
  Timer? _drawCooldownTimer;
  int _drawCooldown = 0;

  @override
  void initState() {
    super.initState();
    
    // Khởi tạo Animation Controller
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
       _transformationController.value = _mapAnimation!.value;
    });

    // 1. CĂN GIỮA BÀN CỜ KHI MỚI VÀO
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerBoard();
    });
    
    // Lắng nghe Stream Chat
    final provider = Provider.of<GameProvider>(context, listen: false);
    _chatSubscription = provider.chatStream.listen((data) {
      if (!mounted) return;
      String sender = data['sender'] ?? "";
      String content = data['content'] ?? "";
      String myName = provider.currentUsername ?? "";

      if (sender == myName) _showMyChat(content);
      else _showOpponentChat(content);
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animController.dispose();
    _drawCooldownTimer?.cancel();
    _chatSubscription?.cancel();
    _myChatTimer?.cancel();
    _opponentChatTimer?.cancel();
    super.dispose();
  }

  // --- LOGIC CAMERA (ZOOM & SCROLL) ---
  
  // Hàm 1: Đưa Camera về giữa bàn cờ (Reset)
  void _centerBoard() {
    if (!mounted) return;
    final Size screenSize = MediaQuery.of(context).size;
    final double boardPixelSize = boardSize * cellSize; // 1400px
    double scale = 1;

    // Công thức:
    // 1. Dời gốc tọa độ về giữa màn hình (Screen/2)
    // 2. Zoom (Scale)
    // 3. Dời ngược lại để tâm bàn cờ (Board/2) trùng với gốc đó
    final Matrix4 matrix = Matrix4.identity()
      ..translate(screenSize.width / 2, screenSize.height / 2) 
      ..scale(scale) 
      ..translate(-boardPixelSize / 2, -boardPixelSize / 2);

    _transformationController.value = matrix;
  }

  // Hàm 2: Đưa Camera tới ô cờ cụ thể (Focus)
  void _scrollToCell(int x, int y) {
    if (!mounted) return;
    
    // Lấy độ zoom hiện tại (để không bị zoom in/out đột ngột)
    final Matrix4 currentMatrix = _transformationController.value;
    final double currentScale = currentMatrix.getMaxScaleOnAxis();
    
    final Size screenSize = MediaQuery.of(context).size;
    
    // Tính tọa độ pixel tâm của ô cờ (x, y)
    final double targetPixelX = x * cellSize + cellSize / 2;
    final double targetPixelY = (y+4) * cellSize + cellSize / 2;

    // Tính Matrix đích: Đưa ô cờ đó về giữa màn hình
    final Matrix4 targetMatrix = Matrix4.identity()
      ..translate(screenSize.width / 2, screenSize.height / 2)
      ..scale(currentScale) 
      ..translate(-targetPixelX, -targetPixelY); 

    // Chạy hiệu ứng lướt
    _mapAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));

    _animController.forward(from: 0);
  }

  // ... (Logic Chat giữ nguyên) ...
  void _showMyChat(String msg) {
    setState(() => _myChatMsg = msg);
    _myChatTimer?.cancel();
    _myChatTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _myChatMsg = null);
    });
  }

  void _showOpponentChat(String msg) {
    setState(() => _opponentChatMsg = msg);
    _opponentChatTimer?.cancel();
    _opponentChatTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _opponentChatMsg = null);
    });
  }

  void _startDrawCooldown() {
    setState(() => _drawCooldown = 60);
    _drawCooldownTimer?.cancel();
    _drawCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_drawCooldown > 0) _drawCooldown--;
        else timer.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, provider, child) {
        final room = provider.currentRoom;
        if (room == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF1A1A2E),
            body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
          );
        }

        final myUsername = provider.currentUsername ?? "";
        final String myUserIdStr = provider.currentUserId?.toString() ?? "0";
        
        final me = room.players.firstWhere((p) => p.username == myUsername, orElse: () => Player(id: -1, username: "me", sessionId: "", displayName: "Tôi", avatar: "", role: "GUEST", side: "", isReady: false, coin: 0, rank: "Tập sự"));
        final opponent = room.players.firstWhere((p) => p.username != myUsername, orElse: () => Player(id: 0, username: "waiting", sessionId: "", displayName: "Đang chờ...", avatar: "", role: "GUEST", side: "", isReady: false, coin: 0, rank: ""));
        final bool isHost = me.role == "HOST";
        final bool isMyTurn = (room.status == "PLAYING") && (room.currentTurn == me.side);

        // --- AUTO SCROLL LOGIC (PHÁT HIỆN NƯỚC ĐI MỚI) ---
        if (room.board.length > _prevBoard.length) {
           String? newMoveKey;
           // Tìm ô mới nhất
           room.board.forEach((key, val) {
             if (!_prevBoard.containsKey(key)) newMoveKey = key;
           });

           if (newMoveKey != null) {
             var parts = newMoveKey!.split(',');
             int newX = int.parse(parts[0]);
             int newY = int.parse(parts[1]);
             
             // Scroll tới nước đi mới bất kể là của mình hay đối thủ
             // (Để đảm bảo luôn nhìn thấy diễn biến trận đấu)
             Future.delayed(const Duration(milliseconds: 100), () => _scrollToCell(newX, newY));
           }
        }
        _prevBoard = Map.from(room.board);

        // --- XỬ LÝ DIALOG SỰ KIỆN ---
        WidgetsBinding.instance.addPostFrameCallback((_) {
            bool hasDrawRequest = room.drawRequestByUserId != null;
            bool isMeRequester = room.drawRequestByUserId.toString() == myUserIdStr;
            bool isGamePlaying = room.status == "PLAYING";

            // A. Dialog Cầu Hòa
            if (hasDrawRequest && !isMeRequester && isGamePlaying && !_isDrawDialogShown) {
              setState(() => _isDrawDialogShown = true);
              _showDrawOfferDialog(context, provider, room.roomId, opponent.displayName);
            }
            if ((!hasDrawRequest || !isGamePlaying) && _isDrawDialogShown) {
              Navigator.of(context).pop(); 
              setState(() => _isDrawDialogShown = false);
            }

            // B. Dialog Kết Thúc
            if (room.status == "FINISHED" && !_isEndGameDialogShown) {
              setState(() => _isEndGameDialogShown = true);
              bool isWinner = room.winner == me.username;
              bool isDraw = room.winner == "DRAW";
              if (_isDrawDialogShown) {
                 Navigator.of(context).pop();
                 setState(() => _isDrawDialogShown = false);
              }
              _showEndGameDialog(context, provider, isWinner, isDraw, me.username);
            }

            // C. Reset
            if (room.status == "WAITING" && (_isEndGameDialogShown || _isDrawDialogShown)) {
              setState(() { _isEndGameDialogShown = false; _isDrawDialogShown = false; });
              Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == null); 
            }
        });

        return Scaffold(
          resizeToAvoidBottomInset: false, 
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, provider, room),

                  Expanded(
                    child: Stack(
                      children: [
                        // LAYER 1: BÀN CỜ (Nằm dưới)
                        // Dùng Column để tạo khoảng trống phía trên cho thẻ đối thủ
                        Column(
                          children: [
                            // Chừa ra khoảng trống bằng chiều cao thẻ đối thủ (khoảng 90-100px)
                            const SizedBox(height: 100), 
                            Expanded(
                              child: (room.status == "WAITING" || room.status == "FINISHED")
                                ? _buildWaitingArea(room, isHost, provider)
                                : _buildGameBoard(room, isMyTurn, provider),
                            ),
                          ],
                        ),

                        // LAYER 2: ĐỐI THỦ (Nằm trên cùng -> Bong bóng chat sẽ đè lên bàn cờ)
                        Positioned(
                          top: 0, 
                          left: 0, 
                          right: 0,
                          child: _buildPlayerArea(
                            opponent,
                            isActiveTurn: room.status == "PLAYING" && room.currentTurn == opponent.side,
                            isMe: false,
                            chatMsg: _opponentChatMsg,
                          ),
                        ),
                      ],
                    ),
                  ),

                  _buildPlayerArea(me, isActiveTurn: isMyTurn, isMe: true, chatMsg: _myChatMsg),
                  _buildBottomActions(context, room, me, isHost, provider, opponent),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- WIDGET BÀN CỜ 40x40 ---
 Widget _buildGameBoard(GameRoom room, bool canMove, GameProvider provider) {
    return Container(
      color: const Color(0xFF121212), // Màu nền vùng bao quanh
      child: InteractiveViewer(
        transformationController: _transformationController,
        constrained: false, 
        boundaryMargin: const EdgeInsets.all(2000.0),
        minScale: 0.2,
        maxScale: 3.0,
        // Dùng RepaintBoundary bọc ngoài InteractiveViewer để tối ưu render khi có lớp phủ (chat)
        child: RepaintBoundary(
          child: Container(
            // Container bọc ngoài để vẽ viền bao quanh bàn cờ
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white54, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5)],
            ),
            // Gọi Widget vẽ Canvas ở đây
            child: BigBoardWidget(
              boardSize: boardSize,
              cellSize: cellSize,
              boardData: room.board,
              onTap: (x, y) {
                // Kiểm tra xem ô đó đã đánh chưa
                String key = "$x,$y";
                if (canMove && !room.board.containsKey(key)) {
                  provider.makeMove(room.roomId, x, y);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  // --- CÁC WIDGET PHỤ ---

  Widget _buildPlayerArea(Player player, {required bool isActiveTurn, required bool isMe, String? chatMsg}) {
    // Chiều cao ước lượng của thẻ PlayerInfoCard (gồm padding + margin + content)
    // Để đặt bong bóng chat không bị đè lên thẻ
    const double cardHeight = 85.0; 

    return Stack(
      // QUAN TRỌNG: Cho phép bong bóng vẽ tràn ra ngoài vùng stack mà không bị cắt
      clipBehavior: Clip.none, 
      alignment: Alignment.center,
      children: [
        // 1. Thẻ thông tin (Đây là widget gốc để giữ chỗ)
        _buildPlayerInfoCard(player, isActiveTurn: isActiveTurn, isMe: isMe),

        // 2. Bong bóng chat (Nổi lơ lửng, không chiếm chỗ layout)
        if (chatMsg != null)
          Positioned(
            // Nếu là Mình (ở đáy màn hình) -> Bong bóng nằm trên thẻ (cách đáy cardHeight)
            // Nếu là Đối thủ (ở đỉnh màn hình) -> Bong bóng nằm dưới thẻ (cách đỉnh cardHeight)
            bottom: isMe ? cardHeight : null,
            top: !isMe ? cardHeight : null,
            
            child: Container(
              constraints: const BoxConstraints(maxWidth: 250), // Giới hạn chiều rộng tin nhắn
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  
                  // Tạo hiệu ứng đuôi bong bóng hướng về phía thẻ
                  bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(12),
                  bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
                  
                  // Đối thủ (Bubble ở dưới): Vuông góc trên bên trái
                  // Mình (Bubble ở trên): Vuông góc dưới bên phải
                ).resolve(TextDirection.ltr), // Đảm bảo hướng bo góc đúng
                
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chatMsg, 
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 14)
                  ),
                  // Mũi tên trỏ xuống/lên (Optional - dùng CustomPaint hoặc Icon nếu muốn đẹp hơn)
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayerInfoCard(Player player, {required bool isActiveTurn, required bool isMe}) {
      if (player.id <= 0) return Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text("Đang chờ...", style: TextStyle(color: Colors.grey))));
      final glowColor = isActiveTurn ? (isMe ? Colors.cyanAccent : Colors.redAccent) : Colors.transparent;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF0F3460).withOpacity(0.8), borderRadius: BorderRadius.circular(12), border: Border.all(color: isActiveTurn ? glowColor : Colors.white10), boxShadow: isActiveTurn ? [BoxShadow(color: glowColor.withOpacity(0.3), blurRadius: 10)] : []),
        child: Row(children: [CircleAvatar(radius: 20, backgroundImage: NetworkImage(player.avatar.isNotEmpty ? player.avatar : "https://api.dicebear.com/7.x/avataaars/svg?seed=${player.username}")), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(player.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("Coin: ${player.coin}", style: const TextStyle(color: Colors.amberAccent, fontSize: 11))])), if (player.side.isNotEmpty) Text(player.side, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: player.side == "X" ? Colors.cyanAccent : Colors.redAccent)), const SizedBox(width: 8), if (player.role == "HOST") const Icon(Icons.stars, color: Colors.yellow, size: 20) else if (player.isReady) const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20)]),
      );
  }

  void _showChatInputDialog(BuildContext context, GameProvider provider, String roomId) {
    TextEditingController _chatController = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF252540), title: const Text("Chat", style: TextStyle(color: Colors.white)), content: TextField(controller: _chatController, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Nhập nội dung...", hintStyle: TextStyle(color: Colors.white38), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))), onSubmitted: (value) { if (value.trim().isNotEmpty) { provider.sendChat(roomId, value.trim()); Navigator.pop(ctx); }}), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy", style: TextStyle(color: Colors.grey))), ElevatedButton(onPressed: () { if (_chatController.text.trim().isNotEmpty) { provider.sendChat(roomId, _chatController.text.trim()); Navigator.pop(ctx); }}, child: const Text("Gửi"))]));
  }

 Widget _buildBottomActions(BuildContext context, GameRoom room, Player me, bool isHost, GameProvider provider, Player opponent) {
    // 1. TRẠNG THÁI ĐANG CHƠI (Giữ nguyên)
    if (room.status == "PLAYING") {
      // Khi vào game rồi thì reset biến _isStarting để lần sau dùng lại
      if (_isStarting) {
        // Dùng Future.microtask để tránh lỗi setState khi đang build
        Future.microtask(() => setState(() => _isStarting = false));
      }

      return Container(
        color: const Color(0xFF16213E), 
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround, 
          children: [
            _iconButton(Icons.chat_bubble_outline, "Chat", Colors.white70, () => _showChatInputDialog(context, provider, room.roomId)), 
            _iconButton(Icons.handshake_outlined, _drawCooldown > 0 ? "${_drawCooldown}s" : "Cầu hòa", Colors.yellowAccent, () { 
              if (_drawCooldown == 0) { 
                provider.sendDrawRequest(room.roomId); 
                _startDrawCooldown(); 
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã gửi lời mời hòa!"))); 
              }
            }), 
            _iconButton(Icons.flag_outlined, "Rời phòng", Colors.redAccent, () => _handleLeave(context, provider, room.roomId, isPlaying: true))
          ]
        ),
      );
    }
    
    // 2. TRẠNG THÁI CHỜ (SỬA LOGIC TẠI ĐÂY)
    bool hasOpponent = opponent.id > 0;
    bool opponentReady = opponent.isReady;

    return Container(
      padding: const EdgeInsets.all(16), 
      color: const Color(0xFF16213E),
      child: Center(
        child: isHost
          // --- NÚT CỦA CHỦ PHÒNG ---
          ? ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                // Đổi màu xám nếu: Không đủ đk start HOẶC Đang loading start
                backgroundColor: (hasOpponent && opponentReady && !_isStarting) ? Colors.blueAccent : Colors.grey,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)
              ),
              // Nếu đang start -> Hiện vòng quay loading, ngược lại hiện Icon Play
              icon: _isStarting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              
              label: Text(
                _isStarting ? "ĐANG VÀO..." : "BẮT ĐẦU GAME", 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
              ),
              
              onPressed: (hasOpponent && opponentReady && !_isStarting) 
                ? () {
                    // 1. Khóa nút ngay lập tức
                    setState(() => _isStarting = true);
                    
                    // 2. Gửi lệnh
                    provider.startGame(room.roomId);

                    // 3. (Phòng hờ) Nếu sau 5s mà Server chưa phản hồi (mạng lag), mở lại nút để bấm lại
                    Future.delayed(const Duration(seconds: 5), () {
                      if (mounted && room.status == "WAITING") {
                         setState(() => _isStarting = false);
                      }
                    });
                  } 
                : null,
            )
          // --- NÚT CỦA KHÁCH (Giữ nguyên) ---
          : ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: me.isReady ? Colors.grey : Colors.greenAccent, 
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)
              ),
              icon: Icon(me.isReady ? Icons.close : Icons.check),
              label: Text(me.isReady ? "HỦY SẴN SÀNG" : "SẴN SÀNG", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              onPressed: () => provider.toggleReady(room.roomId),
            ),
      ),
    );
  }

  void _showEndGameDialog(BuildContext context, GameProvider provider, bool isWinner, bool isDraw, String myName) {
      Map<String, dynamic>? myResult;
      if (provider.lastGameResult != null && provider.lastGameResult!.containsKey(myName)) { myResult = provider.lastGameResult![myName]; }
      int coinDelta = isDraw ? 0 : (myResult?['coin'] ?? 0);
      int pointDelta = isDraw ? 0 : (myResult?['point'] ?? 0);
      String title = isWinner ? "CHIẾN THẮNG!" : (isDraw ? "HÒA NHAU" : "THẤT BẠI"); Color color = isWinner ? Colors.amber : (isDraw ? Colors.blueAccent : Colors.redAccent); IconData icon = isWinner ? Icons.emoji_events : (isDraw ? Icons.handshake : Icons.sentiment_very_dissatisfied);
      showDialog(context: context, barrierDismissible: false, builder: (ctx) => WillPopScope(onWillPop: () async => false, child: Dialog(backgroundColor: const Color(0xFF252540), child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(border: Border.all(color: color, width: 2), borderRadius: BorderRadius.circular(20), color: const Color(0xFF252540)), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 70, color: color), const SizedBox(height: 16), Text(title, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold)), const SizedBox(height: 20), Container(padding: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_statItem("Coins", coinDelta, Icons.monetization_on, Colors.amber), Container(width: 1, height: 40, color: Colors.white10), _statItem("Rank Point", pointDelta, Icons.stars, Colors.blueAccent)])), const SizedBox(height: 30), Row(children: [Expanded(child: OutlinedButton(onPressed: () { Navigator.pop(ctx); provider.leaveRoom(provider.currentRoom!.roomId); Navigator.pop(context); }, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(vertical: 12)), child: const Text("THOÁT", style: TextStyle(color: Colors.redAccent)))), const SizedBox(width: 16), Expanded(child: ElevatedButton(onPressed: () { Navigator.pop(ctx); provider.restartGame(provider.currentRoom!.roomId); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 12)), child: const Text("CHƠI LẠI")))])])))));
  }

  void _showDrawOfferDialog(BuildContext context, GameProvider provider, String roomId, String senderName) {
      showDialog(context: context, barrierDismissible: false, builder: (ctx) => WillPopScope(onWillPop: () async => false, child: AlertDialog(backgroundColor: const Color(0xFF252540), title: const Text("Cầu hòa", style: TextStyle(color: Colors.white)), content: Text("$senderName muốn xin hòa ván đấu này.", style: const TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () { provider.replyDrawRequest(roomId, false); Navigator.pop(ctx); setState(() => _isDrawDialogShown = false); }, child: const Text("Từ chối", style: TextStyle(color: Colors.redAccent))), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () { provider.replyDrawRequest(roomId, true); Navigator.pop(ctx); setState(() => _isDrawDialogShown = false); }, child: const Text("Đồng ý"))])));
  }

  Widget _buildHeader(BuildContext context, GameProvider provider, GameRoom room) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
       child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white70), onPressed: () => _handleLeave(context, provider, room.roomId, isPlaying: room.status == "PLAYING")), Column(children: [Text("Phòng: ${room.roomName}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),Text("ID: ${room.roomId}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)) ,Text(room.status == "PLAYING" ? "Đang đấu" : "Đang chờ", style: TextStyle(fontSize: 10, color: room.status == "PLAYING" ? Colors.greenAccent : Colors.orange))]), const SizedBox(width: 40)]));
  }

  Widget _buildWaitingArea(GameRoom room, bool isHost, GameProvider provider) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(room.status == "FINISHED" ? Icons.emoji_events : Icons.sports_esports, size: 80, color: Colors.white12), const SizedBox(height: 16), Text(room.status == "FINISHED" ? "Ván đấu kết thúc" : "Chờ chủ phòng bắt đầu...", style: const TextStyle(color: Colors.white38)), if (room.status == "WAITING") Padding(padding: const EdgeInsets.only(top: 20), child: Row(mainAxisSize: MainAxisSize.min, children: [Checkbox(value: room.ruleBlock2Ends, activeColor: Colors.cyanAccent, onChanged: isHost ? (v) => provider.updateRule(room.roomId, v ?? false) : null), Text("Luật chặn 2 đầu", style: TextStyle(color: isHost ? Colors.white : Colors.white54)), if (!isHost) const Icon(Icons.lock, size: 14, color: Colors.white24)]))]));
  }
  
  Widget _iconButton(IconData icon, String label, Color color, VoidCallback onTap) { return InkWell(onTap: onTap, child: Column(children: [Icon(icon, color: color), Text(label, style: TextStyle(color: color, fontSize: 10))])); }
  Widget _statItem(String label, int value, IconData icon, Color color) { return Column(children: [Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 4), Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text("${value >= 0 ? '+' : ''}$value", style: TextStyle(color: value >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16))])]); }
  void _handleLeave(BuildContext context, GameProvider provider, String roomId, {bool isPlaying = false}) { showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF252540), title: const Text("Rời phòng?", style: TextStyle(color: Colors.white)), content: Text(isPlaying ? "Bạn sẽ bị xử thua!" : "Bạn muốn rời phòng?", style: const TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy", style: TextStyle(color: Colors.grey))), TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); provider.leaveRoom(roomId); }, child: const Text("Rời", style: TextStyle(color: Colors.redAccent)))])); }
}